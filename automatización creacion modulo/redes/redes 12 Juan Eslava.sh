# Configuraciones de red 

export VPC_CIDR="172.16.0.0/16"  

export SUBNET_CIDR="172.16.0.0/20"  

export VPC_NAME="proyecto-vpc"  

 

export REGION="us-east-1" 

export AZ="us-east-1a" 

export KEY_NAME="labsuser"  

export SG_NAME="migs"  

 

 

# 1. Crear la VPC 

echo "Creando VPC..." 

VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.VpcId' --output text --region $REGION) 

echo "VPC ID: $VPC_ID" 

 

# 2. Etiquetar la VPC 

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME --region $REGION 

 

# 3. Habilitar soporte DNS (necesario para nombres de host) 

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION 

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION 

 

# 4. Crear la subred pública 

echo "Creando subred pública..." 

SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR --availability-zone $AZ --query 'Subnet.SubnetId' --output text --region $REGION) 

echo "Subred ID: $SUBNET_ID" 

 

# 5. Etiquetar la subred 

aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value="$VPC_NAME-public-subnet" --region $REGION 

 

# 6. Habilitar asignación automática de IP pública (CRÍTICO para subred pública) 

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region $REGION 

 

# 7. Crear el Internet Gateway 

echo "Creando Internet Gateway (IGW)..." 

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region $REGION) 

echo "IGW ID: $IGW_ID" 

 

# 8. Etiquetar IGW 

aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value="$VPC_NAME-igw" --region $REGION 

 

# 9. Adjuntar el IGW a la VPC 

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION 

 

# 10. Crear la Tabla de Enrutamiento Pública (RTB) 

echo "Creando Tabla de Enrutamiento Pública (RTB)..." 

RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region $REGION) 

echo "RTB ID: $RTB_ID" 

 

# 11. Etiquetar RTB 

aws ec2 create-tags --resources $RTB_ID --tags Key=Name,Value="$VPC_NAME-public-rtb" --region $REGION 

 

# 12. Agregar la ruta por defecto (0.0.0.0/0) al IGW 

aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION 

 

# 13. Asociar la RTB a la subred pública 

aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $SUBNET_ID --region $REGION 

 

 

# 14. Crear par de claves 

echo "Creando clave SSH..." 

aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text --region $REGION > $KEY_NAME.pem 

chmod 400 $KEY_NAME.pem 

 

# 15. Crear Grupo de Seguridad (Firewall) 

echo "Creando Grupo de Seguridad..." 

SG_ID=$(aws ec2 create-security-group --vpc-id $VPC_ID --group-name $SG_NAME --description "SSH access from everywhere" --query 'GroupId' --output text --region $REGION) 

echo "Security Group ID: $SG_ID" 

 

# 16. Abrir puerto 22 (SSH) para el acceso exterior 

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION 

 

AMI_ID="ami-0ecb62995f68bb549" 

 

# 17. Lanzar la instancia EC2 en la subred pública 

echo "Lanzando instancia EC2..." 

INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $KEY_NAME --security-group-ids $SG_ID --subnet-id $SUBNET_ID --query 'Instances[0].InstanceId' --output text --region $REGION) 

echo "Instancia ID: $INSTANCE_ID" 

 

# 18. Etiquetar instancia 

aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value="$VPC_NAME-webserver" --region $REGION 

 

# 19. Esperar a que la instancia esté lista 

echo "Esperando a que la instancia esté en estado 'running'..." 

aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION 

 

# 20. Obtener la IP pública de la instancia 

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --region $REGION) 

echo "IP Pública: $PUBLIC_IP" 

 

# 21. Intentar la conexión SSH 

echo "Intentando conexión SSH. Confirma con 'yes' si es la primera vez." 

ssh -i $KEY_NAME.pem ubuntu@$PUBLIC_IP 

 