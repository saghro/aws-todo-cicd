# 🔧 Dépannage SSH - GitHub Actions

## Problème: Erreur de connexion SSH lors du déploiement

### Symptômes
```
Load key "/home/runner/.ssh/id_rsa": error in libcrypto
Permission denied (publickey,gssapi-keyex,gssapi-with-mic)
scp: Connection closed
```

### Causes possibles

1. **Clé SSH mal formatée dans GitHub Secrets**
   - La clé privée doit être au format PEM complet
   - Doit inclure les en-têtes `-----BEGIN RSA PRIVATE KEY-----` et `-----END RSA PRIVATE KEY-----`
   - Les retours à la ligne doivent être préservés

2. **Secret GitHub non configuré**
   - Le secret `EC2_SSH_PRIVATE_KEY` n'existe pas dans GitHub
   - Le secret est vide ou mal configuré

3. **Instance EC2 pas encore prête**
   - L'instance est en cours de démarrage
   - Le service SSH n'est pas encore démarré
   - Le UserData est encore en cours d'exécution

4. **Security Group bloque SSH**
   - Le Security Group n'autorise pas les connexions SSH depuis GitHub Actions
   - Les IPs de GitHub Actions changent régulièrement

## Solutions

### 1. Vérifier et configurer la clé SSH dans GitHub Secrets

```bash
# Sur votre machine locale, afficher la clé privée
cat ~/.ssh/todo-app-key.pem

# Copier TOUTE la clé, y compris les en-têtes:
# -----BEGIN RSA PRIVATE KEY-----
# [contenu de la clé]
# -----END RSA PRIVATE KEY-----
```

**Dans GitHub:**
1. Allez dans Settings → Secrets and variables → Actions
2. Vérifiez ou créez le secret `EC2_SSH_PRIVATE_KEY`
3. Collez la clé complète (avec les en-têtes et tous les retours à la ligne)
4. Sauvegardez

### 2. Vérifier que la Key Pair existe dans AWS

```bash
aws ec2 describe-key-pairs --key-names todo-app-key --region us-east-1
```

Si elle n'existe pas:
```bash
# Créer une nouvelle Key Pair
aws ec2 create-key-pair \
  --key-name todo-app-key \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/todo-app-key.pem

chmod 400 ~/.ssh/todo-app-key.pem
```

### 3. Vérifier le Security Group

Le Security Group du WebServer doit autoriser les connexions SSH (port 22) depuis:
- `0.0.0.0/0` (pour GitHub Actions - moins sécurisé mais fonctionnel)
- Ou les plages d'IPs de GitHub Actions (plus sécurisé)

```bash
# Vérifier les règles du Security Group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=prod-webserver-sg" \
  --region us-east-1 \
  --query "SecurityGroups[0].IpPermissions"
```

### 4. Vérifier que l'instance est prête

```bash
# Vérifier l'état de l'instance
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=prod-webserver" \
  --region us-east-1 \
  --query "Reservations[0].Instances[0].[State.Name,PublicIpAddress]"

# Tester la connexion SSH manuellement
ssh -i ~/.ssh/todo-app-key.pem ec2-user@<WEBSERVER_IP>
```

### 5. Vérifier les logs CloudFormation

Si l'instance est créée mais SSH ne fonctionne pas:
- Vérifiez les logs CloudFormation pour voir si le UserData s'est exécuté correctement
- Vérifiez les logs système de l'instance EC2 dans CloudWatch Logs

## Test de la clé SSH localement

```bash
# Tester que la clé est valide
ssh-keygen -l -f ~/.ssh/todo-app-key.pem

# Tester la connexion
ssh -i ~/.ssh/todo-app-key.pem ec2-user@<WEBSERVER_IP>
```

## Format correct de la clé SSH dans GitHub Secrets

La clé doit ressembler à ceci (exemple):
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
[plusieurs lignes de contenu]
...
-----END RSA PRIVATE KEY-----
```

**Important:**
- Inclure les en-têtes `-----BEGIN` et `-----END`
- Préserver tous les retours à la ligne
- Ne pas ajouter d'espaces supplémentaires
- La clé complète doit être sur une seule valeur de secret (pas de sauts de ligne dans l'interface GitHub)

## Vérification dans le workflow

Le workflow vérifie maintenant automatiquement:
- ✅ Que la clé SSH est valide (format correct)
- ✅ Que l'instance est prête avant de tenter la connexion
- ✅ Affiche des messages d'erreur détaillés en cas d'échec

Si le problème persiste, vérifiez les logs du workflow GitHub Actions pour plus de détails.

