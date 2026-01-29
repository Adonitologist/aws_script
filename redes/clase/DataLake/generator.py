from faker import Faker
import random
from faker.providers import bank, credit_card, date_time, profile, currency, user_agent
import logging
import boto3
from botocore.exceptions import ClientError
import os
import pandas as pd
from collections import defaultdict

# Recupera el nombre del bucket de S3 desde las variables de entorno de la funciojn Lambda
inputBucket = os.environ['input_bucket']

def lambda_handler(event, context):
    #Punto de entrada de la función AWS Lambda
    # 1. Genera el archivo CSV localmente en el entorno temporal
    generate_data()
    # 2. Sube ese archivo generado al bucket de S3 que elijamos
    upload_file(file_name='/tmp/cart_abandonment_data.csv', bucket=inputBucket)
    
def generate_data():
    #Genera datos ficticios de carritos de compra y los guarda en un CSV
    fake = Faker()
    fake.add_provider(currency) # Añade soporte para generar etiquetas de precios

    fake_data = defaultdict(list)
    
    # Genera 1000 filas de datos aleatorios
    for _ in range(1000):
        fake_data["cart_id"].append(random.randint(0, 10))  #Caarro
        fake_data["customer_id"].append(random.randint(0, 10))  #Cliente
        fake_data["product_id"].append(random.randint(0, 10))   #Producto
        fake_data["product_amount"].append(random.randint(1, 20))   #Cantidad del producto
        fake_data["product_price"].append(fake.pricetag())  #Precio

    # Crea un DataFrame de Panda para organizar los datos
    df_fake_data = pd.DataFrame(fake_data)
    
    # Muestra los primeros registros en los logs de CloudWatch
    print(df_fake_data.head())
    
    # Guarda el archivo en el directorio /tmp (único sitio para poder hacer una escritura en lambda)
    df_fake_data.to_csv("/tmp/cart_abandonment_data.csv")

def upload_file(file_name, bucket, object_name=None):
    #Sube el archivo local al bucket de S3

    # Si no se define un nombre de objeto, usa el mismo nombre del archivo original
    if object_name is None:
        object_name = os.path.basename(file_name)

    # Crea el cliente de conexión con el servicio S3
    s3_client = boto3.client('s3')
    
    try:
        # Intenta subir el archivo al destino especificado
        response = s3_client.upload_file(file_name, bucket, object_name)
    except ClientError as e:
        # Registra el error si algo falla
        logging.error(e)
        return False
    return True