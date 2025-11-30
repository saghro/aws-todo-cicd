#!/bin/bash

# Script pour enrichir le dashboard CloudWatch après le déploiement
# Usage: ./scripts/enrich-dashboard.sh [STACK_NAME] [REGION]

set -e

STACK_NAME=${1:-"todo-app-stack"}
REGION=${2:-"us-east-1"}
ENV_NAME=${3:-"prod"}

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

echo "📊 Enrichissement du dashboard CloudWatch"
echo "=========================================="
echo ""

# Récupérer les IDs d'instance
log_info "Récupération des IDs d'instance..."
WEBSERVER_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='WebServerInstanceId'].OutputValue" \
    --output text 2>/dev/null || \
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${ENV_NAME}-webserver" "Name=instance-state-name,Values=running" \
        --region $REGION \
        --query "Reservations[0].Instances[0].InstanceId" \
        --output text)

DATABASE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${ENV_NAME}-database" "Name=instance-state-name,Values=running" \
    --region $REGION \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text)

if [ -z "$WEBSERVER_ID" ] || [ "$WEBSERVER_ID" == "None" ]; then
    log_error "Impossible de trouver l'ID de l'instance WebServer"
    exit 1
fi

if [ -z "$DATABASE_ID" ] || [ "$DATABASE_ID" == "None" ]; then
    log_error "Impossible de trouver l'ID de l'instance Database"
    exit 1
fi

log_info "WebServer Instance ID: $WEBSERVER_ID"
log_info "Database Instance ID: $DATABASE_ID"
echo ""

# Créer le body du dashboard enrichi
DASHBOARD_BODY=$(cat <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", {"InstanceId": "$WEBSERVER_ID"}],
          [".", ".", {"InstanceId": "$DATABASE_ID"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "$REGION",
        "title": "CPU Utilization (%)"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "NetworkIn", {"InstanceId": "$WEBSERVER_ID"}],
          ["...", {"InstanceId": "$DATABASE_ID"}],
          ["AWS/EC2", "NetworkOut", {"InstanceId": "$WEBSERVER_ID"}],
          ["...", {"InstanceId": "$DATABASE_ID"}]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "$REGION",
        "title": "Network Traffic (Bytes)"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "StatusCheckFailed", {"InstanceId": "$WEBSERVER_ID"}],
          [".", ".", {"InstanceId": "$DATABASE_ID"}]
        ],
        "period": 60,
        "stat": "Maximum",
        "region": "$REGION",
        "title": "Status Check Failed"
      }
    }
  ]
}
EOF
)

# Mettre à jour le dashboard
log_info "Mise à jour du dashboard CloudWatch..."
aws cloudwatch put-dashboard \
    --dashboard-name "${ENV_NAME}-todo-app-dashboard" \
    --dashboard-body "$DASHBOARD_BODY" \
    --region $REGION

if [ $? -eq 0 ]; then
    log_info "✅ Dashboard enrichi avec succès!"
    echo ""
    log_info "URL du dashboard:"
    echo "https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:name=${ENV_NAME}-todo-app-dashboard"
else
    log_error "❌ Échec de la mise à jour du dashboard"
    exit 1
fi

