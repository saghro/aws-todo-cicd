#!/bin/bash

# Script pour réinitialiser le mot de passe PostgreSQL
# Usage: ./scripts/reset-db-password.sh

set -e

# Charger les variables depuis outputs.txt
if [ ! -f "outputs.txt" ]; then
    echo "❌ Fichier outputs.txt non trouvé. Exécutez d'abord ./scripts/deploy.sh"
    exit 1
fi

source outputs.txt

echo "🔐 Réinitialisation du mot de passe PostgreSQL"
echo "================================================"

# Vérifier que le fichier de clé SSH existe
KEY_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Fichier de clé SSH non trouvé: $KEY_FILE"
    exit 1
fi

chmod 600 $KEY_FILE

# Demander le nouveau mot de passe
read -sp "Nouveau mot de passe pour l'utilisateur PostgreSQL 'todouser': " NEW_DB_PASSWORD
echo ""
read -sp "Confirmer le mot de passe: " CONFIRM_PASSWORD
echo ""

if [ "$NEW_DB_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
    echo "❌ Les mots de passe ne correspondent pas"
    exit 1
fi

if [ -z "$NEW_DB_PASSWORD" ]; then
    echo "❌ Le mot de passe ne peut pas être vide"
    exit 1
fi

# Copier la clé SSH sur le serveur web si nécessaire
echo "🔑 Vérification de la clé SSH sur le serveur web..."
if ! ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=5 ec2-user@$WEBSERVER_IP "test -f ~/.ssh/${KEY_PAIR_NAME}.pem" 2>/dev/null; then
    echo "📤 Copie de la clé SSH sur le serveur web..."
    scp -i $KEY_FILE \
        -o StrictHostKeyChecking=no \
        $KEY_FILE \
        ec2-user@$WEBSERVER_IP:~/.ssh/${KEY_PAIR_NAME}.pem
    
    ssh -i $KEY_FILE \
        -o StrictHostKeyChecking=no \
        ec2-user@$WEBSERVER_IP "chmod 600 ~/.ssh/${KEY_PAIR_NAME}.pem"
fi

# Se connecter à la base de données via le serveur web et réinitialiser le mot de passe
echo "🔧 Réinitialisation du mot de passe PostgreSQL..."
ssh -i $KEY_FILE \
    -o StrictHostKeyChecking=no \
    ec2-user@$WEBSERVER_IP bash << EOF

# Exporter le nouveau mot de passe
export NEW_DB_PASSWORD='${NEW_DB_PASSWORD}'

# Se connecter à la base de données et changer le mot de passe
ssh -i ~/.ssh/${KEY_PAIR_NAME}.pem \
    -o StrictHostKeyChecking=no \
    ec2-user@$DATABASE_IP bash << INNER_EOF

# Changer le mot de passe de l'utilisateur todouser
sudo -u postgres psql << PSQL_EOF
ALTER USER todouser WITH PASSWORD '\${NEW_DB_PASSWORD}';
\q
PSQL_EOF

# Vérifier que le changement a fonctionné
echo "✅ Mot de passe réinitialisé avec succès"

# Afficher un message de confirmation
echo ""
echo "📋 Informations mises à jour:"
echo "  • Database IP: $DATABASE_IP"
echo "  • Database Name: tododb"
echo "  • Database User: todouser"
echo "  • Database Password: [nouveau mot de passe configuré]"

INNER_EOF

EOF

echo ""
echo "================================================"
echo "✅ Mot de passe PostgreSQL réinitialisé!"
echo "================================================"
echo ""
echo "📝 Important:"
echo "  • Notez ce mot de passe dans un endroit sûr"
echo "  • Vous en aurez besoin pour déployer l'application (./scripts/deploy-app.sh)"
echo ""
echo "🔗 Pour tester la connexion:"
echo "  ssh -i $KEY_FILE ec2-user@$WEBSERVER_IP"
echo "  ssh -i ~/.ssh/${KEY_PAIR_NAME}.pem ec2-user@$DATABASE_IP"
echo "  sudo -u postgres psql -d tododb -U todouser"
echo ""

