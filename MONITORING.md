# 📊 Guide de Monitoring - Todo App AWS

Guide complet pour utiliser et configurer le monitoring CloudWatch pour l'application Todo.

## 🎯 Vue d'Ensemble

Le monitoring de l'application Todo utilise AWS CloudWatch pour:
- **Métriques** - CPU, réseau, mémoire, disque
- **Logs** - Logs de l'application en temps réel
- **Alarmes** - Alertes automatiques par email
- **Dashboard** - Vue d'ensemble visuelle

## 📈 Dashboard CloudWatch

### Accès

1. Connectez-vous à la [Console AWS](https://console.aws.amazon.com)
2. Allez dans **CloudWatch** → **Dashboards**
3. Sélectionnez `prod-todo-app-dashboard`

### Widgets Disponibles

#### 1. CPU Utilization
- Affiche l'utilisation CPU des instances WebServer et Database
- Période: 5 minutes
- Statistic: Average

#### 2. Network Traffic
- Affiche le trafic réseau entrant et sortant
- Séparé par instance (WebServer et Database)
- Période: 5 minutes
- Statistic: Sum

#### 3. Status Check
- Affiche les échecs de status check
- Alerte immédiate en cas de problème
- Période: 1 minute
- Statistic: Maximum

## 🚨 Alarmes CloudWatch

### Alarmes Configurées

#### WebServer

1. **High CPU Alarm**
   - Nom: `prod-webserver-high-cpu`
   - Condition: CPU > 80% pendant 5 minutes
   - Action: Email via SNS

2. **Status Check Failed**
   - Nom: `prod-webserver-status-check-failed`
   - Condition: Status check échoue 2 fois consécutives
   - Action: Email via SNS

#### Database

1. **High CPU Alarm**
   - Nom: `prod-database-high-cpu`
   - Condition: CPU > 80% pendant 5 minutes
   - Action: Email via SNS

2. **Status Check Failed**
   - Nom: `prod-database-status-check-failed`
   - Condition: Status check échoue 2 fois consécutives
   - Action: Email via SNS

### Vérifier les Alarmes

```bash
# Lister toutes les alarmes
aws cloudwatch describe-alarms \
  --alarm-name-prefix prod-

# Vérifier l'état d'une alerte spécifique
aws cloudwatch describe-alarms \
  --alarm-names prod-webserver-high-cpu
```

### Historique des Alarmes

1. Console AWS → CloudWatch → Alarmes
2. Cliquez sur une alerte
3. Onglet "History" pour voir l'historique

## 📝 Logs CloudWatch

### Log Group

- **Nom**: `/aws/ec2/todo-app/webserver`
- **Log Stream**: `{instance_id}` (ID de l'instance EC2)

### Accès aux Logs

#### Via Console AWS

1. Console AWS → CloudWatch → Logs → Log groups
2. Cliquez sur `/aws/ec2/todo-app/webserver`
3. Sélectionnez un log stream
4. Visualisez les logs en temps réel

#### Via AWS CLI

```bash
# Lister les log streams
aws logs describe-log-streams \
  --log-group-name /aws/ec2/todo-app/webserver

# Récupérer les logs récents
aws logs tail /aws/ec2/todo-app/webserver \
  --follow \
  --format short
```

### Format des Logs

Les logs incluent:
- Timestamp ISO 8601
- Niveau de log (INFO, ERROR, WARN)
- Message de log
- Métadonnées (requête HTTP, etc.)

## 🔧 CloudWatch Agent

### Configuration

Le CloudWatch Agent est installé automatiquement sur le WebServer avec:
- **Métriques personnalisées**: CPU détaillé, mémoire, disque
- **Logs**: Collection automatique des logs de l'application

### Métriques Personnalisées

Les métriques suivantes sont collectées:

#### CPU
- `CPU_USAGE_IDLE` - CPU inactif (%)
- `CPU_USAGE_IOWAIT` - CPU en attente I/O (%)
- `CPU_USAGE_USER` - CPU utilisateur (%)
- `CPU_USAGE_SYSTEM` - CPU système (%)

#### Mémoire
- `MEM_USED_PERCENT` - Mémoire utilisée (%)

#### Disque
- `DISK_USED_PERCENT` - Disque utilisé (%)

### Namespace

Toutes les métriques personnalisées sont dans le namespace: `TodoApp/WebServer`

### Vérifier l'Agent

```bash
# Se connecter au WebServer
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$WEBSERVER_IP

# Vérifier le statut de l'agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 -c ssm:AmazonCloudWatch-linux -a status

# Voir les logs de l'agent
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

## 📊 Métriques Standard EC2

### Métriques Disponibles

- **CPUUtilization** - Utilisation CPU (%)
- **NetworkIn** - Trafic réseau entrant (bytes)
- **NetworkOut** - Trafic réseau sortant (bytes)
- **StatusCheckFailed** - Échec du status check (0 ou 1)
- **DiskReadOps** - Opérations de lecture disque
- **DiskWriteOps** - Opérations d'écriture disque

### Requête de Métriques

```bash
# CPU Utilization des 24 dernières heures
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```

## 🎨 Personnalisation

### Ajouter une Nouvelle Alerte

1. Console AWS → CloudWatch → Alarmes → Create alarm
2. Sélectionnez la métrique
3. Configurez le seuil
4. Ajoutez l'action SNS

### Créer un Widget Personnalisé

1. Ouvrez le dashboard
2. Cliquez sur "Edit"
3. Ajoutez un widget
4. Sélectionnez les métriques
5. Sauvegardez

## 🔍 Dépannage

### Les logs ne s'affichent pas

```bash
# Vérifier que l'agent tourne
ssh -i ~/.ssh/todo-app-key.pem ec2-user@$WEBSERVER_IP
sudo systemctl status amazon-cloudwatch-agent

# Redémarrer l'agent
sudo systemctl restart amazon-cloudwatch-agent
```

### Les métriques personnalisées n'apparaissent pas

```bash
# Vérifier la configuration
sudo cat /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Recharger la configuration
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
```

### Les alarmes ne se déclenchent pas

1. Vérifiez que l'abonnement SNS est confirmé
2. Vérifiez les seuils de l'alarme
3. Vérifiez que les métriques sont collectées

## 📚 Ressources

- [Documentation CloudWatch](https://docs.aws.amazon.com/cloudwatch/)
- [CloudWatch Agent Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [CloudWatch Dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)

