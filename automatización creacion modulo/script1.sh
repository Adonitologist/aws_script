#!/bin/bash

# Crear una VPC y devolver su ID
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 192.168.0.0/24 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=MyVpc}]' \
  --query 'Vpc.VpcId' \
  --output text)

echo "VPC creada con ID: $VPC_ID"

# Habilitar DNS en la VPC
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"

# Crear subred dentro de la VPC
SUB_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 192.168.0.0/28 \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=MiSubred1}]' \
  --query 'Subnet.SubnetId' \
  --output text)

echo "Subred creada con ID: $SUB_ID"

aws ec2 modify-subnet-attribute --subnet-id $SUB_ID --map-public-ip-on-launch