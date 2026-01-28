import boto3
import os
import time
from botocore.exceptions import ClientError, WaiterError

# Inicializar cliente de CloudFormation
cf_client = boto3.client('cloudformation', region_name='us-east-1')

def deploy_stack():
    stack_name = 'rds-example'
    
    base_path = os.path.dirname(os.path.abspath(__file__))
    yaml_path = os.path.join(base_path, '4_01.yaml')
    
    try:
        with open(yaml_path, 'r') as file:
            template_body = file.read()
    except FileNotFoundError:
        print(f"Error: No se encontró el archivo {yaml_path}")
        return

    parameters = [
        {'ParameterKey': 'DBPassword', 'ParameterValue': 'ComplexPassw0rd!'}, 
        {'ParameterKey': 'KeyPairName', 'ParameterValue': 'vockey'},
        {'ParameterKey': 'EnvironmentType', 'ParameterValue': 'dev'}
    ]

    try:
        # Check current status of the stack
        response = cf_client.describe_stacks(StackName=stack_name)
        status = response['Stacks'][0]['StackStatus']
        
        if status == 'ROLLBACK_COMPLETE':
            print(f"El stack {stack_name} está en ROLLBACK_COMPLETE. Eliminando para reintentar...")
            cf_client.delete_stack(StackName=stack_name)
            waiter = cf_client.get_waiter('stack_delete_complete')
            waiter.wait(StackName=stack_name)
            print("Stack eliminado. Procediendo con la creación limpia...")
            # After deletion, we trigger the creation logic
            raise cf_client.exceptions.ClientError({"Error": {"Code": "NotFound"}}, "DescribeStacks")

        print(f"Intentando actualizar el stack existente: {stack_name}...")
        cf_client.update_stack(
            StackName=stack_name,
            TemplateBody=template_body,
            Parameters=parameters,
            Capabilities=['CAPABILITY_IAM']
        )
        waiter = cf_client.get_waiter('stack_update_complete')
        print("Actualizando recursos...")
        waiter.wait(StackName=stack_name)
        print("¡Stack actualizado con éxito!")

    except (cf_client.exceptions.ClientError, ClientError) as e:
        error_code = e.response['Error']['Code']
        
        # If stack doesn't exist (or was just deleted), create it
        if error_code == 'ValidationError' or 'does not exist' in str(e) or error_code == 'NotFound':
            try:
                print(f"Creando nuevo stack: {stack_name}...")
                cf_client.create_stack(
                    StackName=stack_name,
                    TemplateBody=template_body,
                    Parameters=parameters,
                    Capabilities=['CAPABILITY_IAM']
                )
                waiter = cf_client.get_waiter('stack_create_complete')
                print("Esperando a que los recursos se completen...")
                waiter.wait(StackName=stack_name)
                print("¡Stack creado con éxito!")
            except WaiterError:
                print("\n[!] ERROR: El nuevo intento también falló.")
                print("Por favor, revisa 'Events' en la consola de AWS CloudFormation.")
        elif 'No updates are to be performed' in str(e):
            print("No hay cambios que realizar.")
        else:
            print(f"Error inesperado: {e}")

if __name__ == "__main__":
    deploy_stack()