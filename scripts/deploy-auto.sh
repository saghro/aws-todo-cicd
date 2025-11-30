#!/bin/bash

# Script de déploiement automatique avec paramètres
# Usage: ./scripts/deploy-auto.sh [KEY_PAIR] [EMAIL]

set -e

# Variables
STACK_NAME="todo-app-stack"
TEMPLATE_FILE="infrastructure/infrastructure.yml"
REGION="us-east-1"
ENV_NAME="prod"

# Paramètres
KEY_PAIR_NAME="${1:-todo-app-key}"
ALERT_EMAIL="${2}"

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

# Vérifier que l'email est fourni
if [ -z "$ALERT_EMAIL" ]; then
    log_error "Email requis. Usage: ./scripts/deploy-auto.sh [KEY_PAIR] [EMAIL]"
    exit 1
fi

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Vérifier la configuration AWS
log_info "Vérification de la configuration AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS CLI n'est pas configuré. Exécutez 'aws configure' d'abord."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_info "Compte AWS: $ACCOUNT_ID"
log_info "Key Pair: $KEY_PAIR_NAME"
log_info "Email: $ALERT_EMAIL"

# Valider le template
log_info "Validation du template CloudFormation..."
if aws cloudformation validate-template --template-body file://$TEMPLATE_FILE > /dev/null 2>&1; then
    log_info "✅ Template valide"
else
    log_error "❌ Template invalide"
    exit 1
fi

# Déployer la stack
log_info "Déploiement de la stack CloudFormation..."
log_info "⏳ Cela peut prendre 10-15 minutes..."

aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        EnvironmentName=$ENV_NAME \
        KeyPairName=$KEY_PAIR_NAME \
        AlertEmail=$ALERT_EMAIL \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --no-fail-on-empty-changeset

if [ $? -eq 0 ]; then
    log_info "✅ Stack déployée avec succès"
else
    log_error "❌ Échec du déploiement"
    exit 1
fi

# Récupérer les outputs
log_info "Récupération des informations..."
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

# Afficher les résultats
echo ""
echo "================================================"
log_info "🎉 Déploiement terminé!"
echo "================================================"
echo ""
echo "📊 Informations:"
echo "  • WebServer IP:  $WEBSERVER_IP"
echo "  • WebServer DNS: $WEBSERVER_DNS"
echo "  • Database IP:   $DATABASE_IP"
echo ""

# Sauvegarder dans outputs.txt
cat > outputs.txt << EOF
STACK_NAME=$STACK_NAME
WEBSERVER_IP=$WEBSERVER_IP
WEBSERVER_DNS=$WEBSERVER_DNS
DATABASE_IP=$DATABASE_IP
REGION=$REGION
ENV_NAME=$ENV_NAME
KEY_PAIR_NAME=$KEY_PAIR_NAME
EOF

log_info "Informations sauvegardées dans outputs.txt"
echo ""
echo "📧 Confirmez l'abonnement SNS dans votre email: $ALERT_EMAIL"
echo ""
echo "🔗 Prochaines étapes:"
echo "  1. Confirmez l'email SNS"
echo "  2. Configurez la base de données: ./scripts/setup-database.sh"
echo "  3. Déployez l'application: ./scripts/deploy-app.sh"

