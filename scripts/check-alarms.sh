#!/bin/bash

# Script pour vérifier et créer les alarmes CloudWatch
# Usage: ./scripts/check-alarms.sh

set -e

echo "🔍 Vérification des alarmes CloudWatch"
echo "========================================"

# Variables
STACK_NAME="todo-app-stack"
REGION="us-east-1"  # Changez selon votre région

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

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI n'est pas installé."
    exit 1
fi

# Vérifier la région
read -p "Région AWS (défaut: $REGION): " INPUT_REGION
REGION=${INPUT_REGION:-$REGION}
log_info "Région: $REGION"

# Vérifier que la stack existe
log_info "Vérification de la stack CloudFormation..."
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    log_error "Stack '$STACK_NAME' introuvable dans la région $REGION"
    exit 1
fi

# Récupérer les IDs des instances
log_info "Récupération des IDs des instances..."
WEBSERVER_INSTANCE_ID=$(aws cloudformation describe-stack-resources \
    --stack-name $STACK_NAME \
    --logical-resource-id WebServerInstance \
    --region $REGION \
    --query "StackResources[0].PhysicalResourceId" \
    --output text 2>/dev/null || echo "")

DATABASE_INSTANCE_ID=$(aws cloudformation describe-stack-resources \
    --stack-name $STACK_NAME \
    --logical-resource-id DatabaseInstance \
    --region $REGION \
    --query "StackResources[0].PhysicalResourceId" \
    --output text 2>/dev/null || echo "")

if [ -z "$WEBSERVER_INSTANCE_ID" ] || [ "$WEBSERVER_INSTANCE_ID" == "None" ]; then
    log_error "Impossible de récupérer l'ID de l'instance WebServer"
    exit 1
fi

if [ -z "$DATABASE_INSTANCE_ID" ] || [ "$DATABASE_INSTANCE_ID" == "None" ]; then
    log_error "Impossible de récupérer l'ID de l'instance Database"
    exit 1
fi

log_info "WebServer Instance ID: $WEBSERVER_INSTANCE_ID"
log_info "Database Instance ID: $DATABASE_INSTANCE_ID"

# Récupérer l'ARN du topic SNS
log_info "Récupération du topic SNS..."
SNS_TOPIC_ARN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='SNSTopicArn'].OutputValue" \
    --output text 2>/dev/null || echo "")

if [ -z "$SNS_TOPIC_ARN" ] || [ "$SNS_TOPIC_ARN" == "None" ]; then
    log_error "Impossible de récupérer l'ARN du topic SNS"
    exit 1
fi

log_info "SNS Topic ARN: $SNS_TOPIC_ARN"

# Récupérer le nom de l'environnement
ENV_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Parameters[?ParameterKey=='EnvironmentName'].ParameterValue" \
    --output text 2>/dev/null || echo "prod")

log_info "Environment: $ENV_NAME"

# Fonction pour créer une alerte
create_alarm() {
    local ALARM_NAME=$1
    local METRIC_NAME=$2
    local NAMESPACE=$3
    local STATISTIC=$4
    local PERIOD=$5
    local EVALUATION_PERIODS=$6
    local THRESHOLD=$7
    local COMPARISON=$8
    local INSTANCE_ID=$9
    
    log_info "Création de l'alarme: $ALARM_NAME"
    
    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --alarm-description "Alerte $METRIC_NAME pour $INSTANCE_ID" \
        --metric-name "$METRIC_NAME" \
        --namespace "$NAMESPACE" \
        --statistic "$STATISTIC" \
        --period $PERIOD \
        --evaluation-periods $EVALUATION_PERIODS \
        --threshold $THRESHOLD \
        --comparison-operator "$COMPARISON" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --alarm-actions "$SNS_TOPIC_ARN" \
        --region $REGION \
        --treat-missing-data notBreaching
    
    if [ $? -eq 0 ]; then
        log_info "✅ Alarme '$ALARM_NAME' créée avec succès"
    else
        log_error "❌ Échec de la création de l'alarme '$ALARM_NAME'"
    fi
}

# Vérifier et créer les alarmes
echo ""
log_info "Vérification des alarmes existantes..."

# Liste des alarmes à créer
ALARMS=(
    "$ENV_NAME-webserver-high-cpu|CPUUtilization|AWS/EC2|Average|300|1|80|GreaterThanThreshold|$WEBSERVER_INSTANCE_ID"
    "$ENV_NAME-webserver-status-check-failed|StatusCheckFailed|AWS/EC2|Maximum|60|2|1|GreaterThanOrEqualToThreshold|$WEBSERVER_INSTANCE_ID"
    "$ENV_NAME-database-high-cpu|CPUUtilization|AWS/EC2|Average|300|1|80|GreaterThanThreshold|$DATABASE_INSTANCE_ID"
    "$ENV_NAME-database-status-check-failed|StatusCheckFailed|AWS/EC2|Maximum|60|2|1|GreaterThanOrEqualToThreshold|$DATABASE_INSTANCE_ID"
)

for ALARM_CONFIG in "${ALARMS[@]}"; do
    IFS='|' read -r ALARM_NAME METRIC_NAME NAMESPACE STATISTIC PERIOD EVAL_PERIODS THRESHOLD COMPARISON INSTANCE_ID <<< "$ALARM_CONFIG"
    
    # Vérifier si l'alarme existe
    if aws cloudwatch describe-alarms --alarm-names "$ALARM_NAME" --region $REGION --query "MetricAlarms[0].AlarmName" --output text 2>/dev/null | grep -q "$ALARM_NAME"; then
        log_warning "Alarme '$ALARM_NAME' existe déjà"
    else
        create_alarm "$ALARM_NAME" "$METRIC_NAME" "$NAMESPACE" "$STATISTIC" "$PERIOD" "$EVAL_PERIODS" "$THRESHOLD" "$COMPARISON" "$INSTANCE_ID"
    fi
done

echo ""
log_info "✅ Vérification terminée!"
echo ""
log_info "📊 Liste des alarmes dans la région $REGION:"
aws cloudwatch describe-alarms \
    --alarm-name-prefix "$ENV_NAME-" \
    --region $REGION \
    --query "MetricAlarms[*].[AlarmName,StateValue]" \
    --output table

echo ""
log_info "🔗 Accès dans la console:"
echo "   https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:"

