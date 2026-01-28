#!/bin/bash 

# 

# Práctica AWS CLI: ACLs personalizadas 

# 

KEY_PAIR_NAME="labsuser" 

 

# Nota: Si AMI_ID no está definido en el entorno, el 'resolve:ssm' en el run-instances lo encontrará. 

# Si lo usas manualmente, asegúrate de que el ID sea el de la región actual. 

AMI_ID="ami-0ecb62995f68bb549"  

 

# ---------------------------------------------------------------------------- 

## 1. CONFIGURACIÓN BASE DE LA RED (VPC, Subredes, IGW) 

# ---------------------------------------------------------------------------- 

 

echo "--- 1. CONFIGURACIÓN BASE DE LA RED ---" 

 

# 1.1 Crear la VPC (10.0.0.0/16) 

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text) 

echo "VPC ID: $VPC_ID" 

 

# 1.2 Crear y adjuntar el Internet Gateway (IGW) 

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text) 

aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID 

echo "IGW ID: $IGW_ID" 

 

# 1.3 Obtener la Tabla de Ruteo Principal (Main RT) y crear ruta a Internet 

MAIN_RT_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" --query 'RouteTables[0].RouteTableId' --output text) 

aws ec2 create-route --route-table-id $MAIN_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID 

echo "Main Route Table ID: $MAIN_RT_ID" 

 

# 1.4 Crear Subnet 1 (Prueba SG) y Subnet 2 (Prueba NACL) 

SUBNET_SG_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --query 'Subnet.SubnetId' --output text) 

SUBNET_NACL_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --query 'Subnet.SubnetId' --output text) 

echo "Subnet SG ID: $SUBNET_SG_ID" 

echo "Subnet NACL ID: $SUBNET_NACL_ID" 

 

# 1.5 Habilitar la asignación automática de IP pública en ambas subredes 

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_SG_ID --map-public-ip-on-launch 

aws ec2 modify-subnet-attribute --subnet-id $SUBNET_NACL_ID --map-public-ip-on-launch 

echo "Asignación de IP pública habilitada." 

 

 

# ---------------------------------------------------------------------------- 

## 1.6 ASEGURAR NACL PARA SUBNET_SG_ID (Necesario para asegurar que el SG es el único control) 

# ---------------------------------------------------------------------------- 

echo "--- 1.6 ASEGURANDO NACL DE SUBNET SG ---" 

 

# 1.6.1 Obtener el ID de la NACL asociada a la Subnet SG (debería ser la NACL por defecto) 

NACL_SG_ID=$(aws ec2 describe-network-acls \ 

--filters "Name=association.subnet-id,Values=$SUBNET_SG_ID" \ 

--query 'NetworkAcls[0].NetworkAclId' \ 

--output text) 

echo "NACL de la Subnet SG: $NACL_SG_ID" 

 

# 1.6.2 Regla de ENTRADA: Permitir ICMP (Rule 10) 

aws ec2 create-network-acl-entry \ 

--network-acl-id $NACL_SG_ID \ 

--rule-number 10 \ 

--protocol icmp \ 

--ingress \ 

--rule-action allow \ 

--cidr-block 0.0.0.0/0 \ 

--icmp-type-code Type=-1,Code=-1 

 

# 1.6.3 Regla de SALIDA: Permitir ICMP (Ping) 

aws ec2 create-network-acl-entry \ 

--network-acl-id $NACL_SG_ID \ 

--rule-number 10 \ 

--protocol icmp \ 

--egress \ 

--rule-action allow \ 

--cidr-block 0.0.0.0/0 \ 

--icmp-type-code Type=-1,Code=-1 

 

# 1.6.4 Regla de SALIDA: Permitir Puertos Efímeros TCP para tráfico de vuelta (ej: SSH) (Rule 20) 

aws ec2 create-network-acl-entry \ 

--network-acl-id $NACL_SG_ID \ 

--rule-number 20 \ 

--protocol tcp \ 

--egress \ 

--rule-action allow \ 

--cidr-block 0.0.0.0/0 \ 

--port-range From=1024,To=65535 

echo "NACL de Subnet SG configurada para permitir tráfico necesario." 

 

 

# ---------------------------------------------------------------------------- 

