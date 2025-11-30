# 📝 Todo App AWS - Projet CI/CD

Application Todo complète déployée sur AWS avec infrastructure as code, monitoring et CI/CD automatisé.

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
         │         VPC           │
         │  ┌─────────────────┐ │
         │  │  Public Subnet   │ │
         │  │  ┌─────────────┐ │ │
         │  │  │ WebServer   │ │ │
         │  │  │ EC2 (t3.micro)│ │ │
         │  │  │ Port 3000   │ │ │
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
         │    + SNS Alerts      │
         └───────────────────────┘
```

## 🚀 Technologies

### Frontend
- **React 19** - Framework UI
- **Tailwind CSS v4** - Styling
- **CSS personnalisé** - Design moderne

### Backend
- **Node.js** - Runtime
- **Express 5** - Framework web
- **PostgreSQL** - Base de données
- **Chalk** - Logs colorés (ANSI)

### Infrastructure
- **AWS CloudFormation** - Infrastructure as Code
- **AWS EC2** - Serveurs
- **AWS VPC** - Réseau privé
- **AWS CloudWatch** - Monitoring
- **AWS SNS** - Alertes
- **GitHub Actions** - CI/CD

## 📁 Structure du Projet

```
aws-todo-cicd/
├── frontend/              # Application React
│   ├── src/
│   │   ├── App.js        # Composant principal
│   │   ├── App.css       # Styles CSS personnalisés
│   │   └── index.css     # Styles globaux
│   ├── public/
│   ├── package.json
│   └── .env              # Configuration API URL
├── backend/               # API Node.js
│   ├── server.js         # Serveur Express
│   ├── package.json
│   └── .env              # Variables d'environnement
├── database/              # Scripts SQL
│   └── init.sql          # Initialisation PostgreSQL
├── infrastructure/        # Infrastructure AWS
│   └── infrastructure.yml # Template CloudFormation
├── scripts/               # Scripts de déploiement
│   ├── pre-deploy-check.sh    # Vérification pré-déploiement
│   ├── deploy.sh              # Déploiement infrastructure
│   ├── setup-database.sh      # Configuration base de données
│   └── deploy-app.sh          # Déploiement application
├── .github/
│   └── workflows/
│       └── deploy.yml     # Pipeline CI/CD
└── README.md             # Ce fichier
```

## 🚀 Démarrage Rapide

### 1. Prérequis

```bash
# Vérifier AWS CLI
aws --version

# Configurer AWS
aws configure

# Vérifier la configuration
aws sts get-caller-identity
```

### 2. Vérification Pré-Déploiement

```bash
./scripts/pre-deploy-check.sh
```

### 3. Déployer l'Infrastructure

```bash
./scripts/deploy.sh
```

Répondez aux questions:
- Key Pair: `todo-app-key`
- Email: `votre@email.com`

### 4. Configurer la Base de Données

```bash
./scripts/setup-database.sh
```

### 5. Déployer l'Application

```bash
./scripts/deploy-app.sh
```

### 6. Tester

```bash
source outputs.txt
curl http://$WEBSERVER_IP:3000/health
curl http://$WEBSERVER_IP:3000/api/todos
```

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
REACT_APP_API_URL=http://192.168.1.4:3000
```

## 📚 Documentation

- [Guide de Déploiement Complet](./DEPLOYMENT.md) - Instructions détaillées pour déployer l'application
- [Guide de Monitoring](./MONITORING.md) - Configuration et utilisation de CloudWatch
- [Guide CI/CD](./CICD.md) - Configuration et utilisation du pipeline GitHub Actions
- [Architecture AWS](./infrastructure/infrastructure.yml) - Template CloudFormation
- [Scripts de Déploiement](./scripts/) - Scripts automatisés

## 🔧 Configuration

### Variables d'Environnement Backend

```env
PORT=3000
NODE_ENV=production
DB_HOST=10.0.2.145
DB_PORT=5432
DB_NAME=tododb
DB_USER=todouser
DB_PASSWORD=SecurePassword123!
```

