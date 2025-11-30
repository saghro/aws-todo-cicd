#!/bin/bash

# Script pour déployer l'application sur EC2
# Usage: ./scripts/deploy-app.sh

set -e

# Charger les variables
source outputs.txt

echo "🚀 Déploiement de l'application Todo"
echo "================================================"

# Vérifier que le fichier de clé SSH existe
KEY_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Fichier de clé SSH non trouvé: $KEY_FILE"
    exit 1
fi

chmod 600 $KEY_FILE

# Demander le mot de passe de la base de données
read -sp "Mot de passe de la base de données: " DB_PASSWORD
echo ""

# Créer le fichier .env
cat > backend/.env << EOF
PORT=3000
NODE_ENV=production
DB_HOST=$DATABASE_IP
DB_PORT=5432
DB_NAME=tododb
DB_USER=todouser
DB_PASSWORD=$DB_PASSWORD
EOF

echo "📦 Création de l'archive de l'application..."
tar -czf app.tar.gz backend/

echo "📤 Copie de l'application sur le serveur..."
scp -i $KEY_FILE \
    -o StrictHostKeyChecking=no \
    app.tar.gz \
    ec2-user@$WEBSERVER_IP:/home/ec2-user/

echo "🔧 Installation et démarrage de l'application..."
ssh -i $KEY_FILE \
    -o StrictHostKeyChecking=no \
    ec2-user@$WEBSERVER_IP << 'EOF'

# Extraire l'application
cd /home/ec2-user
rm -rf app
mkdir app
tar -xzf app.tar.gz -C app --strip-components=1
cd app

# Installer les dépendances
npm install --production

# Arrêter l'ancienne instance
pkill -f "node server.js" || true

# Démarrer l'application
nohup node server.js > app.log 2>&1 &

echo "✅ Application démarrée"

# Attendre que l'application démarre
sleep 5

# Vérifier que l'application fonctionne
curl -s http://localhost:3000/health || echo "⚠️  L'API ne répond pas encore"

EOF

echo ""
echo "================================================"
echo "✅ Déploiement terminé!"
echo "================================================"
echo ""
echo "🌐 Application accessible sur:"
echo "  http://$WEBSERVER_IP:3000"
echo ""
echo "🔍 Vérification de l'API:"
echo "  curl http://$WEBSERVER_IP:3000/health"
echo "  curl http://$WEBSERVER_IP:3000/api/todos"
echo ""
echo "📋 Pour voir les logs:"
echo "  ssh -i $KEY_FILE ec2-user@$WEBSERVER_IP"
echo "  tail -f ~/app/app.log"
echo ""

# Nettoyage
rm app.tar.gz

# Test de l'API
echo "🧪 Test de l'API..."
sleep 3
curl -s http://$WEBSERVER_IP:3000/health | jq . || echo "Installez jq pour formater le JSON"