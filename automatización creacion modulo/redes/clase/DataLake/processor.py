import os
import logging
import boto3
from botocore.exceptions import ClientError
import pandas as pd
from collections import defaultdict

# Configuración de los nombres de los buckets
inputBucket = os.environ['input_bucket']    # Bucket de donde se lee el CSV original
outputBucket = os.environ['output_bucket']  # Bucket donde se guardará el resultado procesado

def lambda_handler(event, context):
    # Función principal coordinada por AWS Lambda
    # Descarga el archivo de datos desde S3 al almacenamiento temporal
    download_file(file_name='cart_abandonment_data.csv', bucket=inputBucket)
    
    # Procesa el archivo 
    process_file(file_name='cart_abandonment_data.csv')
    
    # Sube el archivo final con los resultados al bucket de salida
    upload_file(file_name='/tmp/cart_aggregated_data.csv', bucket=outputBucket)
    
def download_file(file_name, bucket, object_name=None):
    # Descarga un objeto desde un bucket de S3 al directorio /tmp de la Lambda (Unico sitio donde podemos escribir datos en lambda que no sean parte del codigo)
    s3 = boto3.client('s3')
    # Se especifica la ruta acia el s3 que recibira los datos
    s3.download_file(bucket, file_name, '/tmp/' + file_name)

def process_file(file_name):
    # Lee los datos y calcula el total de productos que al final no fueron comprados para generar un nuevo CSV
    # Carga el archivo CSV descargado ignorando la primera columna de índice
    raw_data = pd.read_csv('/tmp/'+file_name, index_col=0)
    
    # Lógica de agregación:
    # - Agrupa por "product_id"
    # - Suma la columna "product_amount" para cada producto
    # - Coge los primeros 50 registros y los ordena de mayor a menor
    aggregate_data = raw_data.groupby('product_id')['product_amount'].sum().head(50).nlargest(50)
    
    # Cambia el nombre de columnas y sesetae el índice para que el formato sea mas limpio
    aggregate_data.columns = ['product_id', 'abandoned_amount']
    aggregate_data = aggregate_data.reset_index()
    
    # Imprime los primeros 15 resultados en los logs
    print(aggregate_data.head(15))
    
    # Guarda el resultado final en un nuevo archivo CSV en el directorio temporal
    aggregate_data.to_csv('/tmp/cart_aggregated_data.csv')

def upload_file(file_name, bucket, object_name=None):
    # Sube un archivo local desde la Lambda hacia un bucket de S3
    # Si no se especifica nombre para S3, se usa el nombre del archivo local
    if object_name is None:
        object_name = os.path.basename(file_name)

    s3_client = boto3.client('s3')
    try:
        # Ejecuta la carga del archivo
        response = s3_client.upload_file(file_name, bucket, object_name)
    except ClientError as e:
        # Captura errores de permisos o de red y los registra
        logging.error(e)
        return False
    return True