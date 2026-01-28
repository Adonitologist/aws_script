import boto3


def crear_vpc():
    # Crear cliente de EC2
    ec2 = boto3.client('ec2')
    
    # Crear la VPC
    vpc = ec2.create_vpc(CidrBlock='172.16.0.0/16')
    vpc_id = vpc['Vpc']['VpcId']
    print("VPC creada:", vpc_id)
    
    # Habilitar DNS support
    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsSupport={'Value': True}
    )
    
    # Habilitar DNS hostnames
    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsHostnames={'Value': True}
    )
    
    
    # Etiquetar la VPC (opcional)
    ec2.create_tags(
        Resources=[vpc_id],
        Tags=[{'Key': 'Name', 'Value': 'MiVPC-Boto'}]
    )
    
    return vpc_id

if __name__ == "__main__":
    vpc_id = crear_vpc()
    print("VPC ID final:", vpc_id)