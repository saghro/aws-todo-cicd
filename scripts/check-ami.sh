#!/bin/bash

# Script pour vérifier et obtenir l'AMI ID correct selon la région
# Usage: ./scripts/check-ami.sh [REGION]

set -e

REGION=${1:-"us-east-1"}

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

echo "🖼️  Vérification de l'AMI Amazon Linux 2"
echo "========================================"
echo ""
log_info "Région: $REGION"
echo ""

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Obtenir l'AMI ID pour Amazon Linux 2
log_info "Recherche de l'AMI Amazon Linux 2 dans $REGION..."

AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters \
        "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
        "Name=state,Values=available" \
    --region $REGION \
    --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
    --output text 2>/dev/null || echo "")

if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    log_error "❌ Impossible de trouver l'AMI Amazon Linux 2 dans $REGION"
    exit 1
fi

log_info "✅ AMI ID trouvé: $AMI_ID"

# Vérifier les détails de l'AMI
AMI_NAME=$(aws ec2 describe-images \
    --image-ids "$AMI_ID" \
    --region $REGION \
    --query "Images[0].Name" \
    --output text)

AMI_CREATION=$(aws ec2 describe-images \
    --image-ids "$AMI_ID" \
    --region $REGION \
    --query "Images[0].CreationDate" \
    --output text)

echo ""
log_info "Détails de l'AMI:"
echo "  Nom: $AMI_NAME"
echo "  Date de création: $AMI_CREATION"
echo "  Région: $REGION"
echo ""

# Vérifier l'AMI dans le template
TEMPLATE_AMI="ami-0156001f0548e90b1"
if [ "$AMI_ID" != "$TEMPLATE_AMI" ]; then
    log_warning "⚠️  L'AMI dans le template ($TEMPLATE_AMI) est différent de l'AMI actuel ($AMI_ID)"
    echo ""
    log_info "💡 Mettez à jour infrastructure/infrastructure.yml avec:"
    echo "   ImageId: $AMI_ID  # Amazon Linux 2 pour $REGION"
else
    log_info "✅ L'AMI dans le template correspond à l'AMI actuel"
fi

echo ""
log_info "📋 AMI ID pour $REGION: $AMI_ID"

