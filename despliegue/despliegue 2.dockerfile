# Crear Target Group
aws elbv2 create-target-group \
    --name green-blue-tg \
    --protocol TCP \
    --port 80 \
    --vpc-id vpc-0d462b5de4f158831 \
    --health-check-protocol HTTP \
    --health-check-path / \
    --target-type instance

# Crear Load Balancer
aws elbv2 create-load-balancer \
    --name my-green-blue-lb \
    --subnets subnet-0bb4bacea9f0f2de7 subnet-068ac2fae6842f492 \
    --scheme internet-facing \
    --type network \
    --ip-address-type ipv4

# Registrar targets en el Target Group
aws elbv2 register-targets \
    --target-group-arn "arn:aws:elasticloadbalancing:REGION:ACCOUNT-ID:targetgroup/green-blue-tg/TARGETGROUP-ID" \
    --targets Id=i-05Saabb26cfa0dc28 Id=i-0f8ec103e675f6c7b

# Crear Listener
aws elbv2 create-listener \
    --load-balancer-arn "arn:aws:elasticloadbalancing:us-east-1:218393655875:loadbalancer/net/my-green-blue-lb/ba0b6a5cddf7fdab" \
    --protocol TCP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="arn:aws:elasticloadbalancing:us-east-1:218393655875:targetgroup/green-blue-tg/15da0637d937f3e7"