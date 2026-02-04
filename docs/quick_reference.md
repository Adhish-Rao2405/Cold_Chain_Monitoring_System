# ColdTrack Quick Reference

Quick commands and shortcuts for daily ColdTrack operations.

---

## Initial Setup (One-Time)

```bash
# 1. Clone repository
git clone https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git
cd Cold_Chain_Monitoring_System

# 2. Install dependencies
pip3 install -r requirements.txt

# 3. Configure environment
cp config/.env.example .env
nano .env  # Edit with your values

# 4. Start local services
docker-compose -f config/docker-compose.yml up -d

# 5. Setup AWS IoT
./scripts/setup_aws.sh

# 6. Deploy Lambda
./scripts/deploy_lambda.sh

# 7. Test connection
./scripts/test_connection.sh

# 8. Run simulator
cd device/simulator && python3 simulator.py
```

---

## Daily Operations

### Start Services

```bash
# Start all Docker services
docker-compose -f config/docker-compose.yml up -d

# Start simulator
cd device/simulator
python3 simulator.py
```

### Stop Services

```bash
# Stop simulator
Ctrl+C

# Stop Docker services
docker-compose -f config/docker-compose.yml down
```

### View Data

```bash
# Open Grafana
open http://localhost:3000

# Open InfluxDB
open http://localhost:8086
```

---

## Monitoring Commands

### Check System Status

```bash
# Check all Docker containers
docker ps

# Check simulator is running
ps aux | grep simulator

# Check Lambda function
aws lambda get-function --function-name ColdTrack-Process
```

### View Logs

```bash
# Lambda logs (real-time)
aws logs tail /aws/lambda/ColdTrack-Process --follow

# InfluxDB logs
docker logs coldtrack-influxdb --tail 50 --follow

# Grafana logs
docker logs coldtrack-grafana --tail 50 --follow
```

### Query Data

```bash
# Query InfluxDB (last hour)
docker exec -it coldtrack-influxdb influx query '
from(bucket: "sensors")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "sensor_data")
'

# Count total messages
docker exec -it coldtrack-influxdb influx query '
from(bucket: "sensors")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "sensor_data")
  |> count()
'
```

---

## AWS Commands

### IoT Core

```bash
# List things
aws iot list-things

# Describe thing
aws iot describe-thing --thing-name CT-001

# List certificates
aws iot list-certificates

# Get IoT endpoint
aws iot describe-endpoint --endpoint-type iot:Data-ATS
```

### Lambda

```bash
# Invoke Lambda manually
aws lambda invoke \
  --function-name ColdTrack-Process \
  --payload '{"device_id":"CT-001","temperature":5.5,"humidity":65,"battery":85,"timestamp":1706875200}' \
  output.json

# View Lambda config
aws lambda get-function-configuration --function-name ColdTrack-Process

# Update environment variables
aws lambda update-function-configuration \
  --function-name ColdTrack-Process \
  --environment Variables="{INFLUX_URL=http://your-ip:8086,INFLUX_TOKEN=your-token}"
```

### CloudWatch Logs

```bash
# Tail logs
aws logs tail /aws/lambda/ColdTrack-Process --follow

# Search logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/ColdTrack-Process \
  --filter-pattern "ERROR"

# Get last 10 errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/ColdTrack-Process \
  --filter-pattern "ERROR" \
  --max-items 10
```

---

## Docker Commands

### Manage Containers

```bash
# Start services
docker-compose -f config/docker-compose.yml up -d

# Stop services
docker-compose -f config/docker-compose.yml stop

# Restart services
docker-compose -f config/docker-compose.yml restart

# Remove services (keeps data)
docker-compose -f config/docker-compose.yml down

# Remove services AND data
docker-compose -f config/docker-compose.yml down -v
```

### Container Operations

```bash
# View container stats
docker stats

# Execute command in container
docker exec -it coldtrack-influxdb bash

# View container logs
docker logs coldtrack-influxdb --tail 100 --follow

# Inspect container
docker inspect coldtrack-influxdb
```

### Troubleshooting

```bash
# Restart specific service
docker-compose -f config/docker-compose.yml restart influxdb

# Rebuild service
docker-compose -f config/docker-compose.yml build influxdb

# View service health
docker-compose -f config/docker-compose.yml ps
```

---

## InfluxDB Commands

### Inside Container

```bash
# Enter container
docker exec -it coldtrack-influxdb bash

# List buckets
influx bucket list

# List measurements
influx query 'import "influxdata/influxdb/schema" schema.measurements(bucket: "sensors")'

# Delete data (careful!)
influx delete \
  --bucket sensors \
  --start 2024-01-01T00:00:00Z \
  --stop 2024-12-31T23:59:59Z \
  --predicate '_measurement="sensor_data"'
```

### Backup & Restore