## 2. PRUEBA 1: GRUPO DE SEGURIDAD (STATEFUL) 

# ---------------------------------------------------------------------------- 

 

echo -e "\n--- 2. PRUEBA 1: GRUPO DE SEGURIDAD (STATEFUL) ---" 

 

# 2.1 Crear el Grupo de Seguridad (SG) para permitir solo INGRESS (entrada) de ping y SSH. 

SG_PING_ID=$(aws ec2 create-security-group \ 

--group-name PingSG \ 

--description "Solo permite entrada ICMP y SSH. Egress (salida) es ALL por defecto." \ 

--vpc-id $VPC_ID \ 

--query 'GroupId' --output text) 

echo "Security Group ID: $SG_PING_ID" 

 

# 2.2 Permitir SSH (TCP/22) de cualquier origen 

aws ec2 authorize-security-group-ingress \ 

--group-id $SG_PING_ID \ 

--protocol tcp \ 

--port 22 \ 

--cidr 0.0.0.0/0 

 

# 2.3 Permitir Ping (ICMP) de cualquier origen (solo INGRESS) 

aws ec2 authorize-security-group-ingress \ 

--group-id $SG_PING_ID \ 

--protocol icmp \ 

--cidr 0.0.0.0/0 \ 

--port -1 

 

# 2.4 Lanzar Instancia EC2 en Subnet 1 con el SG 

echo "Lanzando instancia EC2-SG en Subnet 1..." 

# Usar AMI_ID definida o el resolve:ssm si la variable no se usa 

aws ec2 run-instances_args="--image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2" 

if [ ! -z "$AMI_ID" ]; then 

aws ec2 run-instances_args="--image-id $AMI_ID" 

fi 

 

RUN_SG_OUTPUT=$(aws ec2 run-instances \ 

--image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \ 

--instance-type t2.micro \ 

--subnet-id $SUBNET_SG_ID \ 

--security-group-ids $SG_PING_ID \ 

--associate-public-ip-address \ 

--key-name $KEY_PAIR_NAME \ 

--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EC2-SG}]' \ 

--query 'Instances[0].InstanceId' --output text) 

 

# Esperar a que la instancia obtenga una IP y esté lista 

echo "Esperando a que la instancia EC2-SG esté running..." 

aws ec2 wait instance-running --instance-ids $RUN_SG_OUTPUT 

IP_SG=$(aws ec2 describe-instances --instance-ids $RUN_SG_OUTPUT --query 'Reservations[0].Instances[0].PublicIpAddress' --output text) 

echo "IP Pública EC2-SG: $IP_SG" 

 

# 2.5 REALIZAR PRUEBA: Ping a $IP_SG 

echo ">>> PRUEBA SG (STATEFUL): Ejecuta 'ping $IP_SG'" 

echo ">>> Resultado esperado: Ping FUNCIONA (La respuesta de salida es permitida automáticamente)." 

# ¡Recordar captura de pantalla del ping exitoso! 

 

# ---------------------------------------------------------------------------- 

## 3. PRUEBA 2: NACL (STATELESS - FALLO ESPERADO) 

# ---------------------------------------------------------------------------- 

 

echo -e "\n--- 3. PRUEBA 2: NACL (STATELESS - FALLO ESPERADO) ---" 

 

# 3.1 Crear la NACL 

NACL_ID=$(aws ec2 create-network-acl --vpc-id $VPC_ID --query 'NetworkAcl.NetworkAclId' --output text) 

echo "NACL ID: $NACL_ID" 

 

# 3.2 Obtener el SG por defecto de la VPC para usarlo en la instancia NACL (para que el SG no interfiera) 

DEFAULT_SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text) 

 

# 3.3 Lanzar Instancia EC2 en Subnet 2 con el SG por defecto 

echo "Lanzando instancia EC2-NACL en Subnet 2..." 

RUN_NACL_OUTPUT=$(aws ec2 run-instances \ 

--image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \ 

--instance-type t2.micro \ 

--subnet-id $SUBNET_NACL_ID \ 

--security-group-ids $DEFAULT_SG_ID \ 

--associate-public-ip-address \ 

--key-name $KEY_PAIR_NAME \ 

--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=EC2-NACL}]' \ 

--query 'Instances[0].InstanceId' --output text) 

 

