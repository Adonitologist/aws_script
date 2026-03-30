import boto3
import time
import sys
import base64
from botocore.exceptions import ClientError

# --- CONFIGURACIÓN ---
REGION = "us-east-1"
INSTANCE_NAME = "NextCloud-Task-7.1"
SG_NAME = "nextcloud-sg"
EFS_NAME = "nextcloud-efs-data"
KEY_NAME = "vockey" 

ec2 = boto3.client('ec2', region_name=REGION)
efs = boto3.client('efs', region_name=REGION)

def get_or_create_vpc():
    vpcs = ec2.describe_vpcs(Filters=[{'Name': 'isDefault', 'Values': ['true']}])
    return vpcs['Vpcs'][0]['VpcId']

def get_or_create_sg(vpc_id):
    try:
        groups = ec2.describe_security_groups(Filters=[{'Name': 'group-name', 'Values': [SG_NAME]}])
        if groups['SecurityGroups']:
            return groups['SecurityGroups'][0]['GroupId']
        
        sg = ec2.create_security_group(GroupName=SG_NAME, Description="SG NextCloud Task 7.1", VpcId=vpc_id)
        sg_id = sg['GroupId']
        ec2.authorize_security_group_ingress(GroupId=sg_id, IpPermissions=[
            {'IpProtocol': 'tcp', 'FromPort': 22, 'ToPort': 22, 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]},
            {'IpProtocol': 'tcp', 'FromPort': 80, 'ToPort': 80, 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]},
            {'IpProtocol': 'tcp', 'FromPort': 8080, 'ToPort': 8080, 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]},
            {'IpProtocol': 'tcp', 'FromPort': 2049, 'ToPort': 2049, 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]}
        ])
        return sg_id
    except Exception as e:
        print(f"Error SG: {e}"); sys.exit(1)

def get_or_create_efs():
    filesystems = efs.describe_file_systems()
    for fs in filesystems['FileSystems']:
        tags = efs.list_tags_for_resource(ResourceId=fs['FileSystemId'])['Tags']
        if any(t['Value'] == EFS_NAME for t in tags):
            return fs['FileSystemId']
    
    new_fs = efs.create_file_system(CreationToken=EFS_NAME, Tags=[{'Key': 'Name', 'Value': EFS_NAME}])
    return new_fs['FileSystemId']

def setup_efs_mount(fs_id, sg_id):
    subnets = ec2.describe_subnets(Filters=[{'Name': 'default-for-az', 'Values': ['true']}])
    subnet_id = subnets['Subnets'][0]['SubnetId']
    
    while efs.describe_file_systems(FileSystemId=fs_id)['FileSystems'][0]['LifeCycleState'] != 'available':
        time.sleep(5)

    try:
        efs.create_mount_target(FileSystemId=fs_id, SubnetId=subnet_id, SecurityGroups=[sg_id])
        while True:
            targets = efs.describe_mount_targets(FileSystemId=fs_id)
            if any(t['LifeCycleState'] == 'available' for t in targets['MountTargets']): break
            time.sleep(5)
    except ClientError: pass
    return subnet_id