```bash
# Backup
docker exec coldtrack-influxdb influx backup /tmp/backup
docker cp coldtrack-influxdb:/tmp/backup ./backups/$(date +%Y%m%d)

# Restore
docker cp ./backups/20240204 coldtrack-influxdb:/tmp/restore
docker exec coldtrack-influxdb influx restore /tmp/restore
```

---

## Grafana Commands

### API Operations

```bash
# Get dashboards
curl -u admin:admin http://localhost:3000/api/dashboards/db

# Export dashboard
curl -u admin:admin http://localhost:3000/api/dashboards/uid/coldtrack-main > dashboard_backup.json

# Import dashboard
curl -X POST \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d @visualization/dashboards/main_dashboard.json \
  http://localhost:3000/api/dashboards/db
```

### Reset Password

```bash
# Reset Grafana admin password
docker exec -it coldtrack-grafana grafana-cli admin reset-admin-password newpassword
```

---

## Simulator Commands

### Run Simulator

```bash
# Basic run
python3 device/simulator/simulator.py

# Custom interval (30 seconds)
python3 device/simulator/simulator.py --interval 30

# Custom config
python3 device/simulator/simulator.py --config custom_config.json
```

### Edit Config

```bash
# Edit simulator config
nano device/simulator/config.json

# Important settings:
# - device_id: Device identifier
# - mqtt_endpoint: AWS IoT endpoint
# - publish_interval: Seconds between messages
# - temp_range: [min, max] temperature range
```

---

## Testing Commands

### Run Tests

```bash
# All tests
pytest tests/ -v

# Unit tests only
pytest tests/unit/ -v

# Integration tests only
pytest tests/integration/ -v

# With coverage
pytest tests/ -v --cov=device --cov=cloud --cov-report=html

# Specific test file
pytest tests/unit/test_simulator.py -v
```

### Manual Testing

```bash
# Test MQTT connection
./scripts/test_connection.sh

# Publish test message
mosquitto_pub \
  --cafile certificates/AmazonRootCA1.pem \
  --cert certificates/device.crt \
  --key certificates/private.key \
  -h $(cat certificates/iot_endpoint.txt) \
  -p 8883 \
  -t coldtrack/test \
  -m '{"test": "message"}' \
  -q 1 -d
```

---

## Maintenance Commands

### Update Dependencies

```bash
# Update Python packages
pip3 install -r requirements.txt --upgrade

# Update Docker images
docker-compose -f config/docker-compose.yml pull
docker-compose -f config/docker-compose.yml up -d
```

### Clean Up

```bash
# Remove old Docker images
docker image prune -a

# Remove unused volumes
docker volume prune

# Clear Lambda logs older than 7 days
aws logs delete-log-stream \
  --log-group-name /aws/lambda/ColdTrack-Process \
  --log-stream-name 'old-stream-name'

# Clean InfluxDB old data (older than 90 days)
docker exec -it coldtrack-influxdb influx delete \
  --bucket sensors \
  --start 1970-01-01T00:00:00Z \
  --stop $(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --predicate '_measurement="sensor_data"'
```

---

## Useful Shortcuts

### Environment Variables

```bash
# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Check environment variables
echo $AWS_REGION
echo $INFLUX_URL
```

### SSH/Remote Access

```bash
# SSH tunnel to remote InfluxDB
ssh -L 8086:localhost:8086 user@remote-server

# SSH tunnel to remote Grafana
ssh -L 3000:localhost:3000 user@remote-server
```

### Git Operations

```bash
# Commit changes
git add .
git commit -m "Description of changes"
git push origin main

# Create new branch
git checkout -b feature/new-feature

# Merge branch
git checkout main
git merge feature/new-feature
```

---

## Emergency Commands

### System Down

```bash
# Full restart
docker-compose -f config/docker-compose.yml restart
python3 device/simulator/simulator.py
```

### Data Recovery

```bash
# Restore InfluxDB from backup
docker-compose -f config/docker-compose.yml stop influxdb
docker cp ./backups/latest coldtrack-influxdb:/tmp/restore
docker-compose -f config/docker-compose.yml start influxdb
docker exec coldtrack-influxdb influx restore /tmp/restore
```

### Reset Everything

```bash
# DANGER: This will delete all data!
docker-compose -f config/docker-compose.yml down -v
rm -rf certificates/*
./scripts/setup_aws.sh
docker-compose -f config/docker-compose.yml up -d
./scripts/deploy_lambda.sh
```

---

## Quick Links

- **Grafana**: http://localhost:3000 (admin/admin)
- **InfluxDB**: http://localhost:8086 (admin/coldtrack2024)
- **AWS Console**: https://console.aws.amazon.com/
- **GitHub Repo**: https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System
- **Documentation**: `docs/` folder

---

## Getting Help

```bash
# Simulator help
python3 device/simulator/simulator.py --help

# AWS CLI help
aws iot help
aws lambda help

# Docker Compose help
docker-compose --help

# InfluxDB help
docker exec -it coldtrack-influxdb influx --help
```
