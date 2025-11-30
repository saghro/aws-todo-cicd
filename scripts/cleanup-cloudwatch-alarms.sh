#!/bin/bash

# Script pour supprimer les alarmes CloudWatch existantes
# Usage: ./scripts/cleanup-cloudwatch-alarms.sh [PREFIX] [REGION]

set -e

PREFIX=${1:-"prod-"}
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

echo "🧹 Nettoyage des alarmes CloudWatch"
echo "===================================="
echo ""
log_info "Préfixe: $PREFIX"
log_info "Région: $REGION"
echo ""

# Lister les alarmes
log_info "Recherche des alarmes avec le préfixe '$PREFIX'..."
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "$PREFIX" \
    --region $REGION \
    --query "MetricAlarms[*].AlarmName" \
    --output text 2>/dev/null || echo "")

if [ -z "$ALARMS" ]; then
    log_info "✅ Aucune alerte trouvée avec le préfixe '$PREFIX'"
    exit 0
fi

echo ""
log_warning "Alarmes trouvées:"
for ALARM in $ALARMS; do
    echo "  - $ALARM"
done
echo ""

log_warning "⚠️  Voulez-vous supprimer ces alarmes? (o/n)"
read -r response

if [[ "$response" =~ ^[OoYy]$ ]]; then
    log_info "Suppression des alarmes..."
    
    for ALARM in $ALARMS; do
        log_info "Suppression de: $ALARM"
        aws cloudwatch delete-alarms \
            --alarm-names "$ALARM" \
            --region $REGION && log_info "✅ Supprimée" || log_error "❌ Échec"
    done
    
    echo ""
    log_info "✅ Nettoyage terminé"
else
    log_info "Suppression annulée"
fi

