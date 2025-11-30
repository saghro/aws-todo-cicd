# 🚀 Guide de Déploiement - Todo App AWS

Guide complet pour déployer l'application Todo sur AWS avec EC2, PostgreSQL, CloudWatch et CI/CD.

## 📋 Prérequis

- ✅ AWS CLI installé et configuré
- ✅ Compte AWS avec permissions appropriées
- ✅ Key Pair EC2 créée (`todo-app-key`)
- ✅ Template CloudFormation validé
- ✅ Tous les scripts présents et exécutables

## 🔍 Étape 0: Vérification Pré-Déploiement

Avant de commencer, exécutez le script de vérification:

```bash
./scripts/pre-deploy-check.sh
```

Ce script vérifie:
- ✅ AWS CLI installé et configuré
- ✅ Tous les fichiers nécessaires présents
- ✅ Permissions des scripts correctes
- ✅ Template CloudFormation valide
- ✅ AMI ID correctement configuré
- ✅ Clé SSH disponible

## 🏗️ Étape 1: Déployer l'Infrastructure (10-15 min)

### 1.1 Lancer le déploiement

```bash
./scripts/deploy.sh
```

### 1.2 Répondre aux questions

Le script vous demandera:

1. **Nom de la Key Pair EC2**: `todo-app-key`
2. **Email pour les alertes SNS**: `votre@email.com`

### 1.3 Attendre le déploiement

Le déploiement prend environ 10-15 minutes. CloudFormation crée:

- ✅ VPC avec subnets public et privé
- ✅ Internet Gateway et Route Tables
- ✅ Security Groups
- ✅ IAM Roles pour CloudWatch
- ✅ 2 instances EC2 (WebServer + Database)
- ✅ CloudWatch Alarms
- ✅ SNS Topic pour les alertes

### 1.4 Noter les informations

À la fin, le script affiche:

```
📊 Informations de l'infrastructure:
  • WebServer IP:  54.123.45.67
  • WebServer DNS: ec2-54-123-45-67.compute-1.amazonaws.com
  • Database IP:   10.0.2.145
```

**⚠️ IMPORTANT**: Notez ces informations, elles sont aussi sauvegardées dans `outputs.txt`

### 1.5 Confirmer l'abonnement SNS

1. Vérifiez votre boîte email
2. Cherchez l'email de "AWS Notifications"
3. Cliquez sur "Confirm subscription"
4. ✅ Page de confirmation affichée

## 🗄️ Étape 2: Configurer la Base de Données (5 min)

### 2.1 Lancer la configuration

```bash
./scripts/setup-database.sh
```

### 2.2 Entrer le mot de passe

Le script vous demandera le mot de passe pour l'utilisateur PostgreSQL `todouser`.

**Recommandation**: Utilisez un mot de passe fort (ex: `SecurePassword123!`)

### 2.3 Vérification

Le script:
- ✅ Configure PostgreSQL pour accepter les connexions
- ✅ Crée la base de données `tododb`
- ✅ Crée l'utilisateur `todouser`
- ✅ Crée la table `todos`
- ✅ Insère des données de test

## 📦 Étape 3: Déployer l'Application (5 min)

### 3.1 Préparer le backend

Assurez-vous que le fichier `backend/.env` n'existe pas localement (il sera créé automatiquement).

### 3.2 Lancer le déploiement

```bash
./scripts/deploy-app.sh
```

### 3.3 Entrer le mot de passe de la base de données

Entrez le même mot de passe que celui utilisé à l'étape 2.

### 3.4 Vérification

Le script:
- ✅ Crée le fichier `.env` avec les bonnes variables
- ✅ Crée une archive de l'application
- ✅ Copie l'application sur le serveur EC2
- ✅ Installe les dépendances
- ✅ Démarre l'application

## 🧪 Étape 4: Tester l'Application

### 4.1 Tester l'API

```bash
# Récupérer l'IP du serveur depuis outputs.txt
source outputs.txt

# Test health check
curl http://$WEBSERVER_IP:3000/health

# Test liste des todos
curl http://$WEBSERVER_IP:3000/api/todos
```

### 4.2 Accéder au frontend

Si vous avez déployé le frontend, accédez à:

```
http://$WEBSERVER_IP:3001
```

## 📊 Étape 5: Vérifier dans la Console AWS

### 5.1 CloudFormation

