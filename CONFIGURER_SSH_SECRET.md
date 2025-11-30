# 🔑 Configuration du Secret SSH dans GitHub

## Problème
Le workflow GitHub Actions échoue avec l'erreur :
```
❌ ERREUR: La clé SSH n'est pas valide
Vérifiez que le secret EC2_SSH_PRIVATE_KEY contient la clé privée complète au format PEM
```

## Solution : Configurer correctement le secret GitHub

### Étape 1 : Obtenir le contenu de votre clé SSH

Sur votre machine locale, exécutez :

```bash
./scripts/check-ssh-key.sh ~/.ssh/todo-app-key.pem
```

Ce script va :
- ✅ Vérifier que la clé existe et est valide
- ✅ Afficher le contenu complet à copier dans GitHub
- ✅ Vérifier que la Key Pair existe dans AWS

### Étape 2 : Copier le contenu de la clé

Le script affichera quelque chose comme :

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
[plusieurs lignes de contenu]
...
-----END RSA PRIVATE KEY-----
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Important :** Copiez TOUT le contenu entre les lignes de séparation, y compris :
- La ligne `-----BEGIN RSA PRIVATE KEY-----`
- Toutes les lignes de contenu au milieu
- La ligne `-----END RSA PRIVATE KEY-----`

### Étape 3 : Configurer le secret dans GitHub

1. **Allez dans votre repository GitHub**
2. **Cliquez sur Settings** (en haut à droite)
3. **Dans le menu de gauche, cliquez sur : Secrets and variables → Actions**
4. **Cliquez sur "New repository secret"** (ou modifiez l'existant si `EC2_SSH_PRIVATE_KEY` existe déjà)
5. **Remplissez le formulaire :**
   - **Name:** `EC2_SSH_PRIVATE_KEY`
   - **Secret:** Collez le contenu complet de la clé (tout ce qui est entre les lignes de séparation)
6. **Cliquez sur "Add secret"** (ou "Update secret")

### Étape 4 : Vérifier le format

Le secret doit contenir exactement :

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
[contenu de la clé sur plusieurs lignes]
...
-----END RSA PRIVATE KEY-----
```

**Points critiques :**
- ✅ Les en-têtes `-----BEGIN` et `-----END` doivent être présents
- ✅ Tous les retours à la ligne doivent être préservés
- ✅ Aucun espace supplémentaire au début ou à la fin
- ✅ La clé complète (pas tronquée)

### Étape 5 : Relancer le workflow

Après avoir configuré le secret, relancez le workflow GitHub Actions. Il devrait maintenant :
- ✅ Valider la clé SSH
- ✅ Se connecter aux instances EC2
- ✅ Déployer l'application

## Vérification manuelle

Si vous voulez vérifier que votre clé est correcte avant de la mettre dans GitHub :

```bash
# Vérifier le format
ssh-keygen -l -f ~/.ssh/todo-app-key.pem

# Devrait afficher quelque chose comme :
# 2048 SHA256:... todo-app-key (RSA)
```

## Format de clé accepté

Le workflow accepte les formats suivants :
- **RSA PRIVATE KEY** : `-----BEGIN RSA PRIVATE KEY-----`
- **OPENSSH PRIVATE KEY** : `-----BEGIN OPENSSH PRIVATE KEY-----`

## Si vous n'avez pas de clé SSH

Si vous n'avez pas encore de clé SSH pour ce projet :

```bash
# Créer une nouvelle Key Pair dans AWS
aws ec2 create-key-pair \
  --key-name todo-app-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/todo-app-key.pem

# Définir les permissions correctes
chmod 400 ~/.ssh/todo-app-key.pem

# Vérifier la clé
./scripts/check-ssh-key.sh ~/.ssh/todo-app-key.pem
```

## Dépannage

### Erreur : "Le secret EC2_SSH_PRIVATE_KEY n'est pas configuré"
→ Le secret n'existe pas dans GitHub. Créez-le en suivant l'Étape 3.

### Erreur : "La clé SSH ne contient pas l'en-tête BEGIN"
→ Vous n'avez pas copié les en-têtes. Copiez TOUTE la clé, y compris `-----BEGIN` et `-----END`.

### Erreur : "La clé SSH n'est pas valide"
→ La clé est peut-être tronquée ou mal formatée. Utilisez `./scripts/check-ssh-key.sh` pour obtenir le contenu exact.

### Erreur : "Permission denied" lors de la connexion
→ La clé est valide mais ne correspond pas à la Key Pair de l'instance EC2. Vérifiez que vous utilisez la bonne clé.

## Aide supplémentaire

Pour plus de détails sur le dépannage SSH, consultez :
- `TROUBLESHOOTING_SSH.md` : Guide complet de dépannage SSH
- `scripts/check-ssh-key.sh` : Script de vérification de clé