# Esperar a que la instancia obtenga una IP 

echo "Esperando a que la instancia EC2-NACL esté running..." 

aws ec2 wait instance-running --instance-ids $RUN_NACL_OUTPUT 

IP_NACL=$(aws ec2 describe-instances --instance-ids $RUN_NACL_OUTPUT --query 'Reservations[0].Instances[0].PublicIpAddress' --output text) 

echo "IP Pública EC2-NACL: $IP_NACL" 

 

# 3.4 Asociar la NACL a la Subnet 2 (Prueba NACL) 

ASSOC_ID=$(aws ec2 describe-network-acls \ 

--filters "Name=association.subnet-id,Values=$SUBNET_NACL_ID" \ 

--query 'NetworkAcls[0].Associations[0].NetworkAclAssociationId' --output text) 

 

aws ec2 replace-network-acl-association \ 

--association-id $ASSOC_ID \ 

--network-acl-id $NACL_ID 

 

# 3.5 Configurar reglas de ENTRADA (INGRESS) en la NACL (Permitir ICMP y SSH) 

# ICMP (Ping) 

aws ec2 create-network-acl-entry \ 

--network-acl-id $NACL_ID \ 

--rule-number 100 \ 

--protocol icmp \ 

--ingress \ 

--rule-action allow \ 

--cidr-block 0.0.0.0/0 \ 

--icmp-type-code Type=-1,Code=-1 

# SSH 

aws ec2 create-network-acl-entry \ 

--network-acl-id $NACL_ID \ 

--rule-number 110 \ 

--protocol tcp \ 

--ingress \ 

--rule-action allow \ 

--cidr-block 0.0.0.0/0 \ 

--port-range From=22,To=22 

 

# 3.6 NO configurar reglas de SALIDA (EGRESS) explícitas. El tráfico de respuesta será denegado por la regla * DENY 

echo "NACL configurada con solo reglas INGRESS. Sin reglas EGRESS para ICMP." 

 

# 3.7 REALIZAR PRUEBA: Ping a $IP_NACL 

echo ">>> PRUEBA NACL SIN EGRESS (STATELESS): Ejecuta 'ping $IP_NACL'" 

echo ">>> Resultado esperado: Ping NO FUNCIONA (Request timeout. La NACL bloquea la respuesta de salida)." 

# ¡Recordar captura de pantalla del ping fallido! 

 

# ---------------------------------------------------------------------------- 

## 4. PRUEBA 3: NACL (AÑADIR REGLA DE SALIDA - ÉXITO) 

# ---------------------------------------------------------------------------- 

 

echo -e "\n--- 4. PRUEBA 3: NACL (AÑADIR REGLA DE SALIDA) ---" 

 

# 4.1 Añadir regla de SALIDA (EGRESS) explícita para ICMP (Ping) 

aws ec2 create-network-acl-entry \ 

--network-acl-id $NACL_ID \ 

--rule-number 100 \ 

--protocol icmp \ 

--egress \ 

--rule-action allow \ 

--cidr-block 0.0.0.0/0 \ 

--icmp-type-code Type=-1,Code=-1 

 

# 4.2 Añadir regla de SALIDA (EGRESS) para Puertos Efímeros (Necesario para el tráfico de respuesta general TCP/UDP como SSH) 

aws ec2 create-network-acl-entry \ 

--network-acl-id $NACL_ID \ 

--rule-number 110 \ 

--protocol tcp \ 

--egress \ 

--rule-action allow \ 

--cidr-block 0.0.0.0/0 \ 

--port-range From=1024,To=65535 

echo "Reglas EGRESS añadidas a la NACL (ICMP y puertos efímeros)." 

 

# 4.3 REALIZAR PRUEBA: Ping a $IP_NACL 

echo ">>> PRUEBA NACL CON EGRESS: Ejecuta de nuevo 'ping $IP_NACL'" 

echo ">>> Resultado esperado: Ping FUNCIONA (La respuesta de salida está permitida explícitamente)." 

# ¡Recordar captura de pantalla del ping exitoso final! 

 

# ---------------------------------------------------------------------------- 

## 5. LIMPIEZA DE RECURSOS (OPCIONAL) 

# ---------------------------------------------------------------------------- 

: ' 

# Eliminar recursos 

' 

 