# 📝 Todo App AWS - Application Complète avec CI/CD

Application Todo complète déployée sur AWS avec infrastructure as code, monitoring CloudWatch et pipeline CI/CD automatisé via GitHub Actions.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Internet                              │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  Internet Gateway     │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │         VPC            │
         │  ┌─────────────────┐ │
         │  │  Public Subnet   │ │
         │  │  ┌─────────────┐ │ │
         │  │  │ WebServer   │ │ │
         │  │  │ EC2 (t3.micro)│ │ │
         │  │  │ Port 3000   │ │ │
         │  │  │ Node.js API │ │ │
         │  │  └─────────────┘ │ │
         │  └─────────────────┘ │
         │  ┌─────────────────┐ │
         │  │ Private Subnet  │ │
         │  │  ┌─────────────┐ │ │
         │  │  │ Database    │ │ │
         │  │  │ EC2 (t3.micro)│ │ │
         │  │  │ PostgreSQL  │ │ │
         │  │  └─────────────┘ │ │
         │  └─────────────────┘ │
         └───────────────────────┘
                     │
         ┌───────────▼───────────┐
         │    CloudWatch        │
         │    + SNS Alerts      │<img width="2483" height="1701" alt="AWS Architecture Diagram" src="https://github.com/user-attachments/assets/eb6e3437-2106-41c2-9b7e-e0d6f0e35105" />

         └───────────────────────┘
```

## 🚀 Technologies

### Frontend
- **React** - Framework UI moderne
- **CSS personnalisé** - Design responsive

### Backend
- **Node.js** - Runtime JavaScript
- **Express** - Framework web
- **PostgreSQL** - Base de données relationnelle
- **Chalk** - Logs colorés (ANSI)

### Infrastructure
- **AWS CloudFormation** - Infrastructure as Code
- **AWS EC2** - Serveurs virtuels
- **AWS VPC** - Réseau privé isolé
- **AWS CloudWatch** - Monitoring et alertes
- **AWS SNS** - Notifications par email
- **GitHub Actions** - Pipeline CI/CD automatisé

## 📁 Structure du Projet

```
aws-todo-cicd/
├── frontend/              # Application React
│   ├── src/
│   │   ├── App.js        # Composant principal
│   │   ├── App.css       # Styles CSS
│   │   └── index.js      # Point d'entrée
│   ├── public/
│   ├── package.json
│   └── .env              # Configuration API URL
├── backend/               # API Node.js/Express
│   ├── server.js         # Serveur Express
│   ├── package.json
│   └── .env              # Variables d'environnement
├── database/              # Scripts SQL
│   └── init.sql          # Initialisation PostgreSQL
├── infrastructure/       # Infrastructure AWS
│   └── infrastructure.yml # Template CloudFormation
├── scripts/               # Scripts de déploiement
│   ├── pre-deploy-check.sh    # Vérification pré-déploiement
│   ├── deploy.sh              # Déploiement infrastructure
│   ├── setup-database.sh      # Configuration base de données
│   └── deploy-app.sh          # Déploiement application
├── .github/
│   └── workflows/
│       └── deploy.yml     # Pipeline CI/CD GitHub Actions
└── README.md             # Ce fichier
```

## 🚀 Démarrage Rapide

### Prérequis

```bash
# Vérifier AWS CLI
aws --version

# Configurer AWS
aws configure

# Vérifier la configuration
aws sts get-caller-identity
```

### Déploiement Manuel (3 étapes)

#### 1. Vérification Pré-Déploiement

```bash
./scripts/pre-deploy-check.sh
```

Ce script vérifie:
- ✅ AWS CLI installé et configuré
- ✅ Tous les fichiers nécessaires présents
- ✅ Permissions des scripts correctes
- ✅ Template CloudFormation valide
- ✅ Clé SSH disponible

#### 2. Déployer l'Infrastructure

```bash
./scripts/deploy.sh
```

Le script vous demandera:
- **Nom de la Key Pair EC2**: `todo-app-key`
- **Email pour les alertes SNS**: `votre@email.com`

**Durée**: 10-15 minutes

Le déploiement crée:
- ✅ VPC avec subnets public et privé
- ✅ Internet Gateway et Route Tables
- ✅ Security Groups
- ✅ Instances EC2 (WebServer + Database)
- ✅ Elastic IPs
- ✅ IAM Roles
- ✅ CloudWatch Alarms et Dashboard
- ✅ SNS Topic pour alertes

#### 3. Configurer la Base de Données

```bash
./scripts/setup-database.sh
```

Entrez le mot de passe pour l'utilisateur PostgreSQL `todouser`.

Le script:
- ✅ Configure PostgreSQL pour accepter les connexions
- ✅ Crée la base de données `tododb`
- ✅ Crée l'utilisateur `todouser`
- ✅ Crée la table `todos`
- ✅ Insère des données de test

#### 4. Déployer l'Application

```bash
./scripts/deploy-app.sh
```

Entrez le même mot de passe que celui utilisé à l'étape 3.

Le script:
- ✅ Crée le fichier `.env` avec les variables d'environnement
- ✅ Crée une archive de l'application
- ✅ Copie l'application sur le serveur EC2
- ✅ Installe les dépendances
- ✅ Démarre l'application

### Tester l'Application

```bash
# Récupérer l'IP du serveur depuis CloudFormation
WEBSERVER_IP=$(aws cloudformation describe-stacks \
  --stack-name todo-app-stack \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='WebServerPublicIP'].OutputValue" \
  --output text)

# Test health check
curl http://$WEBSERVER_IP:3000/health

