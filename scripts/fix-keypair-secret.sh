#!/bin/bash

# Script pour identifier et corriger le problème de Key Pair
# Usage: ./scripts/fix-keypair-secret.sh

set -e

REGION="us-east-1"

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

echo "🔑 Correction du Secret GitHub EC2_KEY_PAIR_NAME"
echo "=================================================="
echo ""

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Lister les Key Pairs disponibles
log_info "Key Pairs disponibles dans $REGION:"
echo ""
aws ec2 describe-key-pairs --region $REGION --query "KeyPairs[*].[KeyName,KeyFingerprint]" --output table
echo ""

# Demander quelle Key Pair utiliser
log_question "Quelle Key Pair voulez-vous utiliser pour le déploiement?"
log_info "Options disponibles:"
KEY_PAIRS=$(aws ec2 describe-key-pairs --region $REGION --query "KeyPairs[*].KeyName" --output text)
for KEY in $KEY_PAIRS; do
    echo "  - $KEY"
done
echo ""

read -p "Nom de la Key Pair (ou 'todo-app-key' pour en créer une): " SELECTED_KEY

if [ -z "$SELECTED_KEY" ]; then
    log_error "Aucune Key Pair sélectionnée"
    exit 1
fi

# Vérifier si la Key Pair existe
if aws ec2 describe-key-pairs --key-names "$SELECTED_KEY" --region $REGION &> /dev/null; then
    log_info "✅ Key Pair '$SELECTED_KEY' existe dans $REGION"
    echo ""
    log_info "📋 Action requise dans GitHub:"
    echo ""
    echo "1. Allez dans votre repository GitHub"
    echo "2. Settings → Secrets and variables → Actions"
    echo "3. Modifiez le secret EC2_KEY_PAIR_NAME"
    echo "4. Mettez exactement cette valeur: $SELECTED_KEY"
    echo ""
    log_warning "⚠️  IMPORTANT: Pas d'espaces, pas de guillemets, exactement: $SELECTED_KEY"
else
    if [ "$SELECTED_KEY" == "todo-app-key" ]; then
        log_info "Création de la Key Pair 'todo-app-key'..."
        
        PEM_FILE="$HOME/.ssh/todo-app-key.pem"
        
        if [ -f "$PEM_FILE" ]; then
            log_warning "Le fichier $PEM_FILE existe déjà"
            log_question "Voulez-vous le remplacer? (o/n)"
            read -r response
            if [[ ! "$response" =~ ^[OoYy]$ ]]; then
                log_info "Création annulée"
                exit 0
            fi
        fi
        
        aws ec2 create-key-pair \
            --key-name todo-app-key \
            --region $REGION \
            --query 'KeyMaterial' \
            --output text > "$PEM_FILE"
        
        chmod 400 "$PEM_FILE"
        
        log_info "✅ Key Pair 'todo-app-key' créée"
        log_info "📁 Fichier sauvegardé: $PEM_FILE"
        echo ""
        log_warning "⚠️  IMPORTANT: Sauvegardez ce fichier en lieu sûr!"
        echo ""
        log_info "📋 Action requise dans GitHub:"
        echo ""
        echo "1. Allez dans votre repository GitHub"
        echo "2. Settings → Secrets and variables → Actions"
        echo "3. Modifiez le secret EC2_KEY_PAIR_NAME"
        echo "4. Mettez exactement: todo-app-key"
        echo ""
        echo "5. Modifiez aussi le secret EC2_SSH_PRIVATE_KEY"
        echo "6. Collez le contenu complet du fichier: $PEM_FILE"
    else
        log_error "❌ Key Pair '$SELECTED_KEY' n'existe pas"
        log_info "Créez-la d'abord ou utilisez une Key Pair existante"
        exit 1
    fi
fi

echo ""
log_info "✅ Configuration terminée!"

