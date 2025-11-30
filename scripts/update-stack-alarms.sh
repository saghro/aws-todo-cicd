#!/bin/bash

# Script pour mettre à jour la stack CloudFormation avec les alarmes
# Usage: ./scripts/update-stack-alarms.sh

set -e

echo "🔄 Mise à jour de la stack CloudFormation avec les alarmes"
echo "============================================================"

# Variables
STACK_NAME="todo-app-stack"
TEMPLATE_FILE="infrastructure/infrastructure.yml"
REGION="us-east-1"  # Changez selon votre région

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Vérifier la région
read -p "Région AWS (défaut: $REGION): " INPUT_REGION
REGION=${INPUT_REGION:-$REGION}
log_info "Région: $REGION"

# Vérifier que la stack existe
log_info "Vérification de la stack CloudFormation..."
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    log_error "Stack '$STACK_NAME' introuvable dans la région $REGION"
    log_info "Déployez d'abord la stack avec: ./scripts/deploy.sh"
    exit 1
fi

# Récupérer les paramètres existants
log_info "Récupération des paramètres de la stack..."
KEY_PAIR_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Parameters[?ParameterKey=='KeyPairName'].ParameterValue" \
    --output text 2>/dev/null || echo "")

ALERT_EMAIL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Parameters[?ParameterKey=='AlertEmail'].ParameterValue" \
    --output text 2>/dev/null || echo "")

ENV_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Parameters[?ParameterKey=='EnvironmentName'].ParameterValue" \
    --output text 2>/dev/null || echo "prod")

if [ -z "$KEY_PAIR_NAME" ] || [ "$KEY_PAIR_NAME" == "None" ]; then
    read -p "Nom de la Key Pair EC2: " KEY_PAIR_NAME
fi

if [ -z "$ALERT_EMAIL" ] || [ "$ALERT_EMAIL" == "None" ]; then
    read -p "Email pour les alertes SNS: " ALERT_EMAIL
fi

log_info "Key Pair: $KEY_PAIR_NAME"
log_info "Alert Email: $ALERT_EMAIL"
log_info "Environment: $ENV_NAME"

# Valider le template
log_info "Validation du template CloudFormation..."
if ! aws cloudformation validate-template --template-body file://$TEMPLATE_FILE --region $REGION > /dev/null 2>&1; then
    log_error "Template invalide"
    exit 1
fi

# Mettre à jour la stack
log_info "Mise à jour de la stack CloudFormation..."
log_info "⏳ Cela peut prendre quelques minutes..."

aws cloudformation update-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters \
        ParameterKey=EnvironmentName,ParameterValue=$ENV_NAME \
        ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME \
        ParameterKey=AlertEmail,ParameterValue=$ALERT_EMAIL \
    --capabilities CAPABILITY_IAM \
    --region $REGION

if [ $? -eq 0 ]; then
    log_info "✅ Mise à jour de la stack lancée"
    log_info "⏳ Attente de la fin de la mise à jour..."
    aws cloudformation wait stack-update-complete \
        --stack-name $STACK_NAME \
        --region $REGION
    log_info "✅ Stack mise à jour avec succès"
else
    log_error "❌ Échec de la mise à jour"
    log_warning "La stack est peut-être déjà à jour (pas de changements détectés)"
fi

# Vérifier les alarmes
echo ""
log_info "📊 Vérification des alarmes créées..."
aws cloudwatch describe-alarms \
    --alarm-name-prefix "$ENV_NAME-" \
    --region $REGION \
    --query "MetricAlarms[*].[AlarmName,StateValue]" \
    --output table

echo ""
log_info "✅ Mise à jour terminée!"
log_info "🔗 Accès dans la console:"
echo "   https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:"