def deploy_instance(sg_id, subnet_id, fs_id):
    # UserData corregido con variables MARIADB_ para compatibilidad total
    user_data_script = f"""#!/bin/bash
apt-get update -y
apt-get install -y docker.io docker-compose nfs-common
systemctl start docker
mkdir -p /home/ubuntu/nextcloud-app
cd /home/ubuntu/nextcloud-app

cat <<EOF > .env
DB_PASSWORD=nextcloud_pwd
DB_ROOT_PASSWORD=root_pwd
DB_USER=nextcloud_user
DB_NAME=nextcloud_db
NC_ADMIN_USER=admin
NC_ADMIN_PASS=admin_password
EOF

cat <<EOF > compose.yaml
version: '3.8'
services:
  mariadb:
    image: mariadb:latest
    container_name: mariadb
    restart: always
    environment:
      MARIADB_ROOT_PASSWORD: ${{DB_ROOT_PASSWORD}}
      MARIADB_PASSWORD: ${{DB_PASSWORD}}
      MARIADB_DATABASE: ${{DB_NAME}}
      MARIADB_USER: ${{DB_USER}}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - nextcloudnet

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: phpmyadmin
    depends_on:
      - mariadb
    ports:
      - "8080:80"
    networks:
      - nextcloudnet

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    depends_on:
      - mariadb
    ports:
      - "80:80"
    environment:
      MYSQL_PASSWORD: ${{DB_PASSWORD}}
      MYSQL_DATABASE: ${{DB_NAME}}
      MYSQL_USER: ${{DB_USER}}
      MYSQL_HOST: mariadb
      NEXTCLOUD_ADMIN_USER: ${{NC_ADMIN_USER}}
      NEXTCLOUD_ADMIN_PASSWORD: ${{NC_ADMIN_PASS}}
    volumes:
      - nc_html:/var/www/html
      - efs_volume:/var/www/html/data
    networks:
      - nextcloudnet

networks:
  nextcloudnet:
    driver: bridge

volumes:
  db_data:
  nc_html:
  efs_volume:
    driver: local
    driver_opts:
      type: nfs
      o: addr={fs_id}.efs.{REGION}.amazonaws.com,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport
      device: ":/"
EOF

docker-compose up -d
chown -R ubuntu:ubuntu /home/ubuntu/nextcloud-app
"""

    instances = ec2.describe_instances(Filters=[
        {'Name': 'tag:Name', 'Values': [INSTANCE_NAME]},
        {'Name': 'instance-state-name', 'Values': ['running', 'pending', 'stopped']}
    ])
    
    if instances['Reservations']:
        inst = instances['Reservations'][0]['Instances'][0]
        instance_id = inst['InstanceId']
        print(f"Instancia existente detectada: {instance_id}. Aplicando cambios...")
        
        # Si está encendida, hay que apagarla para modificar el UserData
        if inst['State']['Name'] != 'stopped':
            print("Apagando instancia para actualizar configuración...")
            ec2.stop_instances(InstanceIds=[instance_id])
            ec2.get_waiter('instance_stopped').wait(InstanceIds=[instance_id])
        
        # Inyectamos el nuevo UserData corregido
        ec2.modify_instance_attribute(
            InstanceId=instance_id, 
            UserData={'Value': base64.b64encode(user_data_script.encode()).decode()}
        )
        ec2.start_instances(InstanceIds=[instance_id])
        return instance_id

    print("Lanzando nueva instancia EC2...")
    run = ec2.run_instances(
        ImageId='ami-0c7217cdde317cfec',
        InstanceType='t2.micro',
        KeyName=KEY_NAME,
        MinCount=1, MaxCount=1,
        SecurityGroupIds=[sg_id],
        SubnetId=subnet_id,
        UserData=user_data_script,
        TagSpecifications=[{'ResourceType': 'instance', 'Tags': [{'Key': 'Name', 'Value': INSTANCE_NAME}]}]
    )
    return run['Instances'][0]['InstanceId']

def get_eip(instance_id):
    eips = ec2.describe_addresses()
    for addr in eips['Addresses']:
        if addr.get('InstanceId') == instance_id:
            return addr['PublicIp']
        if 'InstanceId' not in addr:
            ec2.associate_address(InstanceId=instance_id, AllocationId=addr['AllocationId'])
            return addr['PublicIp']
    
    alloc = ec2.allocate_address(Domain='vpc')
    ec2.associate_address(InstanceId=instance_id, AllocationId=alloc['AllocationId'])
    return alloc['PublicIp']

# --- EJECUCIÓN ---
print("--- Iniciando despliegue de infraestructura ---")
vpc_id = get_or_create_vpc()
sg_id = get_or_create_sg(vpc_id)
fs_id = get_or_create_efs()
sub_id = setup_efs_mount(fs_id, sg_id)
inst_id = deploy_instance(sg_id, sub_id, fs_id)

print(f"Esperando a que la instancia {inst_id} esté 'running'...")
ec2.get_waiter('instance_running').wait(InstanceIds=[inst_id])

pub_ip = get_eip(inst_id)
print(f"\nServidor listo en la IP: {pub_ip}")
print("Esperando 3 minutos para la instalación interna (Docker + EFS)...")
time.sleep(180)

print("\n--- FASE DE CAPTURAS ---")
print(f"Conéctate: ssh -i '/home/juaeslher/Descargas/labsuser.pem' ubuntu@{pub_ip}")
input("Presiona ENTER para finalizar cuando tengas las capturas.")