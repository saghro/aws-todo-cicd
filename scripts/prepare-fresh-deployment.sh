#!/bin/bash

# Script pour préparer un déploiement propre
# Supprime les stacks, alarmes et vérifie les prérequis
# Usage: ./scripts/prepare-fresh-deployment.sh [STACK_NAME] [REGION]

set -e

STACK_NAME=${1:-"todo-app-stack"}
REGION=${2:-"us-east-1"}

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo "🧹 Préparation d'un déploiement propre"
echo "======================================="
echo ""
log_info "Stack: $STACK_NAME"
log_info "Région: $REGION"
echo ""

# 1. Nettoyer la stack
log_info "1️⃣  Nettoyage de la stack CloudFormation..."
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Stacks[0].StackStatus" \
        --output text)
    
    if [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]] || [[ "$STACK_STATUS" == "CREATE_FAILED" ]] || [[ "$STACK_STATUS" == "REVIEW_IN_PROGRESS" ]]; then
        log_warning "Stack en état problématique: $STACK_STATUS"
        aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
        log_info "⏳ Attente de la suppression..."
        aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
        log_info "✅ Stack supprimée"
    else
        log_info "Stack en état: $STACK_STATUS (pas de nettoyage nécessaire)"
    fi
else
    log_info "✅ Stack n'existe pas"
fi

# 2. Nettoyer les alarmes
echo ""
log_info "2️⃣  Nettoyage des alarmes CloudWatch..."
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "prod-" \
    --region $REGION \
    --query "MetricAlarms[*].AlarmName" \
    --output text 2>/dev/null || echo "")

if [ -n "$ALARMS" ]; then
    log_warning "Alarmes trouvées, suppression..."
    for ALARM in $ALARMS; do
        aws cloudwatch delete-alarms --alarm-names "$ALARM" --region $REGION 2>/dev/null || true
    done
    log_info "✅ Alarmes supprimées"
else
    log_info "✅ Aucune alerte à supprimer"
fi

# 3. Vérifier les EIPs
echo ""
log_info "3️⃣  Vérification des Elastic IPs..."
EIP_COUNT=$(aws ec2 describe-addresses --region $REGION --query 'length(Addresses)' --output text)
log_info "Elastic IPs: $EIP_COUNT/5"

if [ "$EIP_COUNT" -ge 5 ]; then
    log_warning "⚠️  Limite d'Elastic IPs atteinte ($EIP_COUNT/5)"
    log_info "Exécutez: ./scripts/check-elastic-ips.sh $REGION"
else
    log_info "✅ Espace disponible pour les EIPs"
fi

# 4. Vérifier la Key Pair
echo ""
log_info "4️⃣  Vérification de la Key Pair..."
if aws ec2 describe-key-pairs --key-names "todo-app-key" --region $REGION &> /dev/null; then
    log_info "✅ Key Pair 'todo-app-key' existe"
else
    log_error "❌ Key Pair 'todo-app-key' n'existe pas"
    log_info "Créez-la avec: ./scripts/check-keypair.sh todo-app-key $REGION"
fi

# 5. Vérifier l'AMI
echo ""
log_info "5️⃣  Vérification de l'AMI..."
./scripts/check-ami.sh $REGION > /dev/null 2>&1 && log_info "✅ AMI valide" || log_warning "⚠️  Vérifiez l'AMI"

echo ""
echo "================================================"
log_info "✅ Préparation terminée!"
echo "================================================"
echo ""
log_info "Vous pouvez maintenant relancer le déploiement"
log_info "Le pipeline GitHub Actions devrait fonctionner"

