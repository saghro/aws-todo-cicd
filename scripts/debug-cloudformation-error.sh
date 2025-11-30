#!/bin/bash

# Script pour déboguer les erreurs CloudFormation
# Usage: ./scripts/debug-cloudformation-error.sh

set -e

STACK_NAME="todo-app-stack"
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

echo "🔍 Débogage de l'erreur CloudFormation"
echo "======================================="
echo ""

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Vérifier la région
read -p "Région AWS (défaut: $REGION): " INPUT_REGION
REGION=${INPUT_REGION:-$REGION}
log_info "Région: $REGION"

# Vérifier si la stack existe
log_info "Vérification de la stack..."
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    log_info "✅ Stack existe"
    
    # Afficher les événements récents
    echo ""
    log_info "📋 Événements récents de la stack:"
    aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME \
        --region $REGION \
        --max-items 10 \
        --query "StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]" \
        --output table
else
    log_warning "Stack n'existe pas encore"
fi

# Vérifier les changementsets en échec
echo ""
log_info "🔍 Recherche de changementsets en échec..."
CHANGESETS=$(aws cloudformation list-change-sets \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Summaries[?Status=='FAILED'].[ChangeSetId,StatusReason]" \
    --output text 2>/dev/null || echo "")

if [ -n "$CHANGESETS" ]; then
    log_warning "Changementsets en échec trouvés:"
    echo "$CHANGESETS"
    
    # Obtenir les détails du dernier changeset
    LAST_CHANGESET=$(aws cloudformation list-change-sets \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query "Summaries[?Status=='FAILED'] | [0].ChangeSetId" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$LAST_CHANGESET" ] && [ "$LAST_CHANGESET" != "None" ]; then
        echo ""
        log_info "📋 Détails du changeset en échec:"
        aws cloudformation describe-change-set \
            --change-set-name "$LAST_CHANGESET" \
            --stack-name $STACK_NAME \
            --region $REGION \
            --query "StatusReason" \
            --output text
    fi
else
    log_info "Aucun changeset en échec trouvé"
fi

# Vérifier la Key Pair
echo ""
log_info "🔑 Vérification de la Key Pair..."
if [ -f "outputs.txt" ]; then
    source outputs.txt
    KEY_PAIR_NAME=${KEY_PAIR_NAME:-"todo-app-key"}
else
    KEY_PAIR_NAME="todo-app-key"
fi

log_info "Recherche de la Key Pair: $KEY_PAIR_NAME dans $REGION"

if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$REGION" &> /dev/null; then
    log_info "✅ Key Pair '$KEY_PAIR_NAME' existe dans $REGION"
    
    KEY_INFO=$(aws ec2 describe-key-pairs \
        --key-names "$KEY_PAIR_NAME" \
        --region "$REGION" \
        --query "KeyPairs[0].[KeyName,KeyFingerprint,KeyType]" \
        --output text)
    
    echo "   Nom: $(echo $KEY_INFO | cut -d' ' -f1)"
    echo "   Fingerprint: $(echo $KEY_INFO | cut -d' ' -f2)"
    echo "   Type: $(echo $KEY_INFO | cut -d' ' -f3)"
else
    log_error "❌ Key Pair '$KEY_PAIR_NAME' n'existe PAS dans $REGION"
    echo ""
    log_info "Key Pairs disponibles dans $REGION:"
    aws ec2 describe-key-pairs --region "$REGION" --query "KeyPairs[*].KeyName" --output table
fi

# Vérifier les paramètres du template
echo ""
log_info "📋 Vérification des paramètres CloudFormation..."
if [ -f "infrastructure/infrastructure.yml" ]; then
    log_info "Paramètres requis par le template:"
    aws cloudformation validate-template \
        --template-body file://infrastructure/infrastructure.yml \
        --region $REGION \
        --query "Parameters[*].[ParameterKey,ParameterType,Description]" \
        --output table 2>/dev/null || log_warning "Impossible de valider le template"
fi

# Suggestions
echo ""
echo "================================================"
log_info "💡 Suggestions"
echo "================================================"
echo ""
log_info "1. Vérifiez que le secret EC2_KEY_PAIR_NAME dans GitHub correspond exactement au nom de la Key Pair"
log_info "2. Vérifiez que la Key Pair existe dans la même région que le déploiement ($REGION)"
log_info "3. Vérifiez les permissions IAM de votre utilisateur AWS"
log_info "4. Essayez de créer la stack manuellement pour voir l'erreur complète:"
echo ""
echo "   aws cloudformation create-stack \\"
echo "     --stack-name $STACK_NAME \\"
echo "     --template-body file://infrastructure/infrastructure.yml \\"
echo "     --parameters \\"
echo "       ParameterKey=EnvironmentName,ParameterValue=prod \\"
echo "       ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME \\"
echo "       ParameterKey=AlertEmail,ParameterValue=your@email.com \\"
echo "     --capabilities CAPABILITY_IAM \\"
echo "     --region $REGION"
echo ""

