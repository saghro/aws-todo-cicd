#!/bin/bash

# Script pour configurer la base de données PostgreSQL sur EC2
# Usage: ./scripts/setup-database.sh

set -e

# Charger les variables depuis outputs.txt
if [ ! -f "outputs.txt" ]; then
    echo "❌ Fichier outputs.txt non trouvé. Exécutez d'abord ./scripts/deploy.sh"
    exit 1
fi

source outputs.txt

echo "🗄️  Configuration de la base de données PostgreSQL"
echo "================================================"

# Vérifier que le fichier de clé SSH existe
KEY_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Fichier de clé SSH non trouvé: $KEY_FILE"
    exit 1
fi

chmod 600 $KEY_FILE

# Demander le mot de passe de la base de données
read -sp "Mot de passe pour l'utilisateur PostgreSQL 'todouser': " DB_PASSWORD
echo ""

# Copier la clé SSH sur le serveur web (nécessaire pour se connecter à la base de données)
echo "🔑 Copie de la clé SSH sur le serveur web..."
scp -i $KEY_FILE \
    -o StrictHostKeyChecking=no \
    $KEY_FILE \
    ec2-user@$WEBSERVER_IP:~/.ssh/${KEY_PAIR_NAME}.pem

# Configurer les permissions de la clé sur le serveur web
ssh -i $KEY_FILE \
    -o StrictHostKeyChecking=no \
    ec2-user@$WEBSERVER_IP "chmod 600 ~/.ssh/${KEY_PAIR_NAME}.pem"

# Copier le script d'initialisation sur le serveur web (bastion)
echo "📤 Copie du script d'initialisation sur le serveur web (bastion)..."
scp -i $KEY_FILE \
    -o StrictHostKeyChecking=no \
    database/init.sql \
    ec2-user@$WEBSERVER_IP:/tmp/init.sql

# Copier le script depuis le serveur web vers la base de données et exécuter la configuration
echo "🔧 Configuration de PostgreSQL via le serveur web..."
ssh -i $KEY_FILE \
    -o StrictHostKeyChecking=no \
    ec2-user@$WEBSERVER_IP bash << EOF

# Exporter le mot de passe pour qu'il soit disponible dans le heredoc interne
export DB_PASSWORD='${DB_PASSWORD}'

# Copier le script vers la base de données
scp -i ~/.ssh/${KEY_PAIR_NAME}.pem \
    -o StrictHostKeyChecking=no \
    /tmp/init.sql \
    ec2-user@$DATABASE_IP:/tmp/init.sql

# Exécuter la configuration sur la base de données (passer DB_PASSWORD via l'environnement)
DB_PASSWORD='${DB_PASSWORD}' ssh -i ~/.ssh/${KEY_PAIR_NAME}.pem \
    -o StrictHostKeyChecking=no \
    ec2-user@$DATABASE_IP bash << INNER_EOF

# Modifier le mot de passe dans le script
sed -i "s/SecurePassword123!/\${DB_PASSWORD}/g" /tmp/init.sql

# Configurer PostgreSQL pour accepter les connexions
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf

# Configurer pg_hba.conf pour accepter les connexions depuis le subnet
sudo bash -c "echo 'host    all             all             10.0.1.0/24           md5' >> /var/lib/pgsql/data/pg_hba.conf"

# Redémarrer PostgreSQL
sudo systemctl restart postgresql

# Attendre que PostgreSQL soit prêt
sleep 3

# Exécuter le script d'initialisation
sudo -u postgres psql -f /tmp/init.sql

# Vérifier la connexion
sudo -u postgres psql -d tododb -c "SELECT COUNT(*) FROM todos;" || echo "⚠️  Erreur lors de la vérification"

echo "✅ Base de données configurée avec succès"

INNER_EOF

EOF

echo ""
echo "================================================"
echo "✅ Configuration de la base de données terminée!"
echo "================================================"
echo ""
echo "📊 Informations:"
echo "  • Database IP: $DATABASE_IP"
echo "  • Database Name: tododb"
echo "  • Database User: todouser"
echo "  • Database Password: [configuré]"
echo ""
echo "🔗 Pour vous connecter à la base de données (via le serveur web):"
echo "  ssh -i $KEY_FILE ec2-user@$WEBSERVER_IP"
echo "  ssh -i ~/.ssh/${KEY_PAIR_NAME}.pem ec2-user@$DATABASE_IP"
echo "  sudo -u postgres psql -d tododb"
echo ""

