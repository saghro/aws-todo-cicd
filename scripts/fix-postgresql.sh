#!/bin/bash

# Script pour configurer PostgreSQL sur l'instance Database
# Usage: ./scripts/fix-postgresql.sh [STACK_NAME] [REGION] [KEY_PATH]

set -e

STACK_NAME=${1:-"todo-app-stack"}
REGION=${2:-"us-east-1"}
KEY_PATH=${3:-"~/.ssh/todo-app-key.pem"}

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

echo "🔧 Configuration de PostgreSQL sur l'instance Database"
echo "========================================================"
echo ""

# Récupérer l'IP de la Database
log_info "Récupération de l'IP de la Database..."
DATABASE_IP=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='DatabasePrivateIP'].OutputValue" \
    --output text)

if [ -z "$DATABASE_IP" ] || [ "$DATABASE_IP" == "None" ]; then
    log_error "Impossible de récupérer l'IP de la Database"
    exit 1
fi

log_info "Database IP: $DATABASE_IP"
echo ""

# Récupérer l'IP du WebServer pour la connexion SSH
log_info "Récupération de l'IP du WebServer..."
WEBSERVER_IP=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "Stacks[0].Outputs[?OutputKey=='WebServerPublicIP'].OutputValue" \
    --output text)

if [ -z "$WEBSERVER_IP" ] || [ "$WEBSERVER_IP" == "None" ]; then
    log_error "Impossible de récupérer l'IP du WebServer"
    exit 1
fi

log_info "WebServer IP: $WEBSERVER_IP"
echo ""

# Vérifier que la clé SSH existe
if [ ! -f "$KEY_PATH" ]; then
    log_error "La clé SSH n'existe pas: $KEY_PATH"
    exit 1
fi

log_info "Configuration de PostgreSQL via le WebServer..."
echo ""

# Se connecter au WebServer puis à la Database
ssh -o StrictHostKeyChecking=no \
    -i "$KEY_PATH" \
    ec2-user@$WEBSERVER_IP << EOF
    echo "🔧 Configuration de PostgreSQL sur la Database..."
    
    # Se connecter à la Database
    ssh -o StrictHostKeyChecking=no \
        -i ~/.ssh/id_rsa \
        ec2-user@$DATABASE_IP << 'DB_CONFIG'
    echo "📦 Vérification de PostgreSQL..."
    
    # Vérifier si PostgreSQL est installé
    if ! command -v psql &> /dev/null; then
        echo "⚠️  PostgreSQL n'est pas installé, installation en cours..."
        sudo yum update -y
        sudo amazon-linux-extras install postgresql14 -y
        sudo yum install -y postgresql-server postgresql-contrib
        sudo postgresql-setup initdb
    fi
    
    # Vérifier si PostgreSQL est démarré
    if ! sudo systemctl is-active --quiet postgresql; then
        echo "🚀 Démarrage de PostgreSQL..."
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
    else
        echo "✅ PostgreSQL est déjà démarré"
    fi
    
    # Configurer PostgreSQL pour écouter sur toutes les interfaces
    echo "🔧 Configuration de PostgreSQL pour écouter sur toutes les interfaces..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf
    sudo sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf || true
    
    # Configurer pg_hba.conf pour autoriser les connexions depuis le WebServer
    echo "🔧 Configuration de pg_hba.conf..."
    if ! sudo grep -q "10.0.1.0/24" /var/lib/pgsql/data/pg_hba.conf; then
        echo "host    all             all             10.0.1.0/24          md5" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf
    fi
    if ! sudo grep -q "10.0.2.0/24" /var/lib/pgsql/data/pg_hba.conf; then
        echo "host    all             all             10.0.2.0/24          md5" | sudo tee -a /var/lib/pgsql/data/pg_hba.conf
    fi
    
    # Redémarrer PostgreSQL pour appliquer les changements
    echo "🔄 Redémarrage de PostgreSQL..."
    sudo systemctl restart postgresql
    sleep 3
    
    # Vérifier que PostgreSQL écoute sur le port 5432
    echo "🔍 Vérification du port 5432..."
    sudo netstat -tlnp | grep :5432 || echo "⚠️  Port 5432 pas encore en écoute"
    
    # Créer la base de données et l'utilisateur
    echo "📦 Création de la base de données et de l'utilisateur..."
    sudo -u postgres psql << 'PSQL_INIT'
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'todouser') THEN
            CREATE USER todouser WITH PASSWORD 'VotreMotDePasse123!';
        END IF;
    END
    \$\$;
    
    SELECT 'CREATE DATABASE tododb OWNER todouser' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'tododb')\gexec
    
    \c tododb
    GRANT ALL PRIVILEGES ON DATABASE tododb TO todouser;
    GRANT ALL ON SCHEMA public TO todouser;
    
    -- Créer la table todos si elle n'existe pas
    CREATE TABLE IF NOT EXISTS todos (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        completed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    GRANT ALL PRIVILEGES ON TABLE todos TO todouser;
    GRANT USAGE, SELECT ON SEQUENCE todos_id_seq TO todouser;
    
    -- Insérer des données de test
    INSERT INTO todos (title, description, completed) VALUES
        ('Configurer AWS Infrastructure', 'Déployer VPC, subnets, EC2', true),
        ('Installer PostgreSQL', 'Installer et configurer PostgreSQL sur EC2 privé', false),
        ('Déployer l''application', 'Déployer React + Node.js sur EC2 public', false),
        ('Configurer CloudWatch', 'Mettre en place monitoring et alertes', false),
        ('Tester le pipeline CI/CD', 'Vérifier que GitHub Actions fonctionne', false)
    ON CONFLICT DO NOTHING;
    
    SELECT '✅ Base de données configurée avec succès!' as status;
PSQL_INIT
    
    echo ""
    echo "✅ Configuration terminée!"
    echo "🔍 Test de connexion..."
    sudo -u postgres psql -c "SELECT version();" || echo "⚠️  Test de connexion échoué"
DB_CONFIG
EOF

echo ""
log_info "✅ Configuration terminée!"
echo ""
log_info "Testez maintenant l'API:"
echo "  curl http://$WEBSERVER_IP:3000/health"
echo "  curl http://$WEBSERVER_IP:3000/api/todos"

