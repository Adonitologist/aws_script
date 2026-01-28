#!/bin/bash
echo 1


# Script para cambiar el tipo de una instancia EC2
# Uso: ./cambia_tipo_ec2.sh <instance-id> <nuevo-tipo>

# Colores para mensajes

#Aqui le pedi a la ia que hiciera un sistema de mensajes con colores porque queria mirar a ver que tal quedaba
#ademas de perdirl que escribiera ella los mensajes y las funciones de mensaje y pregunta para ahorrarme tener que escribirlos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Función para mostrar mensajes
error_msg() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success_msg() {
    echo -e "${GREEN}[OK]${NC} $1"
}

info_msg() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning_msg() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

echo 2

#La expresion "  $? " devuelve el codigo de salida del ultimo comando ejecutado
# " ne " es not equal

# Comprobar parámetros
if [ $# -ne 2 ]; then
    error_msg "Número incorrecto de parámetros"
    echo "Uso: $0 <instance-id> <nuevo-tipo-instancia>"
    echo "Ejemplo: $0 i-02d162da757f64b65 t3.small"
    exit 1
fi

INSTANCE_ID=$1
NEW_TYPE=$2

info_msg "Verificando existencia de la instancia $INSTANCE_ID..."

# Comprobar que la instancia existe
INSTANCE_INFO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" 2>&1)

if [ $? -ne 0 ]; then
    error_msg "La instancia $INSTANCE_ID no existe o no tienes permisos para acceder a ella"
    exit 1
fi

success_msg "Instancia encontrada"

# Obtener el estado y tipo actual de la instancia
CURRENT_STATE=$(echo "$INSTANCE_INFO" | grep -o '"Name": "[^"]*"' | head -1 | cut -d'"' -f4)
CURRENT_TYPE=$(echo "$INSTANCE_INFO" | grep '"InstanceType"' | head -1 | awk -F'"' '{print $4}')

info_msg "Estado actual: $CURRENT_STATE"
info_msg "Tipo actual: $CURRENT_TYPE"
info_msg "Tipo solicitado: $NEW_TYPE"

# Comprobar si el tipo nuevo es igual al actual
if [ "$CURRENT_TYPE" = "$NEW_TYPE" ]; then
    warning_msg "El tipo de instancia solicitado ($NEW_TYPE) es el mismo que el actual"
    warning_msg "No se requiere ningún cambio"
    exit 0
fi

# Advertir al usuario y dar opción de abortar
echo ""
warning_msg "ATENCIÓN: Este proceso detendrá la instancia $INSTANCE_ID"
warning_msg "La instancia será cambiada de tipo $CURRENT_TYPE a $NEW_TYPE"
read -p "¿Desea continuar? (s/n): " respuesta

if [ "$respuesta" != "s" ] && [ "$respuesta" != "S" ]; then
    info_msg "Proceso abortado por el usuario"
    exit 0
fi

echo ""
info_msg "Iniciando proceso de cambio de tipo..."

# Si la instancia está running, pararla
if [ "$CURRENT_STATE" = "running" ]; then
    info_msg "Deteniendo la instancia..."
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        error_msg "Error al detener la instancia"
        exit 1
    fi
    
    info_msg "Esperando a que la instancia se detenga..."
    aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
    
    if [ $? -ne 0 ]; then
        error_msg "Timeout esperando a que la instancia se detenga"
        exit 1
    fi
    
    success_msg "Instancia detenida correctamente"
elif [ "$CURRENT_STATE" = "stopped" ]; then
    info_msg "La instancia ya está detenida"
else
    warning_msg "La instancia está en estado: $CURRENT_STATE"
    info_msg "Esperando a que la instancia se detenga..."
    aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
fi

# Cambiar el tipo de instancia
info_msg "Cambiando el tipo de instancia a $NEW_TYPE..."
aws ec2 modify-instance-attribute --instance-id "$INSTANCE_ID" --instance-type "{\"Value\": \"$NEW_TYPE\"}" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    error_msg "Error al cambiar el tipo de instancia"
    error_msg "Verifica que el tipo $NEW_TYPE sea válido y esté disponible en tu región"
    exit 1
fi

success_msg "Tipo de instancia cambiado correctamente"

# Arrancar la instancia
info_msg "Arrancando la instancia..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    error_msg "Error al arrancar la instancia"
    exit 1
fi

info_msg "Esperando a que la instancia esté en ejecución..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

if [ $? -ne 0 ]; then
    error_msg "Timeout esperando a que la instancia arranque"
    exit 1
fi

success_msg "Instancia arrancada correctamente"

# Verificar el cambio
FINAL_TYPE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" | grep '"InstanceType"' | head -1 | awk -F'"' '{print $4}')