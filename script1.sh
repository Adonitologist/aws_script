#Creo y devuelvo su id
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 192.168.0.0/24 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=MyVpc}]' \
    --query 'Vpc.VpcId' \
    --output text)

#MUESTRO EL ID DE LA VPC
echo $VPC_ID

#
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames "{\"Value\":true}"