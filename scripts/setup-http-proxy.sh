#!/bin/bash

# Script pour configurer le serveur web comme proxy HTTP
# Permet à l'instance de base de données d'accéder à Internet via le serveur web

set -e

source outputs.txt

KEY_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"

echo "🔧 Configuration du proxy HTTP sur le serveur web"
echo "================================================"

ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$WEBSERVER_IP bash << EOF

# Installer squid (proxy HTTP)
echo "📦 Installation de squid..."
sudo yum install -y squid

# Configurer squid pour accepter les connexions depuis le subnet privé
echo "🔧 Configuration de squid..."
sudo tee /etc/squid/squid.conf > /dev/null << SQUID_CONF
# Écouter sur IPv4 uniquement
http_port 0.0.0.0:3128

# ACL pour le réseau local
acl localnet src 10.0.0.0/16
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 21
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT

# Règles d'accès - permettre localnet d'abord
http_access allow localnet
http_access allow CONNECT localnet
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access deny all

# Configuration
visible_hostname webserver
coredump_dir /var/spool/squid

# Logging pour debug
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
SQUID_CONF

# Démarrer squid
echo "🚀 Démarrage de squid..."
sudo systemctl start squid
sudo systemctl enable squid

# Vérifier que squid fonctionne
if sudo systemctl is-active --quiet squid; then
    echo "✅ Squid est en cours d'exécution sur le port 3128"
else
    echo "❌ Erreur: Squid n'est pas en cours d'exécution"
    exit 1
fi

EOF

echo ""
echo "✅ Proxy HTTP configuré sur le serveur web"
echo ""
echo "📋 Configuration du proxy sur la base de données..."
echo "   (Cette étape sera faite lors de l'installation de PostgreSQL)"

