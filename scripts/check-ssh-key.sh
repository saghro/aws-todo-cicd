#!/bin/bash

# Script pour vérifier et afficher la clé SSH pour GitHub Secrets
# Usage: ./scripts/check-ssh-key.sh [KEY_PATH] [KEY_NAME]

set -e

KEY_PATH=${1:-"~/.ssh/todo-app-key.pem"}
KEY_NAME=${2:-"todo-app-key"}
REGION=${3:-"us-east-1"}

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

echo "🔑 Vérification de la clé SSH"
echo "=============================="
echo ""

# Expansion du chemin
KEY_PATH="${KEY_PATH/#\~/$HOME}"

# Vérifier que la clé existe
if [ ! -f "$KEY_PATH" ]; then
    log_error "La clé SSH n'existe pas: $KEY_PATH"
    echo ""
    log_info "Options:"
    echo "  1. Créer une nouvelle Key Pair dans AWS:"
    echo "     aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > $KEY_PATH"
    echo "     chmod 400 $KEY_PATH"
    echo ""
    echo "  2. Utiliser une clé existante en spécifiant le chemin:"
    echo "     ./scripts/check-ssh-key.sh /chemin/vers/votre/cle.pem"
    exit 1
fi

# Vérifier les permissions
if [ "$(stat -c %a "$KEY_PATH" 2>/dev/null || stat -f %A "$KEY_PATH" 2>/dev/null)" != "400" ] && [ "$(stat -c %a "$KEY_PATH" 2>/dev/null || stat -f %A "$KEY_PATH" 2>/dev/null)" != "600" ]; then
    log_warning "Les permissions de la clé ne sont pas optimales (devrait être 400 ou 600)"
    log_info "Correction des permissions..."
    chmod 400 "$KEY_PATH"
fi

# Vérifier que la clé est valide
log_info "Vérification du format de la clé..."
if ! ssh-keygen -l -f "$KEY_PATH" &> /dev/null; then
    log_error "La clé SSH n'est pas valide ou n'est pas au format PEM"
    exit 1
fi

FINGERPRINT=$(ssh-keygen -l -f "$KEY_PATH" | awk '{print $2}')
log_info "✅ Clé SSH valide"
echo "   Chemin: $KEY_PATH"
echo "   Fingerprint: $FINGERPRINT"
echo ""

# Vérifier que la Key Pair existe dans AWS
log_info "Vérification de la Key Pair dans AWS..."
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $REGION &> /dev/null; then
    AWS_FINGERPRINT=$(aws ec2 describe-key-pairs \
        --key-names "$KEY_NAME" \
        --region $REGION \
        --query "KeyPairs[0].KeyFingerprint" \
        --output text)
    
    # Comparer les fingerprints (en retirant les deux-points)
    LOCAL_FP=$(echo "$FINGERPRINT" | tr -d ':')
    AWS_FP=$(echo "$AWS_FINGERPRINT" | tr -d ':')
    
    if [ "$LOCAL_FP" == "$AWS_FP" ]; then
        log_info "✅ La clé locale correspond à la Key Pair AWS"
        echo "   Key Pair: $KEY_NAME"
        echo "   Fingerprint AWS: $AWS_FINGERPRINT"
    else
        log_warning "⚠️  Les fingerprints ne correspondent pas!"
        echo "   Local: $FINGERPRINT"
        echo "   AWS:   $AWS_FINGERPRINT"
        echo ""
        log_warning "La clé locale ne correspond peut-être pas à la Key Pair AWS"
    fi
else
    log_warning "⚠️  La Key Pair '$KEY_NAME' n'existe pas dans AWS ($REGION)"
    echo ""
    log_info "Pour créer la Key Pair:"
    echo "  aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION"
fi

echo ""
echo "=========================================="
log_info "Configuration pour GitHub Secrets"
echo "=========================================="
echo ""
log_info "Pour configurer le secret EC2_SSH_PRIVATE_KEY dans GitHub:"
echo ""
echo "1. Allez dans: Settings → Secrets and variables → Actions"
echo "2. Créez ou modifiez le secret: EC2_SSH_PRIVATE_KEY"
echo "3. Collez le contenu complet de la clé ci-dessous:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}"
cat "$KEY_PATH"
echo -e "${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "Important:"
echo "  - Copiez TOUT le contenu ci-dessus (y compris les lignes BEGIN et END)"
echo "  - Préservez tous les retours à la ligne"
echo "  - Ne modifiez pas le format"
echo ""
log_info "Pour tester la connexion SSH:"
echo "  ssh -i $KEY_PATH ec2-user@<WEBSERVER_IP>"

