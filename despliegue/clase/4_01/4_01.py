import boto3
from botocore.exceptions import ClientError

# Inicializar cliente de CloudFormation
cf_client = boto3.client('cloudformation', region_name='us-east-1')

def deploy_stack():
    stack_name = 'rds-example'
    
    # Leer el archivo de la plantilla (ej05.yaml)
    with open('ej05.yaml', 'r') as file:
        template_body = file.read()

    # Parámetros solicitados en la práctica [cite: 31, 32, 33]
    parameters = [
        {'ParameterKey': 'DBPassword', 'ParameterValue': 'Abcd1234'},
        {'ParameterKey': 'KeyPairName', 'ParameterValue': 'vockey'},
        {'ParameterKey': 'EnvironmentType', 'ParameterValue': 'dev'}
    ]

    try:
        print(f"Iniciando despliegue del stack: {stack_name}...")
        cf_client.create_stack(
            StackName=stack_name,
            TemplateBody=template_body,
            Parameters=parameters,
            Capabilities=['CAPABILITY_IAM']
        )
        # Esperar a que la creación termine
        waiter = cf_client.get_waiter('stack_create_complete')
        print("Esperando a que los recursos se completen (esto puede tardar unos minutos)...")
        waiter.wait(StackName=stack_name)
        print("¡Stack creado con éxito!")

    except cf_client.exceptions.AlreadyExistsException:
        print("El stack ya existe. Intentando actualizar...")
        try:
            cf_client.update_stack(
                StackName=stack_name,
                TemplateBody=template_body,
                Parameters=parameters,
                Capabilities=['CAPABILITY_IAM']
            )
            # Esperar a que la actualización termine [cite: 29, 30]
            waiter = cf_client.get_waiter('stack_update_complete')
            print("Actualizando recursos...")
            waiter.wait(StackName=stack_name)
            print("¡Stack actualizado con éxito!")
            
        except ClientError as e:
            if 'No updates are to be performed' in str(e):
                print("No hay cambios que realizar en la plantilla.")
            else:
                raise e

if __name__ == "__main__":
    deploy_stack()