#!/bin/bash

# Script pour corriger et relancer le déploiement
# Usage: ./scripts/fix-and-deploy.sh

set -e

STACK_NAME="todo-app-stack"
REGION="us-east-1"
KEY_PAIR_NAME="${1:-todo-app-key}"
ALERT_EMAIL="${2:-ayoub_saghro@um5.ac.ma}"

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Vérifier l'état de la stack
log_step "Vérification de l'état de la stack..."
STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].StackStatus" \
    --output text \
    --region $REGION 2>/dev/null || echo "NOT_FOUND")

log_info "Statut actuel: $STATUS"

# Si la stack est en ROLLBACK_COMPLETE ou ROLLBACK_IN_PROGRESS, la supprimer
if [ "$STATUS" = "ROLLBACK_COMPLETE" ] || [ "$STATUS" = "ROLLBACK_IN_PROGRESS" ]; then
    log_warn "Stack en état de rollback. Suppression nécessaire..."
    
    if [ "$STATUS" = "ROLLBACK_IN_PROGRESS" ]; then
        log_info "Attente de la fin du rollback..."
        aws cloudformation wait stack-rollback-complete \
            --stack-name $STACK_NAME \
            --region $REGION || true
    fi
    
    log_step "Suppression de la stack..."
    aws cloudformation delete-stack \
        --stack-name $STACK_NAME \
        --region $REGION
    
    log_info "Attente de la suppression complète..."
    aws cloudformation wait stack-delete-complete \
        --stack-name $STACK_NAME \
        --region $REGION
    
    log_info "✅ Stack supprimée"
fi

# Si la stack n'existe pas ou a été supprimée, lancer le déploiement
if [ "$STATUS" = "NOT_FOUND" ] || [ "$STATUS" = "DELETE_COMPLETE" ] || [ "$STATUS" = "ROLLBACK_COMPLETE" ]; then
    log_step "Lancement du déploiement..."
    ./scripts/deploy-auto.sh "$KEY_PAIR_NAME" "$ALERT_EMAIL"
    
    # Attendre que le déploiement soit terminé
    log_info "Attente de la fin du déploiement..."
    aws cloudformation wait stack-create-complete \
        --stack-name $STACK_NAME \
        --region $REGION || {
        log_error "Le déploiement a échoué. Vérifiez les événements:"
        aws cloudformation describe-stack-events \
            --stack-name $STACK_NAME \
            --max-items 10 \
            --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" \
            --output table \
            --region $REGION
        exit 1
    }
    
    log_info "✅ Déploiement terminé avec succès!"
    
    # Créer le fichier outputs.txt
    log_step "Création du fichier outputs.txt..."
    ./scripts/create-outputs.sh
    
    log_info "🎉 Tout est prêt! Vous pouvez maintenant exécuter:"
    echo "   ./scripts/setup-database.sh"
else
    log_warn "Stack en statut: $STATUS"
    log_info "Si le déploiement est en cours, attendez qu'il se termine."
    log_info "Si vous voulez forcer un nouveau déploiement, supprimez d'abord la stack."
fi



