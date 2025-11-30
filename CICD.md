# 🚀 Guide CI/CD - Todo App AWS

Guide complet pour configurer et utiliser le pipeline CI/CD GitHub Actions.

## 📋 Vue d'Ensemble

Le pipeline CI/CD automatise:
- ✅ Tests de l'application
- ✅ Build de l'application
- ✅ Déploiement de l'infrastructure AWS
- ✅ Configuration de la base de données
- ✅ Déploiement de l'application
- ✅ Tests de santé (health checks)
- ✅ Notifications

## 🔧 Configuration Initiale

### 1. Secrets GitHub

Configurez les secrets suivants dans GitHub:

**Settings → Secrets and variables → Actions → New repository secret**

#### Secrets Requis

| Secret | Description | Exemple |
|--------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | Clé d'accès AWS | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `EC2_KEY_PAIR_NAME` | Nom de la key pair EC2 | `todo-app-key` |
| `EC2_SSH_PRIVATE_KEY` | Contenu du fichier .pem | Contenu complet du fichier |
| `ALERT_EMAIL` | Email pour alertes SNS | `admin@example.com` |
| `DB_PASSWORD` | Mot de passe PostgreSQL | `SecurePassword123!` |

### 2. Créer la Key Pair EC2

```bash
# Si vous n'avez pas encore de key pair
aws ec2 create-key-pair \
  --key-name todo-app-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/todo-app-key.pem

chmod 400 ~/.ssh/todo-app-key.pem
```

### 3. Ajouter la Clé Privée à GitHub

```bash
# Copier le contenu du fichier .pem
cat ~/.ssh/todo-app-key.pem

# Coller le contenu complet dans le secret EC2_SSH_PRIVATE_KEY
```

## 🔄 Workflow GitHub Actions

### Structure du Pipeline

```
┌─────────┐
│  Tests  │
└────┬────┘
     │
┌────▼────┐
│  Build  │
└────┬────┘
     │
┌────▼──────────────┐
│ Infrastructure    │
│ (CloudFormation)  │
└────┬──────────────┘
     │
┌────▼──────────────┐
│ Database Setup    │
│ (PostgreSQL)      │
└────┬──────────────┘
     │
┌────▼──────────────┐
│ Deploy App        │
│ (EC2)             │
└────┬──────────────┘
     │
┌────▼──────────────┐
│ Health Check      │
│ (API Tests)       │
└────┬──────────────┘
     │
┌────▼──────────────┐
│ Notification      │
└───────────────────┘
```

### Jobs Détaillés

#### 1. Tests (`test`)

- Exécute les tests backend
- Lint du code
- Continue même si les tests échouent (pour développement)

#### 2. Build (`build`)

- Installe les dépendances
- Build le frontend (React)
- Crée des artifacts pour le déploiement

#### 3. Infrastructure (`deploy-infrastructure`)

- Valide le template CloudFormation
- Déploie la stack CloudFormation
- Récupère les outputs (IPs des instances)

#### 4. Database Setup (`deploy-database`)

- Attend que les instances soient prêtes
- Copie le script SQL
- Initialise la base de données PostgreSQL

#### 5. Deploy Application (`deploy-application`)

- Crée le fichier `.env` avec les variables d'environnement
- Crée une archive de l'application
- Copie l'archive sur le serveur EC2
- Installe Node.js si nécessaire
- Installe les dépendances
- Démarre l'application

#### 6. Health Check (`health-check`)

- Attend le démarrage de l'application
- Teste l'endpoint `/health`
- Teste les endpoints API (`/api/todos`, `/api/todos/stats`)

#### 7. Notification (`notify`)

- Envoie une notification de succès ou d'échec
- Affiche l'URL de l'application

## 🚀 Déclenchement

### Déclenchement Automatique

Le pipeline se déclenche automatiquement sur:

- **Push sur `main`** - Déploiement complet
- **Pull Request vers `main`** - Tests uniquement (pas de déploiement)

### Déclenchement Manuel

1. Allez dans **Actions** → **CI/CD Pipeline**
2. Cliquez sur **Run workflow**
3. Sélectionnez la branche
4. Cliquez sur **Run workflow**

## 📊 Suivi du Pipeline

### Voir les Logs

1. Allez dans **Actions** dans votre repository GitHub
2. Cliquez sur le workflow en cours
3. Cliquez sur un job pour voir les logs détaillés

### Vérifier le Statut

- ✅ **Succès** - Tous les jobs sont verts
- ⚠️ **Avertissement** - Certains jobs ont des warnings
- ❌ **Échec** - Un ou plusieurs jobs ont échoué

## 🔍 Dépannage

### Erreur: "AWS credentials not configured"

**Solution**: Vérifiez que les secrets `AWS_ACCESS_KEY_ID` et `AWS_SECRET_ACCESS_KEY` sont configurés.

### Erreur: "Key pair does not exist"

**Solution**: 
1. Créez la key pair dans AWS
2. Mettez à jour le secret `EC2_KEY_PAIR_NAME`

### Erreur: "SSH connection failed"

**Solution**:
1. Vérifiez que le secret `EC2_SSH_PRIVATE_KEY` contient la clé complète
2. Vérifiez que l'instance EC2 est accessible
3. Vérifiez les Security Groups (port 22 ouvert)

### Erreur: "Database connection failed"

**Solution**:
1. Vérifiez que la base de données est initialisée
2. Vérifiez le mot de passe dans `DB_PASSWORD`
3. Vérifiez que le Security Group permet la connexion depuis le WebServer

### Erreur: "Application failed to start"

**Solution**:
1. Vérifiez les logs sur l'instance EC2
2. Vérifiez que Node.js est installé
3. Vérifiez que les variables d'environnement sont correctes

## 🔐 Sécurité

### Bonnes Pratiques

1. **Ne jamais commiter les secrets** dans le code
2. **Utiliser GitHub Secrets** pour toutes les informations sensibles
3. **Restreindre les permissions IAM** au minimum nécessaire
4. **Utiliser des key pairs différentes** pour chaque environnement
5. **Roter les secrets régulièrement**

### Permissions IAM Minimales

Le rôle IAM utilisé par GitHub Actions doit avoir:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "ec2:Describe*",
        "ec2:GetConsoleOutput",
        "logs:*",
        "sns:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🎯 Personnalisation

### Modifier le Workflow

Éditez le fichier `.github/workflows/deploy.yml` pour:
- Ajouter des tests supplémentaires
- Modifier les seuils de health check
- Ajouter des notifications (Slack, Discord, etc.)
- Déployer sur plusieurs environnements

### Ajouter des Notifications

Exemple pour Slack:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment completed'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 📚 Ressources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS CloudFormation](https://docs.aws.amazon.com/cloudformation/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/)

