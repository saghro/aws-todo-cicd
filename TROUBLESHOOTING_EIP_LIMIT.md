# 🔧 Dépannage - Limite d'Elastic IPs Atteinte

## Problème

Erreur CloudFormation :
```
The maximum number of addresses has been reached
Resource: NatGatewayEIP
```

## Cause

AWS limite le nombre d'**Elastic IPs (EIPs)** à **5 par région** par défaut. Votre compte a atteint cette limite, et CloudFormation ne peut pas créer une nouvelle EIP pour le NAT Gateway.

## Solution Rapide

### Option 1: Libérer les EIPs Non Utilisées (Recommandé)

Utilisez le script automatique :

```bash
./scripts/check-elastic-ips.sh us-east-1
```

Le script :
- ✅ Liste toutes vos Elastic IPs
- ✅ Identifie celles qui ne sont pas utilisées
- ✅ Propose de les libérer automatiquement

### Option 2: Libération Manuelle

#### Étape 1: Lister les EIPs

```bash
aws ec2 describe-addresses --region us-east-1
```

#### Étape 2: Identifier les EIPs Non Utilisées

Les EIPs non utilisées n'ont pas de `AssociationId`. Recherchez celles avec `"AssociationId": null`.

#### Étape 3: Libérer une EIP

```bash
# Remplacer ALLOCATION_ID par l'ID de l'EIP à libérer
aws ec2 release-address \
  --allocation-id eipalloc-xxxxxxxxx \
  --region us-east-1
```

### Option 3: Augmenter la Limite

Si vous avez vraiment besoin de plus de 5 EIPs :

1. Allez dans [AWS Support Center](https://console.aws.amazon.com/support/home)
2. Créez une demande d'augmentation de limite
3. Service: EC2-VPC
4. Type de limite: Elastic IP addresses
5. Région: us-east-1 (ou votre région)
6. Nouvelle valeur limite: (ex: 10)

**Note**: L'approbation peut prendre quelques heures.

## Vérification

Après avoir libéré une EIP, vérifiez :

```bash
# Compter les EIPs
aws ec2 describe-addresses --region us-east-1 \
  --query 'length(Addresses)'

# Vous devriez avoir moins de 5 EIPs maintenant
```

## Prévention

Pour éviter ce problème à l'avenir :

1. **Libérez régulièrement les EIPs non utilisées**
2. **Surveillez votre utilisation** avec le script `check-elastic-ips.sh`
3. **Supprimez les stacks CloudFormation** qui ne sont plus utilisées (elles libèrent automatiquement les EIPs)

## Commandes Utiles

```bash
# Lister toutes les EIPs avec détails
aws ec2 describe-addresses --region us-east-1 \
  --query 'Addresses[*].[AllocationId,PublicIp,AssociationId,InstanceId]' \
  --output table

# Compter les EIPs utilisées vs non utilisées
aws ec2 describe-addresses --region us-east-1 \
  --query '[length(Addresses), length(Addresses[?AssociationId==`null`])]' \
  --output text

# Libérer une EIP spécifique
aws ec2 release-address --allocation-id eipalloc-xxxxx --region us-east-1
```

## Après la Libération

Une fois qu'une EIP est libérée :

1. ✅ Vérifiez que vous avez moins de 5 EIPs
2. ✅ Relancez le pipeline GitHub Actions
3. ✅ La stack CloudFormation devrait maintenant pouvoir créer l'EIP pour le NAT Gateway

## Note Importante

⚠️ **Attention**: Ne libérez pas une EIP qui est utilisée par une instance en production ! Vérifiez toujours l'`AssociationId` avant de libérer.

Une EIP avec un `AssociationId` est associée à une ressource (instance, NAT Gateway, etc.) et ne doit **PAS** être libérée.

