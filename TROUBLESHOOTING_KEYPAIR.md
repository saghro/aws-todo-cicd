# 🔧 Dépannage - Erreur Key Pair CloudFormation

## Problème

Erreur CloudFormation lors du déploiement :
```
Failed to create the changeset: Waiter ChangeSetCreateComplete failed
Reason: The following hook(s)/validation failed: [AWS::EarlyValidation::ResourceExistenceCheck]
```

## Cause

Cette erreur signifie qu'une ressource référencée dans le template CloudFormation n'existe pas dans votre compte AWS. Dans ce cas, c'est probablement la **Key Pair EC2** qui n'existe pas.

## Solutions

### Solution 1: Vérifier la Key Pair (Recommandé)

Utilisez le script de vérification :

```bash
./scripts/check-keypair.sh [KEY_NAME] [REGION]
```

Exemples :
```bash
# Avec les valeurs par défaut (todo-app-key, us-east-1)
./scripts/check-keypair.sh

# Avec des valeurs personnalisées
./scripts/check-keypair.sh my-key-pair eu-north-1
```

Le script :
- ✅ Vérifie si la Key Pair existe
- ✅ Propose de la créer si elle n'existe pas
- ✅ Affiche le fingerprint si elle existe

### Solution 2: Vérifier via AWS CLI

#### Vérifier la région configurée
```bash
aws configure get region
```

#### Vérifier si la Key Pair existe
```bash
# Remplacer todo-app-key par votre nom de Key Pair
# Remplacer us-east-1 par votre région
aws ec2 describe-key-pairs \
  --key-names todo-app-key \
  --region us-east-1
```

Si la commande réussit, la Key Pair existe. Si elle échoue avec "InvalidKeyPair.NotFound", la Key Pair n'existe pas.

### Solution 3: Créer la Key Pair

#### Option A: Via la Console AWS

1. Allez dans [EC2 → Key Pairs](https://console.aws.amazon.com/ec2/home#KeyPairs:)
2. Cliquez sur "Create key pair"
3. Nommez-la (ex: `todo-app-key`)
4. Choisissez le type (RSA recommandé)
5. Téléchargez le fichier `.pem`
6. Sauvegardez-le en lieu sûr (ex: `~/.ssh/todo-app-key.pem`)
7. Définissez les permissions : `chmod 400 ~/.ssh/todo-app-key.pem`

#### Option B: Via AWS CLI

```bash
# Créer la Key Pair
aws ec2 create-key-pair \
  --key-name todo-app-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/todo-app-key.pem

# Définir les permissions
chmod 400 ~/.ssh/todo-app-key.pem
```

**⚠️ IMPORTANT**: Sauvegardez le fichier `.pem` ! Vous ne pourrez plus le télécharger après.

### Solution 4: Vérifier le Secret GitHub

Assurez-vous que le secret `EC2_KEY_PAIR_NAME` dans GitHub Actions correspond exactement au nom de la Key Pair dans AWS :

1. Allez dans votre repository GitHub
2. Settings → Secrets and variables → Actions
3. Vérifiez que `EC2_KEY_PAIR_NAME` contient exactement le nom de la Key Pair (sans espaces, respecter la casse)

### Solution 5: Vérifier la Région

**Important**: La Key Pair doit être dans la **même région** que votre stack CloudFormation.

1. Vérifiez la région de votre stack dans le workflow (variable `AWS_REGION`)
2. Vérifiez que la Key Pair existe dans cette région
3. Si nécessaire, créez la Key Pair dans la bonne région

## Vérification Complète

### Checklist

- [ ] La région AWS est correcte (`aws configure get region`)
- [ ] La Key Pair existe dans cette région
- [ ] Le nom de la Key Pair correspond exactement au secret GitHub
- [ ] Le fichier `.pem` est sauvegardé en lieu sûr
- [ ] Les permissions du fichier sont correctes (`chmod 400`)

### Commandes de Vérification

```bash
# 1. Vérifier la région
aws configure get region

# 2. Lister toutes les Key Pairs dans la région
aws ec2 describe-key-pairs --region us-east-1

# 3. Vérifier une Key Pair spécifique
aws ec2 describe-key-pairs \
  --key-names todo-app-key \
  --region us-east-1

# 4. Vérifier la stack CloudFormation
aws cloudformation describe-stacks \
  --stack-name todo-app-stack \
  --region us-east-1
```

## Régions Courantes

- **us-east-1** - N. Virginia (par défaut)
- **eu-north-1** - Stockholm
- **eu-west-1** - Ireland
- **ap-southeast-1** - Singapore

**Important**: Les Key Pairs sont spécifiques à une région. Si vous changez de région, vous devez créer une nouvelle Key Pair.

## Après la Création

Une fois la Key Pair créée :

1. ✅ Vérifiez qu'elle existe : `aws ec2 describe-key-pairs --key-names todo-app-key --region us-east-1`
2. ✅ Vérifiez que le secret GitHub correspond
3. ✅ Relancez le pipeline GitHub Actions

## Support

Si le problème persiste après ces étapes :

1. Vérifiez les logs CloudFormation détaillés :
```bash
aws cloudformation describe-stack-events \
  --stack-name todo-app-stack \
  --region us-east-1 \
  --max-items 10
```

2. Vérifiez les permissions IAM de votre utilisateur AWS
3. Vérifiez que vous avez les permissions pour créer des Key Pairs