### Variables d'Environnement Frontend

```env
PORT=3001
REACT_APP_API_URL=http://192.168.1.4:3000
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

### Test de l'Infrastructure

```bash
./scripts/pre-deploy-check.sh
```

## 📊 Monitoring

### CloudWatch

#### Métriques Disponibles

- **CPU Utilization** - Utilisation CPU pour WebServer et Database
- **Network Traffic** - Trafic réseau entrant/sortant
- **Status Check** - Vérification de l'état des instances
- **Métriques personnalisées** (via CloudWatch Agent):
  - CPU détaillé (idle, iowait, user, system)
  - Utilisation mémoire (pourcentage)
  - Utilisation disque (pourcentage)

#### Alarmes Configurées

- `prod-webserver-high-cpu` - Alerte si CPU > 80% pendant 5 minutes
- `prod-webserver-status-check-failed` - Alerte si le status check échoue
- `prod-database-high-cpu` - Alerte si CPU > 80% pendant 5 minutes
- `prod-database-status-check-failed` - Alerte si le status check échoue

#### Dashboard CloudWatch

Un dashboard complet est disponible dans CloudWatch avec:
- Vue d'ensemble de l'utilisation CPU
- Graphiques de trafic réseau
- Statut des instances

**Accès**: Console AWS → CloudWatch → Dashboards → `prod-todo-app-dashboard`

#### Logs

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
- ✅ Base de données dans subnet privé
- ✅ IAM Roles avec permissions minimales
- ✅ HTTPS recommandé en production

## 🚀 CI/CD

Le pipeline GitHub Actions déploie automatiquement l'application complète.

### Pipeline GitHub Actions

Le workflow (`.github/workflows/deploy.yml`) comprend:

1. **Tests** - Exécution des tests backend
2. **Build** - Compilation de l'application
3. **Infrastructure** - Déploiement CloudFormation
4. **Base de données** - Initialisation PostgreSQL
5. **Application** - Déploiement sur EC2
6. **Health Check** - Vérification de l'API
7. **Notification** - Notification de succès/échec

### Déclenchement

Le pipeline se déclenche automatiquement sur:
- Push sur la branche `main`
- Pull Request vers `main`

### Secrets GitHub Requis

Configurez ces secrets dans GitHub (Settings → Secrets → Actions):

- `AWS_ACCESS_KEY_ID` - Clé d'accès AWS
- `AWS_SECRET_ACCESS_KEY` - Clé secrète AWS
- `EC2_KEY_PAIR_NAME` - Nom de la key pair EC2 (ex: `todo-app-key`)
- `EC2_SSH_PRIVATE_KEY` - Contenu de la clé privée SSH (.pem)
- `ALERT_EMAIL` - Email pour les alertes SNS
- `DB_PASSWORD` - Mot de passe de la base de données

### Déploiement Manuel

Pour déployer manuellement:

```bash
# 1. Déployer l'infrastructure
./scripts/deploy.sh

# 2. Configurer la base de données
./scripts/setup-database.sh

# 3. Déployer l'application
./scripts/deploy-app.sh
```

## 📝 API Endpoints

- `GET /` - Documentation API
- `GET /health` - Health check
- `GET /api/todos` - Liste des tâches
- `GET /api/todos/:id` - Détails d'une tâche
- `POST /api/todos` - Créer une tâche
- `PUT /api/todos/:id` - Modifier une tâche
- `DELETE /api/todos/:id` - Supprimer une tâche
- `GET /api/todos/stats` - Statistiques

## 🐛 Dépannage

Voir [DEPLOYMENT.md](./DEPLOYMENT.md) pour le guide de dépannage complet.

## 📄 Licence

MIT

## 👥 Auteur

juba

## 🙏 Remerciements

- AWS pour l'infrastructure
- React pour le frontend
- Express pour le backend
- PostgreSQL pour la base de données

