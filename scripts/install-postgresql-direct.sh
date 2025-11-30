#!/bin/bash

# Script pour installer PostgreSQL en utilisant une méthode directe
# Évite les problèmes de substitution de variables dans les heredocs imbriqués

set -e

source outputs.txt

KEY_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"

echo "📦 Installation de PostgreSQL (méthode directe)"
echo "================================================"

# Copier la clé SSH sur le serveur web si nécessaire
if ! ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=5 ec2-user@$WEBSERVER_IP "test -f ~/.ssh/${KEY_PAIR_NAME}.pem" 2>/dev/null; then
    echo "📤 Copie de la clé SSH sur le serveur web..."
    scp -i $KEY_FILE -o StrictHostKeyChecking=no $KEY_FILE ec2-user@$WEBSERVER_IP:~/.ssh/${KEY_PAIR_NAME}.pem
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$WEBSERVER_IP "chmod 600 ~/.ssh/${KEY_PAIR_NAME}.pem"
fi

# Créer un script temporaire pour installer PostgreSQL
INSTALL_SCRIPT="/tmp/install-postgresql-$$.sh"

cat > $INSTALL_SCRIPT << 'SCRIPT_EOF'
#!/bin/bash
set -e

WEBSERVER_IP="$1"
DATABASE_IP="$2"
KEY_PAIR_NAME="$3"

echo "📦 Vérification de l'état de PostgreSQL..."

# Récupérer l'IP privée du serveur web (pour la connexion depuis le subnet privé)
WEBSERVER_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "${WEBSERVER_IP}")

# Se connecter à la base de données et vérifier
ssh -i ~/.ssh/${KEY_PAIR_NAME}.pem -o StrictHostKeyChecking=no ec2-user@${DATABASE_IP} bash << DB_SCRIPT
# Vérifier si PostgreSQL est installé
if command -v psql &> /dev/null; then
    echo "✅ PostgreSQL est déjà installé"
    psql --version
    exit 0
fi

echo "📦 PostgreSQL n'est pas installé"
echo "🔄 Installation via proxy HTTP..."

# Utiliser l'IP privée du serveur web pour le proxy (accessible depuis le subnet privé)
PROXY_URL="http://${WEBSERVER_PRIVATE_IP}:3128"
echo "🔍 Configuration du proxy: \$PROXY_URL"

# Configurer le proxy pour yum (même si le test curl échoue, yum peut fonctionner)
echo "🔧 Configuration du proxy pour yum..."
if ! grep -q "^proxy=" /etc/yum.conf; then
    echo "proxy=\$PROXY_URL" | sudo tee -a /etc/yum.conf > /dev/null
    echo "✅ Proxy configuré pour yum: \$PROXY_URL"
else
    # Mettre à jour le proxy si déjà configuré
    sudo sed -i "s|^proxy=.*|proxy=\$PROXY_URL|" /etc/yum.conf
    echo "✅ Proxy mis à jour pour yum: \$PROXY_URL"
fi

# Tester le proxy (optionnel, mais utile pour le debug)
export http_proxy=\$PROXY_URL
export https_proxy=\$PROXY_URL
export HTTP_PROXY=\$PROXY_URL
export HTTPS_PROXY=\$PROXY_URL

if curl -s --max-time 5 http://www.google.com > /dev/null 2>&1; then
    echo "✅ Proxy HTTP fonctionnel (test curl réussi)"
else
    echo "⚠️  Test curl échoué, mais yum devrait fonctionner avec le proxy configuré"
fi

# Installer PostgreSQL
echo "📦 Installation de PostgreSQL..."
echo "⏳ Étape 1/4: Mise à jour du système (peut prendre quelques minutes)..."
sudo yum update -y || echo "⚠️  Aucune mise à jour disponible (normal)"

echo "⏳ Étape 2/4: Installation de PostgreSQL 14 via amazon-linux-extras (peut prendre 5-10 minutes)..."
sudo amazon-linux-extras install postgresql14 -y || {
    echo "❌ Erreur lors de l'installation de postgresql14"
    exit 1
}

echo "⏳ Étape 3/4: Installation des packages postgresql-server et postgresql-contrib..."
sudo yum install -y postgresql-server postgresql-contrib || {
    echo "❌ Erreur lors de l'installation des packages PostgreSQL"
    exit 1
}

# Initialiser PostgreSQL
if [ ! -d /var/lib/pgsql/data ]; then
    echo "🔧 Initialisation de la base de données..."
    sudo postgresql-setup initdb
fi

# Configurer PostgreSQL
echo "🔧 Configuration de PostgreSQL..."
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf 2>/dev/null || true
sudo bash -c "echo 'host    all             all             10.0.1.0/24           md5' >> /var/lib/pgsql/data/pg_hba.conf" 2>/dev/null || true

# Démarrer PostgreSQL
echo "🚀 Démarrage de PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Vérifier
if command -v psql &> /dev/null; then
    echo "✅ PostgreSQL installé avec succès"
    sudo -u postgres psql --version
    sudo systemctl status postgresql --no-pager | head -3
else
    echo "❌ Échec de l'installation"
    exit 1
fi
DB_SCRIPT

SCRIPT_EOF

chmod +x $INSTALL_SCRIPT

# Copier le script sur le serveur web
echo "📤 Copie du script d'installation sur le serveur web..."
scp -i $KEY_FILE -o StrictHostKeyChecking=no $INSTALL_SCRIPT ec2-user@$WEBSERVER_IP:/tmp/install-postgresql.sh

# Exécuter le script sur le serveur web
echo "🚀 Exécution du script d'installation..."
ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$WEBSERVER_IP bash << EOF
chmod +x /tmp/install-postgresql.sh
/tmp/install-postgresql.sh ${WEBSERVER_IP} ${DATABASE_IP} ${KEY_PAIR_NAME}
rm -f /tmp/install-postgresql.sh
EOF

# Nettoyer le script local
rm -f $INSTALL_SCRIPT

echo ""
echo "================================================"
echo "✅ Installation terminée!"
echo "================================================"
echo ""
echo "📋 Prochaine étape:"
echo "   ./scripts/setup-database.sh"

