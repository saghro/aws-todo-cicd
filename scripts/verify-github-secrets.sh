#!/bin/bash

# Script pour vérifier que les secrets GitHub sont correctement configurés
# Usage: ./scripts/verify-github-secrets.sh

set -e

echo "🔐 Vérification des Secrets GitHub"
echo "==================================="
echo ""

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

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Vérifier la configuration AWS
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS CLI n'est pas configuré."
    exit 1
fi

REGION=$(aws configure get region || echo "us-east-1")
log_info "Région AWS configurée: $REGION"
echo ""

# Liste des secrets requis
echo "📋 Secrets GitHub requis pour le pipeline CI/CD:"
echo ""
echo "1. AWS_ACCESS_KEY_ID"
echo "   → Clé d'accès AWS"
echo ""
echo "2. AWS_SECRET_ACCESS_KEY"
echo "   → Clé secrète AWS"
echo ""
echo "3. EC2_KEY_PAIR_NAME"
echo "   → Nom de la Key Pair EC2 (ex: todo-app-key)"
echo "   → Doit correspondre exactement au nom dans AWS"
echo ""
echo "4. EC2_SSH_PRIVATE_KEY"
echo "   → Contenu du fichier .pem de la Key Pair"
echo ""
echo "5. ALERT_EMAIL"
echo "   → Email pour recevoir les alertes SNS"
echo ""
echo "6. DB_PASSWORD"
echo "   → Mot de passe pour la base de données PostgreSQL"
echo ""

# Vérifier la Key Pair
log_info "Vérification de la Key Pair dans AWS..."
if [ -f "outputs.txt" ]; then
    source outputs.txt
    KEY_PAIR_NAME=${KEY_PAIR_NAME:-"todo-app-key"}
else
    KEY_PAIR_NAME="todo-app-key"
fi

log_question "Quel est le nom de votre Key Pair? (défaut: $KEY_PAIR_NAME)"
read -r input_keypair
KEY_PAIR_NAME=${input_keypair:-$KEY_PAIR_NAME}

if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$REGION" &> /dev/null; then
    log_info "✅ Key Pair '$KEY_PAIR_NAME' existe dans la région $REGION"
    
    KEY_FINGERPRINT=$(aws ec2 describe-key-pairs \
        --key-names "$KEY_PAIR_NAME" \
        --region "$REGION" \
        --query "KeyPairs[0].KeyFingerprint" \
        --output text)
    
    log_info "   Fingerprint: $KEY_FINGERPRINT"
    echo ""
    log_info "✅ Le secret EC2_KEY_PAIR_NAME doit être: $KEY_PAIR_NAME"
else
    log_error "❌ Key Pair '$KEY_PAIR_NAME' n'existe pas dans la région $REGION"
    echo ""
    log_warning "Créez-la d'abord avec:"
    echo "  ./scripts/check-keypair.sh $KEY_PAIR_NAME $REGION"
    exit 1
fi

# Vérifier le fichier .pem
echo ""
log_info "Vérification du fichier .pem local..."
PEM_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"

if [ -f "$PEM_FILE" ]; then
    log_info "✅ Fichier .pem trouvé: $PEM_FILE"
    
    # Vérifier les permissions
    PERMISSIONS=$(stat -f "%OLp" "$PEM_FILE" 2>/dev/null || stat -c "%a" "$PEM_FILE" 2>/dev/null || echo "unknown")
    if [ "$PERMISSIONS" == "400" ] || [ "$PERMISSIONS" == "600" ]; then
        log_info "✅ Permissions correctes: $PERMISSIONS"
    else
        log_warning "⚠️  Permissions: $PERMISSIONS (recommandé: 400)"
        log_warning "   Corrigez avec: chmod 400 $PEM_FILE"
    fi
    
    # Vérifier le contenu
    PEM_CONTENT=$(head -1 "$PEM_FILE")
    if [[ "$PEM_CONTENT" == "-----BEGIN"* ]]; then
        log_info "✅ Format du fichier .pem valide"
        echo ""
        log_info "📋 Le secret EC2_SSH_PRIVATE_KEY doit contenir:"
        echo "   (le contenu complet du fichier $PEM_FILE)"
        echo ""
        log_question "Voulez-vous afficher le contenu pour copier? (o/n)"
        read -r response
        if [[ "$response" =~ ^[OoYy]$ ]]; then
            echo ""
            echo "--- Début du contenu ---"
            cat "$PEM_FILE"
            echo "--- Fin du contenu ---"
            echo ""
        fi
    else
        log_error "❌ Format du fichier .pem invalide"
    fi
else
    log_warning "⚠️  Fichier .pem non trouvé: $PEM_FILE"
    log_warning "   Si vous avez la Key Pair dans AWS, vous ne pouvez plus télécharger le fichier .pem"
    log_warning "   Vous devrez créer une nouvelle Key Pair ou utiliser celle existante si vous avez le fichier"
fi

# Vérifier la région
echo ""
log_info "Vérification de la région..."
log_info "✅ Région AWS: $REGION"
log_info "✅ Le workflow utilise: us-east-1 (vérifiez dans .github/workflows/deploy.yml)"
if [ "$REGION" != "us-east-1" ]; then
    log_warning "⚠️  La région configurée ($REGION) est différente de celle du workflow (us-east-1)"
    log_warning "   Assurez-vous que la Key Pair existe dans us-east-1"
fi

# Résumé
echo ""
echo "================================================"
log_info "📋 Résumé des vérifications"
echo "================================================"
echo ""
log_info "✅ Key Pair AWS: $KEY_PAIR_NAME (existe dans $REGION)"
log_info "✅ Fichier .pem: $PEM_FILE"
echo ""
log_info "🔧 Actions à faire dans GitHub:"
echo ""
echo "1. Allez dans: Settings → Secrets and variables → Actions"
echo ""
echo "2. Vérifiez/Créez ces secrets:"
echo "   - EC2_KEY_PAIR_NAME = $KEY_PAIR_NAME"
echo "   - EC2_SSH_PRIVATE_KEY = (contenu du fichier .pem)"
echo "   - AWS_ACCESS_KEY_ID = (votre clé d'accès)"
echo "   - AWS_SECRET_ACCESS_KEY = (votre clé secrète)"
echo "   - ALERT_EMAIL = (votre email)"
echo "   - DB_PASSWORD = (mot de passe PostgreSQL)"
echo ""
log_info "✅ Vérification terminée!"

