#!/bin/bash

# Script pour vérifier et créer une Key Pair EC2 si nécessaire
# Usage: ./scripts/check-keypair.sh [KEY_NAME] [REGION]

set -e

KEY_NAME=${1:-"todo-app-key"}
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

echo "🔑 Vérification de la Key Pair EC2"
echo "===================================="
echo ""
log_info "Key Pair: $KEY_NAME"
log_info "Région: $REGION"
echo ""

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Vérifier la configuration AWS
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS CLI n'est pas configuré. Exécutez 'aws configure' d'abord."
    exit 1
fi

# Vérifier si la Key Pair existe
log_info "Vérification de l'existence de la Key Pair..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &> /dev/null; then
    log_info "✅ Key Pair '$KEY_NAME' existe déjà dans la région $REGION"
    
    # Afficher les informations
    KEY_FINGERPRINT=$(aws ec2 describe-key-pairs \
        --key-names "$KEY_NAME" \
        --region "$REGION" \
        --query "KeyPairs[0].KeyFingerprint" \
        --output text)
    
    log_info "Fingerprint: $KEY_FINGERPRINT"
    echo ""
    log_info "✅ La Key Pair est prête à être utilisée"
    exit 0
else
    log_warning "❌ Key Pair '$KEY_NAME' n'existe pas dans la région $REGION"
    echo ""
    
    # Proposer de créer la Key Pair
    log_question "Voulez-vous créer la Key Pair maintenant? (o/n)"
    read -r response
    
    if [[ "$response" =~ ^[OoYy]$ ]]; then
        log_info "Création de la Key Pair..."
        
        # Créer la Key Pair
        OUTPUT_FILE="$HOME/.ssh/${KEY_NAME}.pem"
        
        aws ec2 create-key-pair \
            --key-name "$KEY_NAME" \
            --region "$REGION" \
            --query 'KeyMaterial' \
            --output text > "$OUTPUT_FILE"
        
        # Définir les permissions correctes
        chmod 400 "$OUTPUT_FILE"
        
        log_info "✅ Key Pair créée avec succès!"
        log_info "📁 Fichier sauvegardé: $OUTPUT_FILE"
        echo ""
        log_warning "⚠️  IMPORTANT: Sauvegardez ce fichier en lieu sûr!"
        log_warning "⚠️  Vous ne pourrez plus le télécharger après."
        echo ""
        log_info "✅ La Key Pair est maintenant prête à être utilisée"
    else
        log_error "Key Pair non créée. Créez-la manuellement ou utilisez une Key Pair existante."
        echo ""
        log_info "Pour créer manuellement:"
        echo "  aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > ~/.ssh/${KEY_NAME}.pem"
        echo "  chmod 400 ~/.ssh/${KEY_NAME}.pem"
        exit 1
    fi
fi

