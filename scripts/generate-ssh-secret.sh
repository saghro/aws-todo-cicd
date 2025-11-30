#!/bin/bash

# Script pour générer un fichier avec le contenu exact à copier dans GitHub Secrets
# Usage: ./scripts/generate-ssh-secret.sh [KEY_PATH]

set -e

KEY_PATH=${1:-"~/.ssh/todo-app-key.pem"}

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

# Expansion du chemin
KEY_PATH="${KEY_PATH/#\~/$HOME}"

# Vérifier que la clé existe
if [ ! -f "$KEY_PATH" ]; then
    log_error "La clé SSH n'existe pas: $KEY_PATH"
    exit 1
fi

# Vérifier que la clé est valide
if ! ssh-keygen -l -f "$KEY_PATH" &> /dev/null; then
    log_error "La clé SSH n'est pas valide"
    exit 1
fi

# Créer le fichier de sortie
OUTPUT_FILE="github-ssh-secret.txt"

log_info "Génération du fichier pour GitHub Secrets..."
log_info "Fichier de sortie: $OUTPUT_FILE"
echo ""

# Écrire le contenu de la clé dans le fichier
cat "$KEY_PATH" > "$OUTPUT_FILE"

# Afficher des informations
log_info "✅ Fichier généré avec succès!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "📋 Instructions pour configurer GitHub Secrets:"
echo ""
echo "1. Ouvrez le fichier généré:"
echo "   ${BLUE}cat $OUTPUT_FILE${NC}"
echo "   ou"
echo "   ${BLUE}open $OUTPUT_FILE${NC}"
echo ""
echo "2. Sélectionnez TOUT le contenu (Cmd+A ou Ctrl+A)"
echo ""
echo "3. Copiez le contenu (Cmd+C ou Ctrl+C)"
echo ""
echo "4. Allez dans GitHub:"
echo "   ${BLUE}https://github.com/VOTRE_USERNAME/aws-todo-cicd/settings/secrets/actions${NC}"
echo ""
echo "5. Cliquez sur 'New repository secret' (ou modifiez EC2_SSH_PRIVATE_KEY)"
echo ""
echo "6. Remplissez:"
echo "   Name: ${GREEN}EC2_SSH_PRIVATE_KEY${NC}"
echo "   Secret: ${GREEN}Collez le contenu copié${NC}"
echo ""
echo "7. Cliquez sur 'Add secret' (ou 'Update secret')"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "📄 Aperçu du contenu (premières et dernières lignes):"
echo ""
head -3 "$OUTPUT_FILE"
echo "..."
tail -3 "$OUTPUT_FILE"
echo ""
log_info "Taille du fichier: $(wc -c < "$OUTPUT_FILE") octets"
log_info "Nombre de lignes: $(wc -l < "$OUTPUT_FILE")"
echo ""
log_warning "⚠️  Important: Copiez TOUT le contenu, y compris les lignes BEGIN et END!"