# Test liste des todos
curl http://$WEBSERVER_IP:3000/api/todos

# Accéder au frontend
open http://$WEBSERVER_IP:3000
```

## 🔄 CI/CD Automatique avec GitHub Actions

Le pipeline CI/CD se déclenche automatiquement sur chaque push vers `main`.

### Configuration GitHub Secrets

Configurez ces secrets dans GitHub (Settings → Secrets → Actions):

| Secret | Description | Exemple |
|--------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `EC2_KEY_PAIR_NAME` | Nom de la key pair EC2 | `todo-app-key` |
| `EC2_SSH_PRIVATE_KEY` | Contenu du fichier .pem (complet) | Contenu du fichier .pem |
| `ALERT_EMAIL` | Email pour alertes SNS | `admin@example.com` |
| `DB_PASSWORD` | Mot de passe PostgreSQL | `SecurePassword123!` |

### Créer la Key Pair EC2

```bash
# Si vous n'avez pas encore de key pair
aws ec2 create-key-pair \
  --key-name todo-app-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/todo-app-key.pem

chmod 400 ~/.ssh/todo-app-key.pem
```

### Pipeline GitHub Actions

Le workflow (`.github/workflows/deploy.yml`) comprend:

1. **Run Tests** - Exécution des tests backend
2. **Build Application** - Compilation du frontend et backend
3. **Deploy AWS Infrastructure** - Déploiement CloudFormation
4. **Deploy Database** - Initialisation PostgreSQL
5. **Deploy Application** - Déploiement sur EC2
6. **Health Check** - Vérification de l'API
7. **Send Notification** - Notification de succès/échec

### Déclenchement

Le pipeline se déclenche automatiquement sur:
- ✅ Push sur la branche `main`
- ✅ Pull Request vers `main`

## 🛠️ Développement Local

### Backend

```bash
cd backend
npm install
npm start
```

Le serveur démarre sur `http://localhost:3000`

### Frontend

```bash
cd frontend
npm install
npm start
```

L'application démarre sur `http://localhost:3001`

### Configuration API

Modifiez `frontend/.env`:

```env
REACT_APP_API_URL=http://localhost:3000
```

## 📊 Monitoring CloudWatch

### Dashboard

1. Connectez-vous à la [Console AWS](https://console.aws.amazon.com)
2. Allez dans **CloudWatch** → **Dashboards**
3. Sélectionnez `prod-todo-app-dashboard`

Le dashboard affiche:
- **CPU Utilization** - Utilisation CPU des instances
- **Network Traffic** - Trafic réseau entrant/sortant
- **Status Check** - État des instances

### Alarmes Configurées

- `prod-webserver-high-cpu` - CPU > 80% pendant 5 minutes
- `prod-webserver-status-check-failed` - Échec du status check
- `prod-database-high-cpu` - CPU > 80% pendant 5 minutes
- `prod-database-status-check-failed` - Échec du status check

### Logs

Les logs de l'application sont collectés automatiquement:
- **Log Group**: `/aws/ec2/todo-app/webserver`
- **Log Stream**: `{instance_id}`

**Accès**: Console AWS → CloudWatch → Logs → Log groups

### SNS

- Alertes par email en temps réel
- Notifications pour toutes les alarmes CloudWatch
- Abonnement requis lors du premier déploiement

## 🔐 Sécurité

- ✅ VPC avec subnets privés
- ✅ Security Groups restrictifs
- ✅ Base de données dans subnet privé (non accessible depuis Internet)
- ✅ IAM Roles avec permissions minimales
- ✅ HTTPS recommandé en production

## 📝 API Endpoints

- `GET /api` - Documentation API
- `GET /health` - Health check
- `GET /api/todos` - Liste des tâches
- `GET /api/todos/:id` - Détails d'une tâche
- `POST /api/todos` - Créer une tâche
- `PUT /api/todos/:id` - Modifier une tâche
- `DELETE /api/todos/:id` - Supprimer une tâche
- `GET /api/todos/stats` - Statistiques

## 🗄️ Base de Données

### Connexion via CLI

```bash
# 1. Se connecter au WebServer
ssh -i ~/.ssh/todo-app-key.pem ec2-user@<WEBSERVER_IP>

# 2. Installer le client PostgreSQL (si nécessaire)
sudo yum install -y postgresql

# 3. Se connecter à PostgreSQL
psql -h 10.0.2.181 -U todouser -d tododb
```

### Commandes PostgreSQL Utiles

```sql
-- Lister les tables
\dt

-- Voir la structure de la table todos
\d todos

-- Voir toutes les tâches
SELECT * FROM todos;

-- Compter le nombre de tâches
SELECT COUNT(*) FROM todos;

-- Voir les tâches complétées
SELECT * FROM todos WHERE completed = true;

-- Quitter
\q
```

## 🔧 Configuration

### Variables d'Environnement Backend

```env
PORT=3000
NODE_ENV=production
DB_HOST=10.0.2.181
DB_PORT=5432
DB_NAME=tododb
DB_USER=todouser
DB_PASSWORD=VotreMotDePasse123!
```

### Variables d'Environnement Frontend

```env
PORT=3001
REACT_APP_API_URL=http://<WEBSERVER_IP>:3000
```

## 🧪 Tests

### Test du Backend

```bash
cd backend
npm test
```

### Test du Frontend

```bash
cd frontend
npm test
```

## 📄 Licence

MIT

## 👥 Auteur

juba

## 🙏 Remerciements

- AWS pour l'infrastructure
- React pour le frontend
- Express pour le backend
- PostgreSQL pour la base de données
- GitHub Actions pour le CI/CD
