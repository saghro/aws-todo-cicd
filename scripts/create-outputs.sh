#!/bin/bash

# Script pour créer le fichier outputs.txt à partir de la stack CloudFormation
# Usage: ./scripts/create-outputs.sh

set -e

STACK_NAME="todo-app-stack"
REGION="us-east-1"
ENV_NAME="prod"
KEY_PAIR_NAME="todo-app-key"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Vérifier que la stack existe
log_info "Vérification de la stack CloudFormation..."
STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].StackStatus" \
    --output text \
    --region $REGION 2>/dev/null || echo "NOT_FOUND")

if [ "$STATUS" = "NOT_FOUND" ]; then
    log_error "Stack '$STACK_NAME' non trouvée"
    exit 1
fi

if [ "$STATUS" != "CREATE_COMPLETE" ]; then
    log_warn "Stack en statut: $STATUS"
    log_warn "Le fichier outputs.txt ne peut être créé que lorsque la stack est en CREATE_COMPLETE"
    exit 1
fi

# Récupérer les outputs
log_info "Récupération des informations de la stack..."

WEBSERVER_IP=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='WebServerPublicIP'].OutputValue" \
    --output text \
    --region $REGION 2>/dev/null || echo "N/A")

DATABASE_IP=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='DatabasePrivateIP'].OutputValue" \
    --output text \
    --region $REGION 2>/dev/null || echo "N/A")

WEBSERVER_DNS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='WebServerPublicDNS'].OutputValue" \
    --output text \
    --region $REGION 2>/dev/null || echo "N/A")

# Vérifier que les valeurs sont valides
if [ "$WEBSERVER_IP" = "N/A" ] || [ "$DATABASE_IP" = "N/A" ]; then
    log_error "Impossible de récupérer toutes les informations nécessaires"
    log_error "WebServer IP: $WEBSERVER_IP"
    log_error "Database IP: $DATABASE_IP"
    exit 1
fi

# Créer le fichier outputs.txt
OUTPUT_FILE="outputs.txt"
cat > $OUTPUT_FILE << EOF
STACK_NAME=$STACK_NAME
WEBSERVER_IP=$WEBSERVER_IP
WEBSERVER_DNS=$WEBSERVER_DNS
DATABASE_IP=$DATABASE_IP
REGION=$REGION
ENV_NAME=$ENV_NAME
KEY_PAIR_NAME=$KEY_PAIR_NAME
EOF

log_info "✅ Fichier $OUTPUT_FILE créé avec succès!"
echo ""
echo "📊 Informations sauvegardées:"
echo "  • WebServer IP:  $WEBSERVER_IP"
echo "  • WebServer DNS: $WEBSERVER_DNS"
echo "  • Database IP:   $DATABASE_IP"
echo ""
echo "🔗 Vous pouvez maintenant exécuter:"
echo "   ./scripts/setup-database.sh"



