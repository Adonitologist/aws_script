#Crear y guardar Labuser 

aws ec2 create-key-pair --key-name labsuser --query 'KeyMaterial' --output text > labsuser.pem 

#Crear y guardar Vockey 

aws ec2 create-key-pair --key-name vockey2 --query 'KeyMaterial' --output text > vockey2.pem 

 

chmod 400 labsuser.pem vockey2.pem 

 

 

 

# ==================================================================== 

# DEFINICIÓN DE VARIABLES - ¡MODIFICA ESTOS VALORES! 

# ==================================================================== 

 

# 1. Tu IP Pública (Necesaria para el acceso SSH inicial al Bastión) se puede usar el  

#comando curl ifconfig.me 

MY_IP_PUBLIC="213.0.87.21/32" 

 

 

#VPC crear 

 

# Crea la VPC con el CIDR requerido 

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text) 

echo "VPC ID creada: $VPC_ID" 

 

 

# Habilita los nombres DNS para la nueva VPC 

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support '{"Value":true}' 

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames '{"Value":true}' 

 

# SUBRED PUBLICA crear 

 

 

# 2.1 Crear el Internet Gateway (IGW) 

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text) 

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID 

 

# 2.2 Crear la Subred 

SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --query 'Subnet.SubnetId' --output text) 

echo "Subred ID creada: $SUBNET_ID" 

 

# 2.3 Habilitar la asignación automática de IP pública en la subred 

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch 

 

# 2.4 Crear y configurar la tabla de ruteo para el tráfico a Internet 

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text) 

# Añade la ruta por defecto (0.0.0.0/0) al IGW 

aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID 

# Asocia la tabla de ruteo a la subred 

aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RTB_ID 

 

echo "VPC $VPC_ID y Subred $SUBNET_ID creadas y configuradas." 

 

# AMI crear 

 

# ID de la AMI de Ubuntu 22.04 LTS (Ejemplo para us-east-1, busca la correcta para tu región) 

AMI_ID="ami-0ecb62995f68bb549" 

 

 

# GRUPOS DE SEGURIDAD crear 

# 1. Crear Grupo de Seguridad del Bastión 

SG_BASTION_ID=$(aws ec2 create-security-group --group-name gs_bastion --description "Acceso SSH al Bastion" --vpc-id $VPC_ID --query 'GroupId' --output text) 

echo "ID del Grupo de Seguridad del Bastión (gs_bastion): $SG_BASTION_ID" 

 

# 2. Permitir SSH (puerto 22) desde tu IP pública 

aws ec2 authorize-security-group-ingress --group-id $SG_BASTION_ID --protocol tcp --port 22 --cidr $MY_IP_PUBLIC 

 

echo "gs_bastion configurado: SSH solo desde $MY_IP_PUBLIC." 

 

 

# crear APP y configurar 

# 1. Crear Grupo de Seguridad de la Aplicación 

NOMBRE_APLICACION="miapp-ape-juaneslava" 

 

SG_APP_ID=$(aws ec2 create-security-group --group-name $NOMBRE_APLICACION --description "Reglas encadenadas para la App" --vpc-id $VPC_ID --query 'GroupId' --output text) 

echo "ID del Grupo de Seguridad de la Aplicación ($NOMBRE_APLICACION): $SG_APP_ID" 

 

# 2. Permitir HTTPS (puerto 443) desde cualquier origen (0.0.0.0/0)  

aws ec2 authorize-security-group-ingress --group-id $SG_APP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 

 

# 3. Permitir SSH (puerto 22) solo desde el Grupo de Seguridad del Bastión (ENCADENADO)  

aws ec2 authorize-security-group-ingress --group-id $SG_APP_ID --protocol tcp --port 22 --source-group $SG_BASTION_ID 

 

echo "$NOMBRE_APLICACION configurado: HTTPS (0.0.0.0/0) y SSH (solo desde gs_bastion)." 

 

 

 

# EC2 lanzar 

# ec2 server ssh 

aws ec2 run-instances --image-id $AMI_ID \ 

--count 1 \ 

--instance-type t3.micro \ 

--key-name labsuser \ 

--security-group-ids $SG_BASTION_ID \ 

--subnet-id $SUBNET_ID \ 

--private-ip-address 10.0.1.20 \ 

--associate-public-ip-address \ 

--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=SSHServer}]' 

 

echo "Instancia SSHServer lanzada." 

 

# ec2 aplicacion 

aws ec2 run-instances --image-id $AMI_ID \ 

--count 1 \ 

--instance-type t3.micro \ 

--key-name vockey2 \ 

--security-group-ids $SG_APP_ID \ 

--subnet-id $SUBNET_ID \ 

--private-ip-address 10.0.1.30 \ 

--associate-public-ip-address \ 

--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=mi_app}]' 

 

echo "Instancia mi_app lanzada." 

 

 

#OBTENER LA IP PUBLICA DEL BASTION 

#cuando las instancias esten listas del todo 

echo "Esperando a que las instancias estén listas..." 

sleep 60 

 

IP_BASTION=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=SSHServer" --query "Reservations[].Instances[0].PublicIpAddress" --output text) 

echo "IP Pública del Bastión: $IP_BASTION" 

 

 

 

 

# CONECXIONES 

# 1. Iniciar el agente ssh  

eval $(ssh-agent) 

 

# 2. Cargar clave del bastión  

ssh-add labsuser.pem 

 

# 3. Cargar clave de la aplicación  

ssh-add vockey2.pem 

 

# 4. Verificar claves cargadas  

ssh-add -l 

 

# 1. Conexión al Bastión (usando -A para reenvío de clave) 

echo "Conectando al Bastión: ssh -A ubuntu@$IP_BASTION" 

ssh -A ubuntu@$IP_BASTION 

 

# 2. Una vez conectado al Bastión, ejecuta *dentro de la sesión SSH* el siguiente comando: 

echo "Una vez conectado al Bastión, ejecuta: ssh ubuntu@10.0.1.30" 

 

# CAPTURA 

 

 

# PING ENCADENADO 

# Permitir Todo el ICMP (ping) en la aplicación, solo desde el Grupo de Seguridad del Bastión 

aws ec2 authorize-security-group-ingress --group-id $SG_APP_ID --protocol icmp --port -1 --source-group $SG_BASTION_ID 

 

echo "Ping configurado: solo permitido desde el Bastión." 

 

ping -c 4 10.0.1.30 

 

 