#!/bin/bash

# Script pour nettoyer une stack CloudFormation bloquée
# Usage: ./scripts/cleanup-stack.sh [STACK_NAME] [REGION]

set -e

STACK_NAME=${1:-"todo-app-stack"}
REGION=${2:-"us-east-1"}

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

echo "🧹 Nettoyage de la stack CloudFormation"
echo "========================================"
echo ""
log_info "Stack: $STACK_NAME"
log_info "Région: $REGION"
echo ""

# Vérifier l'état de la stack
log_info "Vérification de l'état de la stack..."
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].StackStatus" \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" == "NOT_FOUND" ]; then
    log_info "✅ Stack n'existe pas, rien à nettoyer"
    exit 0
fi

log_info "État actuel: $STACK_STATUS"
echo ""

# États qui nécessitent un nettoyage
PROBLEMATIC_STATES=("REVIEW_IN_PROGRESS" "CREATE_IN_PROGRESS" "UPDATE_IN_PROGRESS" "UPDATE_ROLLBACK_COMPLETE" "CREATE_FAILED" "ROLLBACK_COMPLETE")

if [[ " ${PROBLEMATIC_STATES[@]} " =~ " ${STACK_STATUS} " ]]; then
    log_warning "Stack en état problématique: $STACK_STATUS"
    echo ""
    log_warning "⚠️  Suppression de la stack..."
    
    # Supprimer la stack
    aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
    log_info "⏳ Attente de la suppression (cela peut prendre 5-10 minutes)..."
    
    # Attendre la suppression
    aws cloudformation wait stack-delete-complete \
        --stack-name $STACK_NAME \
        --region $REGION
    
    log_info "✅ Stack supprimée avec succès"
    echo ""
    log_info "Vous pouvez maintenant recréer la stack"
else
    log_info "Stack en état normal: $STACK_STATUS"
    log_info "Aucun nettoyage nécessaire"
fi

