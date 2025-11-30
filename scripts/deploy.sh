#!/bin/bash

# Script de déploiement manuel de l'infrastructure AWS
# Usage: ./scripts/deploy.sh

set -e

echo "🚀 Déploiement de l'infrastructure AWS Todo App"
echo "================================================"

# Variables
STACK_NAME="todo-app-stack"
TEMPLATE_FILE="infrastructure/infrastructure.yml"
REGION="us-east-1"
ENV_NAME="prod"

# Couleurs pour les logs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Vérifier que AWS CLI est installé
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé. Installez-le d'abord."
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

# Vérifier si la stack existe et son état
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].StackStatus" \
    --output text \
    --region $REGION 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" != "NOT_FOUND" ]; then
    if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ] || [ "$STACK_STATUS" == "CREATE_FAILED" ] || [ "$STACK_STATUS" == "DELETE_FAILED" ]; then
        log_warning "Stack en état $STACK_STATUS. Suppression nécessaire..."
        log_info "Suppression de la stack existante..."
        aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
        log_info "⏳ Attente de la suppression (cela peut prendre quelques minutes)..."
        aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
        log_info "✅ Stack supprimée"
    elif [ "$STACK_STATUS" == "CREATE_IN_PROGRESS" ] || [ "$STACK_STATUS" == "UPDATE_IN_PROGRESS" ] || [ "$STACK_STATUS" == "DELETE_IN_PROGRESS" ]; then
        log_error "Stack en cours de traitement. État: $STACK_STATUS"
        log_info "Attendez que l'opération en cours se termine."
        exit 1
    else
        log_info "Stack existante trouvée (état: $STACK_STATUS). Mise à jour..."
    fi
fi

# Demander les paramètres
read -p "Nom de la Key Pair EC2: " KEY_PAIR_NAME
read -p "Email pour les alertes SNS: " ALERT_EMAIL

# Valider le template CloudFormation
log_info "Validation du template CloudFormation..."
if aws cloudformation validate-template --template-body file://$TEMPLATE_FILE > /dev/null 2>&1; then
    log_info "✅ Template valide"
else
    log_error "❌ Template invalide"
    exit 1
fi

# Créer ou mettre à jour la stack
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
    log_error "❌ Échec du déploiement de la stack"
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

# Afficher les résultats
echo ""
echo "================================================"
log_info "🎉 Déploiement terminé avec succès!"
echo "================================================"
echo ""
echo "📊 Informations de l'infrastructure:"
echo "  • WebServer IP:  $WEBSERVER_IP"
echo "  • WebServer DNS: $WEBSERVER_DNS"
echo "  • Database IP:   $DATABASE_IP"
echo ""
echo "🔗 Prochaines étapes:"
echo "  1. Connectez-vous au WebServer: ssh -i ~/.ssh/$KEY_PAIR_NAME.pem ec2-user@$WEBSERVER_IP"
echo "  2. Configurez la base de données: ./scripts/setup-database.sh"
echo "  3. Déployez l'application: ./scripts/deploy-app.sh"
echo ""
echo "📧 Un email de confirmation SNS a été envoyé à: $ALERT_EMAIL"
echo "   Vérifiez votre boîte mail et confirmez l'abonnement."
echo ""

# Sauvegarder les outputs dans un fichier
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

log_info "Les informations ont été sauvegardées dans $OUTPUT_FILE"
