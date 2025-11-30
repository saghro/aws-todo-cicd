# ⚡ Solution Rapide : Clé SSH Tronquée

## Erreur
```
❌ ERREUR: La clé SSH ne contient pas l'en-tête END
```

## Cause
La clé SSH dans GitHub Secrets est **tronquée** - la fin de la clé (ligne `-----END RSA PRIVATE KEY-----`) est manquante.

## Solution en 3 étapes

### 1️⃣ Générer le fichier complet

```bash
./scripts/generate-ssh-secret.sh ~/.ssh/todo-app-key.pem
```

Cela crée un fichier `github-ssh-secret.txt` avec le contenu complet.

### 2️⃣ Vérifier que le fichier est complet

```bash
# Vérifier la dernière ligne
tail -1 github-ssh-secret.txt
```

**Doit afficher :**
```
-----END RSA PRIVATE KEY-----
```

Si ce n'est pas le cas, la clé est toujours tronquée.

### 3️⃣ Mettre à jour le secret GitHub

1. **Ouvrez le fichier :**
   ```bash
   open github-ssh-secret.txt
   # ou
   cat github-ssh-secret.txt
   ```

2. **Sélectionnez TOUT le contenu :**
   - Cmd+A (Mac) ou Ctrl+A (Windows/Linux)
   - Vérifiez visuellement que la dernière ligne est `-----END RSA PRIVATE KEY-----`

3. **Copiez tout :**
   - Cmd+C (Mac) ou Ctrl+C (Windows/Linux)

4. **Dans GitHub :**
   - Allez dans : **Settings → Secrets and variables → Actions**
   - Cliquez sur **EC2_SSH_PRIVATE_KEY** (ou créez-le s'il n'existe pas)
   - **Supprimez TOUT l'ancien contenu**
   - **Collez le nouveau contenu complet**
   - **Vérifiez que la dernière ligne visible est `-----END RSA PRIVATE KEY-----`**
   - Cliquez sur **Update secret** (ou **Add secret**)

5. **Relancez le workflow GitHub Actions**

## Vérification

Après avoir mis à jour le secret, le workflow devrait afficher :
```
✅ Clé SSH valide:
2048 SHA256:... (RSA)
```

## Format correct

La clé complète doit ressembler à ceci :

```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
[plusieurs lignes de contenu, généralement 25-30 lignes]
...
-----END RSA PRIVATE KEY-----
```

**Important :**
- ✅ Commence par `-----BEGIN RSA PRIVATE KEY-----`
- ✅ Se termine par `-----END RSA PRIVATE KEY-----`
- ✅ Fait environ 1700-1800 octets
- ✅ A environ 25-30 lignes

## Si le problème persiste

1. **Vérifiez que vous avez la bonne clé :**
   ```bash
   ssh-keygen -l -f ~/.ssh/todo-app-key.pem
   ```

2. **Vérifiez que la Key Pair existe dans AWS :**
   ```bash
   aws ec2 describe-key-pairs --key-names todo-app-key --region us-east-1
   ```

3. **Regénérez le fichier et réessayez :**
   ```bash
   ./scripts/generate-ssh-secret.sh ~/.ssh/todo-app-key.pem
   ```

## Aide supplémentaire

- `CONFIGURER_SSH_SECRET.md` : Guide complet de configuration
- `TROUBLESHOOTING_SSH.md` : Guide de dépannage détaillé

