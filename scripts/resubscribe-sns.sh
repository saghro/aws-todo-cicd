#!/bin/bash

# Script pour réabonner un email au topic SNS
# Usage: ./scripts/resubscribe-sns.sh [EMAIL]

set -e

STACK_NAME="todo-app-stack"
REGION="us-east-1"
EMAIL="${1:-ayoub_saghro@um5.ac.ma}"

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Vérifier que la stack existe et est complète
log_info "Vérification de la stack CloudFormation..."
STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].StackStatus" \
    --output text \
    --region $REGION 2>/dev/null || echo "NOT_FOUND")

if [ "$STATUS" != "CREATE_COMPLETE" ] && [ "$STATUS" != "UPDATE_COMPLETE" ]; then
    log_error "Stack en statut: $STATUS"
    log_error "La stack doit être en CREATE_COMPLETE ou UPDATE_COMPLETE"
    exit 1
fi

# Récupérer l'ARN du topic SNS
log_info "Récupération de l'ARN du topic SNS..."
TOPIC_ARN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='SNSTopicArn'].OutputValue" \
    --output text \
    --region $REGION 2>/dev/null)

if [ -z "$TOPIC_ARN" ] || [ "$TOPIC_ARN" = "None" ]; then
    log_error "Topic SNS non trouvé dans les outputs de la stack"
    exit 1
fi

log_info "Topic SNS: $TOPIC_ARN"

# Vérifier les abonnements existants
log_info "Vérification des abonnements existants..."
SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic \
    --topic-arn "$TOPIC_ARN" \
    --region $REGION \
    --query "Subscriptions[?Endpoint=='$EMAIL']" \
    --output json 2>/dev/null || echo "[]")

# Supprimer les abonnements non confirmés existants
echo "$SUBSCRIPTIONS" | jq -r '.[] | select(.SubscriptionArn == "PendingConfirmation") | .SubscriptionArn' | while read -r sub_arn; do
    if [ -n "$sub_arn" ]; then
        log_warn "Suppression de l'abonnement non confirmé: $sub_arn"
        aws sns unsubscribe --subscription-arn "$sub_arn" --region $REGION 2>/dev/null || true
    fi
done

# Créer un nouvel abonnement
log_info "Création d'un nouvel abonnement pour: $EMAIL"
SUBSCRIPTION_ARN=$(aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol email \
    --notification-endpoint "$EMAIL" \
    --region $REGION \
    --query "SubscriptionArn" \
    --output text 2>/dev/null)

if [ -n "$SUBSCRIPTION_ARN" ] && [ "$SUBSCRIPTION_ARN" != "None" ]; then
    log_info "✅ Abonnement créé: $SUBSCRIPTION_ARN"
    echo ""
    echo "📧 Un email de confirmation a été envoyé à: $EMAIL"
    echo "   Vérifiez votre boîte mail (et les spams) et cliquez sur le lien de confirmation."
    echo ""
    echo "🔗 Pour vérifier l'état de l'abonnement:"
    echo "   aws sns list-subscriptions-by-topic --topic-arn $TOPIC_ARN --region $REGION"
else
    log_error "Échec de la création de l'abonnement"
    exit 1
fi

