#!/bin/bash

# Script de vérification pré-déploiement
# Usage: ./scripts/pre-deploy-check.sh

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 Vérification pré-déploiement"
echo "================================================"
echo ""

ERRORS=0

# Vérifier AWS CLI
echo -n "Vérification AWS CLI... "
if command -v aws &> /dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    echo "  Installez AWS CLI: https://aws.amazon.com/cli/"
    ERRORS=$((ERRORS + 1))
fi

# Vérifier la configuration AWS
echo -n "Vérification configuration AWS... "
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅${NC} (Compte: $ACCOUNT_ID)"
else
    echo -e "${RED}❌${NC}"
    echo "  Exécutez: aws configure"
    ERRORS=$((ERRORS + 1))
fi

# Vérifier les fichiers nécessaires
echo -n "Vérification infrastructure.yml... "
if [ -f "infrastructure/infrastructure.yml" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Vérification database/init.sql... "
if [ -f "database/init.sql" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Vérification scripts/deploy.sh... "
if [ -f "scripts/deploy.sh" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Vérification scripts/setup-database.sh... "
if [ -f "scripts/setup-database.sh" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -n "Vérification scripts/deploy-app.sh... "
if [ -f "scripts/deploy-app.sh" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Vérifier les permissions des scripts
echo -n "Vérification permissions scripts... "
if [ -x "scripts/deploy.sh" ] && [ -x "scripts/setup-database.sh" ] && [ -x "scripts/deploy-app.sh" ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${YELLOW}⚠️${NC}  Correction des permissions..."
    chmod +x scripts/*.sh
    echo -e "${GREEN}✅${NC}"
fi

# Vérifier le template CloudFormation
echo -n "Validation template CloudFormation... "
if aws cloudformation validate-template --template-body file://infrastructure/infrastructure.yml &> /dev/null; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Vérifier l'AMI ID
echo -n "Vérification AMI ID... "
AMI_COUNT=$(grep -c "ami-0156001f0548e90b1" infrastructure/infrastructure.yml || echo "0")
if [ "$AMI_COUNT" -eq "2" ]; then
    echo -e "${GREEN}✅${NC} (2 occurrences trouvées)"
else
    echo -e "${YELLOW}⚠️${NC}  ($AMI_COUNT occurrences trouvées, attendu: 2)"
fi

# Vérifier la clé SSH
echo -n "Vérification clé SSH... "
if [ -f "$HOME/.ssh/todo-app-key.pem" ]; then
    PERMS=$(stat -f "%OLp" "$HOME/.ssh/todo-app-key.pem" 2>/dev/null || stat -c "%a" "$HOME/.ssh/todo-app-key.pem" 2>/dev/null)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "0600" ]; then
        echo -e "${GREEN}✅${NC}"
    else
        echo -e "${YELLOW}⚠️${NC}  Correction des permissions..."
        chmod 600 "$HOME/.ssh/todo-app-key.pem"
        echo -e "${GREEN}✅${NC}"
    fi
else
    echo -e "${YELLOW}⚠️${NC}  Clé non trouvée: ~/.ssh/todo-app-key.pem"
    echo "  Créez-la dans la console AWS EC2 → Key Pairs"
fi

echo ""
echo "================================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ Toutes les vérifications sont passées!${NC}"
    echo ""
    echo "🚀 Vous êtes prêt à déployer:"
    echo "  ./scripts/deploy.sh"
    exit 0
else
    echo -e "${RED}❌ $ERRORS erreur(s) trouvée(s)${NC}"
    echo ""
    echo "Corrigez les erreurs avant de déployer."
    exit 1
fi

