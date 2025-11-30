#!/bin/bash

# Script pour vérifier et libérer les Elastic IPs non utilisées
# Usage: ./scripts/check-elastic-ips.sh [REGION]

set -e

REGION=${1:-"us-east-1"}

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

echo "🌐 Vérification des Elastic IPs"
echo "================================"
echo ""
log_info "Région: $REGION"
echo ""

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Obtenir toutes les Elastic IPs
log_info "Récupération des Elastic IPs dans $REGION..."
EIPS=$(aws ec2 describe-addresses --region $REGION --output json)

# Compter les EIPs
TOTAL_COUNT=$(echo "$EIPS" | jq '.Addresses | length')
USED_COUNT=$(echo "$EIPS" | jq '[.Addresses[] | select(.AssociationId != null)] | length')
UNUSED_COUNT=$((TOTAL_COUNT - USED_COUNT))

echo ""
log_info "📊 Statistiques:"
echo "  Total d'Elastic IPs: $TOTAL_COUNT"
echo "  Utilisées: $USED_COUNT"
echo "  Non utilisées: $UNUSED_COUNT"
echo "  Limite AWS: 5 par défaut"
echo ""

# Afficher les EIPs non utilisées
if [ "$UNUSED_COUNT" -gt 0 ]; then
    log_warning "⚠️  Elastic IPs non utilisées trouvées:"
    echo ""
    echo "$EIPS" | jq -r '.Addresses[] | select(.AssociationId == null) | "  Allocation ID: \(.AllocationId)\n  Public IP: \(.PublicIp)\n  Tags: \(.Tags // [] | map("\(.Key)=\(.Value)") | join(", "))\n"'
    echo ""
    
    log_question "Voulez-vous libérer les Elastic IPs non utilisées? (o/n)"
    read -r response
    
    if [[ "$response" =~ ^[OoYy]$ ]]; then
        echo ""
        log_info "Libération des Elastic IPs non utilisées..."
        
        UNUSED_ALLOCATION_IDS=$(echo "$EIPS" | jq -r '.Addresses[] | select(.AssociationId == null) | .AllocationId')
        
        for ALLOC_ID in $UNUSED_ALLOCATION_IDS; do
            log_info "Libération de $ALLOC_ID..."
            if aws ec2 release-address --allocation-id "$ALLOC_ID" --region $REGION; then
                log_info "✅ Elastic IP libérée: $ALLOC_ID"
            else
                log_error "❌ Échec de la libération: $ALLOC_ID"
            fi
        done
        
        echo ""
        log_info "✅ Libération terminée"
    else
        log_info "Libération annulée"
    fi
else
    log_info "✅ Aucune Elastic IP non utilisée"
fi

# Afficher toutes les EIPs
echo ""
log_info "📋 Toutes les Elastic IPs dans $REGION:"
echo "$EIPS" | jq -r '.Addresses[] | "  Allocation ID: \(.AllocationId)\n  Public IP: \(.PublicIp)\n  Association ID: \(.AssociationId // "Non associée")\n  Instance ID: \(.InstanceId // "N/A")\n  Network Interface ID: \(.NetworkInterfaceId // "N/A")\n  Tags: \(.Tags // [] | map("\(.Key)=\(.Value)") | join(", ") // "Aucun")\n"'

# Vérifier la limite
if [ "$TOTAL_COUNT" -ge 5 ]; then
    echo ""
    log_error "❌ Limite atteinte! Vous avez $TOTAL_COUNT/5 Elastic IPs"
    log_warning "💡 Solutions:"
    echo "  1. Libérez les Elastic IPs non utilisées (voir ci-dessus)"
    echo "  2. Demandez une augmentation de limite à AWS Support"
    echo "  3. Supprimez les ressources qui utilisent des EIPs"
else
    echo ""
    log_info "✅ Vous avez $TOTAL_COUNT/5 Elastic IPs (limite non atteinte)"
fi

echo ""
log_info "✅ Vérification terminée"

