# 🔧 Dépannage - Erreur CloudFormation ResourceExistenceCheck

## Problème

Erreur lors du déploiement CloudFormation :
```
Failed to create the changeset: Waiter ChangeSetCreateComplete failed
Reason: The following hook(s)/validation failed: [AWS::EarlyValidation::ResourceExistenceCheck]
```

## Causes Possibles

Cette erreur signifie qu'une ressource référencée dans le template CloudFormation n'existe pas dans votre compte AWS. Les causes les plus courantes :

1. **Key Pair n'existe pas** dans la région spécifiée
2. **Nom de la Key Pair incorrect** dans le secret GitHub
3. **Région incorrecte** (Key Pair dans une région, déploiement dans une autre)
4. **Permissions IAM insuffisantes**

## Solutions Étape par Étape

### Étape 1: Vérifier la Key Pair

```bash
# Vérifier que la Key Pair existe
./scripts/check-keypair.sh todo-app-key us-east-1

# Ou manuellement
aws ec2 describe-key-pairs --key-names todo-app-key --region us-east-1
```

**Résultat attendu**: La Key Pair doit exister et être affichée.

### Étape 2: Vérifier le Secret GitHub

Le secret `EC2_KEY_PAIR_NAME` dans GitHub doit contenir **exactement** le nom de la Key Pair :

1. Allez dans GitHub → Settings → Secrets and variables → Actions
2. Vérifiez le secret `EC2_KEY_PAIR_NAME`
3. Il doit contenir exactement : `todo-app-key` (sans espaces, respecter la casse)

**⚠️ Erreurs courantes** :
- Espaces avant/après : ` todo-app-key ` ❌
- Casse incorrecte : `Todo-App-Key` ❌
- Nom différent : `my-key` ❌

### Étape 3: Vérifier la Région

La Key Pair doit être dans la **même région** que le déploiement :

```bash
# Vérifier la région configurée
aws configure get region

# Vérifier la région dans le workflow
# (.github/workflows/deploy.yml, ligne 13: AWS_REGION: us-east-1)
```

**Important**: Si votre Key Pair est dans `eu-north-1` mais le workflow déploie dans `us-east-1`, cela échouera.

### Étape 4: Obtenir Plus de Détails

Utilisez le script de débogage pour obtenir plus d'informations :

```bash
./scripts/debug-cloudformation-error.sh
```

Ce script affiche :
- Les événements récents de la stack
- Les détails des changementsets en échec
- La liste des Key Pairs disponibles
- Des suggestions de résolution

### Étape 5: Vérifier les Permissions IAM

Votre utilisateur AWS doit avoir les permissions pour :
- `ec2:DescribeKeyPairs`
- `ec2:CreateKeyPair` (si vous créez une nouvelle Key Pair)
- `cloudformation:*`

Vérifiez avec :
```bash
aws sts get-caller-identity
aws iam get-user
```

## Solutions Spécifiques

### Solution 1: Créer la Key Pair dans la Bonne Région

Si la Key Pair n'existe pas dans la région du déploiement :

```bash
# Créer la Key Pair dans us-east-1
aws ec2 create-key-pair \
  --key-name todo-app-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/todo-app-key.pem

chmod 400 ~/.ssh/todo-app-key.pem
```

### Solution 2: Utiliser une Key Pair Existante

Si vous avez une Key Pair dans une autre région, créez-en une nouvelle dans la région du déploiement, ou changez la région du workflow.

### Solution 3: Vérifier le Secret GitHub

1. Allez dans GitHub → Settings → Secrets
2. Vérifiez que `EC2_KEY_PAIR_NAME` contient exactement le nom de la Key Pair
3. Pas d'espaces, pas de caractères spéciaux, respecter la casse

### Solution 4: Tester le Déploiement Manuellement

Testez le déploiement manuellement pour voir l'erreur complète :

```bash
aws cloudformation create-stack \
  --stack-name todo-app-stack-test \
  --template-body file://infrastructure/infrastructure.yml \
  --parameters \
    ParameterKey=EnvironmentName,ParameterValue=prod \
    ParameterKey=KeyPairName,ParameterValue=todo-app-key \
    ParameterKey=AlertEmail,ParameterValue=your@email.com \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

## Checklist de Vérification

- [ ] La Key Pair existe dans AWS (`aws ec2 describe-key-pairs`)
- [ ] La Key Pair est dans la bonne région (us-east-1)
- [ ] Le secret GitHub `EC2_KEY_PAIR_NAME` contient exactement le nom de la Key Pair
- [ ] Pas d'espaces dans le secret GitHub
- [ ] La casse correspond exactement
- [ ] Les permissions IAM sont correctes
- [ ] L'AMI ID existe dans la région (vérifié avec `./scripts/check-ami.sh`)

## Commandes Utiles

```bash
# Vérifier toutes les Key Pairs dans une région
aws ec2 describe-key-pairs --region us-east-1

# Vérifier les événements CloudFormation
aws cloudformation describe-stack-events \
  --stack-name todo-app-stack \
  --region us-east-1 \
  --max-items 10

# Vérifier les changementsets en échec
aws cloudformation list-change-sets \
  --stack-name todo-app-stack \
  --region us-east-1

# Obtenir les détails d'un changeset
aws cloudformation describe-change-set \
  --change-set-name <CHANGESET_ID> \
  --stack-name todo-app-stack \
  --region us-east-1
```

## Après Correction

Une fois le problème résolu :

1. ✅ Vérifiez que la Key Pair existe dans la bonne région
2. ✅ Vérifiez que le secret GitHub est correct
3. ✅ Commitez et poussez les changements
4. ✅ Relancez le pipeline GitHub Actions

Le workflow amélioré affichera maintenant plus de détails en cas d'erreur, ce qui facilitera le diagnostic.

