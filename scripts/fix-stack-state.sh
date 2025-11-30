#!/bin/bash

# Script pour corriger l'état d'une stack CloudFormation en UPDATE_ROLLBACK_COMPLETE
# Usage: ./scripts/fix-stack-state.sh [STACK_NAME] [REGION]

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

log_question() {
    echo -e "${BLUE}[?]${NC} $1"
}

echo "🔧 Correction de l'état de la stack CloudFormation"
echo "===================================================="
echo ""
log_info "Stack: $STACK_NAME"
log_info "Région: $REGION"
echo ""

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Vérifier l'état de la stack
log_info "Vérification de l'état de la stack..."
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].StackStatus" \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" == "NOT_FOUND" ]; then
    log_error "Stack '$STACK_NAME' introuvable dans $REGION"
    exit 1
fi

log_info "État actuel: $STACK_STATUS"
echo ""

# Vérifier les EIPs
log_info "Vérification des Elastic IPs..."
EIP_COUNT=$(aws ec2 describe-addresses --region $REGION --query 'length(Addresses)' --output text)
log_info "Elastic IPs disponibles: $EIP_COUNT/5"

if [ "$EIP_COUNT" -ge 5 ]; then
    log_error "❌ Limite d'Elastic IPs atteinte ($EIP_COUNT/5)"
    log_warning "Libérez des EIPs avec: ./scripts/check-elastic-ips.sh $REGION"
    exit 1
fi

# Gérer selon l'état
case "$STACK_STATUS" in
    "UPDATE_ROLLBACK_COMPLETE")
        log_warning "Stack en état UPDATE_ROLLBACK_COMPLETE"
        echo ""
        log_info "Options disponibles:"
        echo "  1. Continuer le rollback (continue-update-rollback)"
        echo "  2. Supprimer et recréer la stack (recommandé)"
        echo ""
        log_question "Que voulez-vous faire? (1=rollback, 2=supprimer, 3=annuler)"
        read -r choice
        
        case "$choice" in
            1)
                log_info "Tentative de continuation du rollback..."
                aws cloudformation continue-update-rollback \
                    --stack-name $STACK_NAME \
                    --region $REGION || log_warning "Rollback déjà terminé"
                log_info "✅ Rollback continué"
                ;;
            2)
                log_warning "⚠️  Suppression de la stack..."
                log_question "Êtes-vous sûr de vouloir supprimer la stack? (o/n)"
                read -r confirm
                
                if [[ "$confirm" =~ ^[OoYy]$ ]]; then
                    log_info "Suppression de la stack..."
                    aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
                    log_info "⏳ Attente de la suppression..."
                    aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
                    log_info "✅ Stack supprimée"
                    log_info "Vous pouvez maintenant recréer la stack"
                else
                    log_info "Suppression annulée"
                fi
                ;;
            *)
                log_info "Opération annulée"
                ;;
        esac
        ;;
    "CREATE_FAILED"|"ROLLBACK_COMPLETE"|"DELETE_FAILED")
        log_warning "Stack en état problématique: $STACK_STATUS"
        log_info "Suppression recommandée..."
        log_question "Voulez-vous supprimer la stack? (o/n)"
        read -r confirm
        
        if [[ "$confirm" =~ ^[OoYy]$ ]]; then
            aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
            log_info "⏳ Suppression en cours..."
            aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
            log_info "✅ Stack supprimée"
        fi
        ;;
    "CREATE_COMPLETE"|"UPDATE_COMPLETE")
        log_info "✅ Stack en bon état: $STACK_STATUS"
        log_info "Vous pouvez faire une mise à jour normale"
        ;;
    *)
        log_warning "État inattendu: $STACK_STATUS"
        log_info "Vérifiez manuellement l'état de la stack"
        ;;
esac

echo ""
log_info "✅ Opération terminée"