1. Allez sur [AWS Console → CloudFormation](https://console.aws.amazon.com/cloudformation)
2. Vérifiez que la stack `todo-app-stack` est en `CREATE_COMPLETE` ✅

### 5.2 EC2 Instances

1. Allez sur [AWS Console → EC2 → Instances](https://console.aws.amazon.com/ec2)
2. Vérifiez que 2 instances sont en cours d'exécution:
   - `prod-webserver` (IP publique visible)
   - `prod-database` (IP privée uniquement)

### 5.3 CloudWatch

1. Allez sur [AWS Console → CloudWatch](https://console.aws.amazon.com/cloudwatch)
2. **Dashboard**:
   - Cliquez sur "Dashboards" dans le menu de gauche
   - Ouvrez `prod-todo-app-dashboard`
   - Vérifiez les métriques CPU, réseau et status check
3. **Alarmes**:
   - Cliquez sur "Alarms" dans le menu de gauche
   - Vérifiez que les alarmes suivantes sont en état "OK":
     - `prod-webserver-high-cpu`
     - `prod-webserver-status-check-failed`
     - `prod-database-high-cpu`
     - `prod-database-status-check-failed`
4. **Logs**:
   - Cliquez sur "Log groups" dans le menu de gauche
   - Vérifiez le log group `/aws/ec2/todo-app/webserver`
   - Les logs de l'application y sont collectés automatiquement

## 🔧 Commandes Utiles

### Se connecter au WebServer

```bash
source outputs.txt
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$WEBSERVER_IP
```

### Se connecter à la Database

```bash
source outputs.txt
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$DATABASE_IP
```

### Voir les logs de l'application

```bash
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$WEBSERVER_IP
tail -f ~/app/app.log
```

### Redémarrer l'application

```bash
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$WEBSERVER_IP
cd ~/app
pkill -f "node server.js"
nohup node server.js > app.log 2>&1 &
```

### Vérifier PostgreSQL

```bash
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$DATABASE_IP
sudo -u postgres psql -d tododb
```

## 🐛 Dépannage

### Erreur: "Key pair does not exist"

```bash
# Vérifier dans AWS
aws ec2 describe-key-pairs --key-names todo-app-key

# Si elle n'existe pas, créez-la dans la console AWS:
# EC2 → Key Pairs → Create Key Pair
```

### Erreur: "Stack stuck in CREATE_IN_PROGRESS"

```bash
# Voir les événements récents
aws cloudformation describe-stack-events \
  --stack-name todo-app-stack \
  --max-items 10

# Voir les logs en temps réel
watch -n 5 'aws cloudformation describe-stack-events \
  --stack-name todo-app-stack \
  --max-items 5'
```

### L'application ne répond pas

```bash
# Vérifier que l'application tourne
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$WEBSERVER_IP
ps aux | grep "node server.js"

# Voir les logs
tail -f ~/app/app.log

# Vérifier les ports
sudo netstat -tlnp | grep 3000
```

### Problème de connexion à la base de données

```bash
# Vérifier que PostgreSQL écoute
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$DATABASE_IP
sudo systemctl status postgresql

# Vérifier les connexions
sudo -u postgres psql -d tododb -c "SELECT COUNT(*) FROM todos;"
```

## 📝 Checklist de Déploiement

### Infrastructure
- [ ] Prérequis vérifiés (`./scripts/pre-deploy-check.sh`)
- [ ] Infrastructure déployée (`./scripts/deploy.sh`)
- [ ] Email SNS confirmé
- [ ] Base de données configurée (`./scripts/setup-database.sh`)
- [ ] Application déployée (`./scripts/deploy-app.sh`)

### Tests
- [ ] API testée et fonctionnelle (`curl http://$WEBSERVER_IP:3000/health`)
- [ ] Endpoints API testés (`/api/todos`, `/api/todos/stats`)

### Monitoring
- [ ] CloudWatch Dashboard accessible
- [ ] Alarmes CloudWatch actives et en état "OK"
- [ ] Logs CloudWatch collectés (`/aws/ec2/todo-app/webserver`)
- [ ] CloudWatch Agent configuré sur WebServer

### CI/CD (Optionnel)
- [ ] Secrets GitHub configurés
- [ ] Workflow GitHub Actions testé
- [ ] Pipeline CI/CD fonctionnel

## 🎉 Félicitations!

Votre application Todo est maintenant déployée sur AWS avec:

- ✅ Infrastructure complète (VPC, EC2, Security Groups, NAT Gateway)
- ✅ Base de données PostgreSQL sécurisée dans subnet privé
- ✅ Application backend déployée et fonctionnelle
- ✅ Monitoring complet avec CloudWatch (Dashboard, Alarmes, Logs)
- ✅ Alertes SNS configurées (CPU, Status Check)
- ✅ CI/CD automatisé avec GitHub Actions
- ✅ CloudWatch Agent configuré pour métriques personnalisées

## 📊 Accès aux Ressources

### Application
- **API**: `http://$WEBSERVER_IP:3000`
- **Health Check**: `http://$WEBSERVER_IP:3000/health`
- **API Docs**: `http://$WEBSERVER_IP:3000/`

### Monitoring
- **CloudWatch Dashboard**: Console AWS → CloudWatch → Dashboards → `prod-todo-app-dashboard`
- **CloudWatch Logs**: Console AWS → CloudWatch → Logs → `/aws/ec2/todo-app/webserver`
- **CloudWatch Alarmes**: Console AWS → CloudWatch → Alarmes

### Infrastructure
- **CloudFormation Stack**: Console AWS → CloudFormation → `todo-app-stack`
- **EC2 Instances**: Console AWS → EC2 → Instances
- **VPC**: Console AWS → VPC → Your VPCs

## 📚 Ressources

- [Documentation AWS CloudFormation](https://docs.aws.amazon.com/cloudformation/)
- [Documentation AWS EC2](https://docs.aws.amazon.com/ec2/)
- [Documentation PostgreSQL](https://www.postgresql.org/docs/)

