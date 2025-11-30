# 🔧 Dépannage - Alarmes CloudWatch Manquantes

## Problème

Les alarmes CloudWatch n'apparaissent pas dans la console AWS.

## Causes Possibles

1. **Région différente** - La console est dans une région différente de celle du déploiement
2. **Stack déployée avant les alarmes** - La stack a été créée avant l'ajout des alarmes au template
3. **Alarmes non créées** - Les alarmes n'ont pas été créées lors du déploiement

## Solutions

### Solution 1: Vérifier la Région

1. Vérifiez dans quelle région votre stack est déployée:
```bash
aws cloudformation describe-stacks \
  --stack-name todo-app-stack \
  --query "Stacks[0].StackId" \
  --output text
```

2. Assurez-vous que la console CloudWatch est dans la même région:
   - En haut à droite de la console, vérifiez la région
   - Changez-la si nécessaire pour correspondre à votre stack

### Solution 2: Créer les Alarmes Manuellement

Utilisez le script `check-alarms.sh` pour créer les alarmes manquantes:

```bash
./scripts/check-alarms.sh
```

Ce script:
- ✅ Vérifie que la stack existe
- ✅ Récupère les IDs des instances
- ✅ Récupère l'ARN du topic SNS
- ✅ Crée les 4 alarmes manquantes:
  - `prod-webserver-high-cpu`
  - `prod-webserver-status-check-failed`
  - `prod-database-high-cpu`
  - `prod-database-status-check-failed`

### Solution 3: Mettre à Jour la Stack

Si vous préférez mettre à jour la stack CloudFormation complète:

```bash
./scripts/update-stack-alarms.sh
```

Ce script:
- ✅ Récupère les paramètres existants de la stack
- ✅ Met à jour la stack avec le template complet (incluant les alarmes)
- ✅ Attend la fin de la mise à jour
- ✅ Affiche les alarmes créées

### Solution 4: Vérifier via AWS CLI

Vérifiez si les alarmes existent dans votre région:

```bash
# Remplacer us-east-1 par votre région
aws cloudwatch describe-alarms \
  --alarm-name-prefix prod- \
  --region us-east-1 \
  --query "MetricAlarms[*].[AlarmName,StateValue]" \
  --output table
```

## Vérification

Après avoir créé les alarmes, vérifiez dans la console:

1. Allez dans **CloudWatch** → **Alarms**
2. Assurez-vous d'être dans la bonne région
3. Vous devriez voir 4 alarmes:
   - `prod-webserver-high-cpu` (état: OK)
   - `prod-webserver-status-check-failed` (état: OK)
   - `prod-database-high-cpu` (état: OK)
   - `prod-database-status-check-failed` (état: OK)

## Commandes Utiles

### Lister toutes les alarmes
```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix prod- \
  --region us-east-1
```

### Vérifier une alerte spécifique
```bash
aws cloudwatch describe-alarms \
  --alarm-names prod-webserver-high-cpu \
  --region us-east-1
```

### Supprimer une alerte (si nécessaire)
```bash
aws cloudwatch delete-alarms \
  --alarm-names prod-webserver-high-cpu \
  --region us-east-1
```

## Régions Courantes

- **us-east-1** - N. Virginia (par défaut dans le script)
- **eu-north-1** - Stockholm (visible dans votre capture d'écran)
- **eu-west-1** - Ireland
- **ap-southeast-1** - Singapore

**Important**: Assurez-vous que la région dans la console correspond à la région de votre stack!

## Support

Si les alarmes ne s'affichent toujours pas après ces étapes:

1. Vérifiez les logs CloudFormation pour les erreurs
2. Vérifiez les permissions IAM
3. Vérifiez que le topic SNS existe et est confirmé

