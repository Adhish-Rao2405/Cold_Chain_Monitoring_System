# ColdTrack Troubleshooting Guide

Common issues and solutions for ColdTrack deployment and operation.

---

## Quick Diagnostics

Run these commands first to check overall system health:

```bash
# Check all services
docker ps
aws iot describe-thing --thing-name CT-001
aws lambda get-function --function-name ColdTrack-Process

# Check logs
docker logs coldtrack-influxdb --tail 50
docker logs coldtrack-grafana --tail 50
aws logs tail /aws/lambda/ColdTrack-Process --follow
```

---

## Device Simulator Issues

### Issue: "AWS IoT SDK not installed"

**Symptoms:**
```
❌ Error: AWS IoT SDK not installed
Run: pip install awsiotsdk
```

**Solution:**
```bash
cd device/simulator
pip3 install -r requirements.txt
```

---

### Issue: "Connection failed" or "mqtt_connection is None"

**Symptoms:**
```
❌ Connection failed: [Errno 8] nodename nor servname provided, or not known
```

**Possible Causes:**
1. Incorrect IoT endpoint
2. Invalid certificates
3. Certificate not attached to policy

**Solution:**

1. **Verify IoT endpoint:**
```bash
cat certificates/iot_endpoint.txt
# Should be: xxxxx.iot.eu-west-2.amazonaws.com
```

2. **Check certificates exist:**
```bash
ls -l certificates/
# Should see: device.crt, private.key, AmazonRootCA1.pem
```

3. **Test TLS connection:**
```bash
openssl s_client \
  -connect $(cat certificates/iot_endpoint.txt):8883 \
  -CAfile certificates/AmazonRootCA1.pem \
  -cert certificates/device.crt \
  -key certificates/private.key
# Should see "Verify return code: 0 (ok)"
```

4. **Verify certificate is attached to policy:**
```bash
# Get certificate ARN
CERT_ARN=$(cat certificates/cert_arn.txt)

# List attached policies
aws iot list-attached-policies --target $CERT_ARN

# Should show: ColdTrackPolicy
```

5. **Re-run setup if needed:**
```bash
./scripts/setup_aws.sh
```

---

### Issue: "Config file not found"

**Symptoms:**
```
❌ Config file not found: config.json
📝 Using default configuration
```

**Solution:**
```bash
# Copy example config
cp device/simulator/config.json.example device/simulator/config.json

# Or let simulator create default
python3 device/simulator/simulator.py
# Edit config.json with your IoT endpoint
```

---

### Issue: Simulator publishes but no data in InfluxDB

**Symptoms:**
- Simulator shows "Published: X.XX°C"
- No data appears in Grafana
- No Lambda logs

**Diagnosis:**
```bash
# Check IoT Rule
aws iot get-topic-rule --rule-name ProcessData

# Check Lambda is triggered
aws logs tail /aws/lambda/ColdTrack-Process --follow

# Subscribe to IoT topic
aws iot-data publish \
  --topic coldtrack/test \
  --cli-binary-format raw-in-base64-out \
  --payload '{"test": "message"}'
```

**Solution:**

1. **Verify Lambda has IoT permission:**
```bash
aws lambda get-policy --function-name ColdTrack-Process
# Should show iot.amazonaws.com as principal
```

2. **Re-create IoT Rule:**
```bash
./scripts/deploy_lambda.sh
```

3. **Check CloudWatch Logs for errors:**
```bash
aws logs tail /aws/lambda/ColdTrack-Process --follow
```

---

## Lambda Function Issues

### Issue: "Lambda not found"

**Symptoms:**
```
An error occurred (ResourceNotFoundException) when calling GetFunction
```

**Solution:**
```bash
# Deploy Lambda
./scripts/deploy_lambda.sh
```

---

### Issue: Lambda timeout or memory errors

**Symptoms:**
```
Task timed out after 30.00 seconds
REPORT Memory Size: 256 MB Max Memory Used: 256 MB
```

**Solution:**

1. **Increase timeout:**
```bash
aws lambda update-function-configuration \
  --function-name ColdTrack-Process \
  --timeout 60
```

2. **Increase memory:**
```bash
aws lambda update-function-configuration \
  --function-name ColdTrack-Process \
  --memory-size 512
```

---

### Issue: "Module 'influxdb_client' has no attribute..."

**Symptoms:**
```
[ERROR] AttributeError: module 'influxdb_client' has no attribute 'InfluxDBClient'
```

**Solution:**
```bash
# Re-package Lambda with correct dependencies
cd cloud/lambda/data_processor
rm -rf __pycache__/
pip3 install -r requirements.txt -t . --upgrade
```

Then redeploy:
```bash
./scripts/deploy_lambda.sh
```

---

### Issue: Lambda can't connect to InfluxDB

**Symptoms:**
```
[ERROR] ConnectionError: HTTPConnectionPool(host='localhost', port=8086)
```

**Possible Causes:**
1. InfluxDB not running
2. Incorrect INFLUX_URL environment variable
3. Lambda not in same VPC as InfluxDB (for production)

**Solution:**

1. **Check InfluxDB is running:**
```bash
curl http://localhost:8086/health
```

2. **Update Lambda environment variables:**
```bash
aws lambda update-function-configuration \
  --function-name ColdTrack-Process \
  --environment Variables="{
    INFLUX_URL=http://YOUR_INFLUXDB_IP:8086,
    INFLUX_TOKEN=your_token,
    INFLUX_ORG=coldtrack,
    INFLUX_BUCKET=sensors
  }"
```

3. **For local development, use public IP:**
```bash
# Get your public IP
curl ifconfig.me

# Update Lambda with public IP
INFLUX_URL=http://YOUR_PUBLIC_IP:8086
```

---

## InfluxDB Issues

### Issue: InfluxDB container won't start

**Symptoms:**
```
Error response from daemon: Conflict. The container name "/coldtrack-influxdb" is already in use
```

**Solution:**
```bash
# Stop and remove existing container
docker stop coldtrack-influxdb
docker rm coldtrack-influxdb

# Restart
docker-compose -f config/docker-compose.yml up -d
```

---

### Issue: "InfluxDB authentication failed"

**Symptoms:**
```
unauthorized: unauthorized access
```

**Solution:**

1. **Generate new token in InfluxDB UI:**
   - Open http://localhost:8086
   - Login with admin/coldtrack2024
   - Go to Settings → Tokens
   - Generate new "All Access" token

2. **Update environment variables:**
```bash
# Edit .env file
nano .env

# Update INFLUX_TOKEN
INFLUX_TOKEN=your_new_token

# Redeploy Lambda
./scripts/deploy_lambda.sh
```

---

### Issue: "No data in InfluxDB"

**Symptoms:**
- Simulator running
- Lambda processing
- But queries return empty

**Diagnosis:**
```bash
# Query InfluxDB directly
docker exec -it coldtrack-influxdb influx query '
from(bucket: "sensors")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "sensor_data")
'
```

**Solution:**

1. **Check bucket exists:**
```bash
docker exec -it coldtrack-influxdb influx bucket list
# Should show: sensors
```

2. **Create bucket if missing:**
```bash
docker exec -it coldtrack-influxdb influx bucket create \
  --name sensors \
  --org coldtrack \
  --retention 90d
```

3. **Test write manually:**
```bash
docker exec -it coldtrack-influxdb influx write \
  --bucket sensors \
  --org coldtrack \
  'sensor_data,device_id=CT-001 temperature=5.5'
```

---

## Grafana Issues

### Issue: Grafana won't start

**Symptoms:**
```
Error: unable to create database: permission denied
```

**Solution:**
```bash
# Fix permissions
sudo chown -R 472:472 grafana-data/

# Restart
docker-compose -f config/docker-compose.yml restart grafana
```

---

### Issue: "No data points" in Grafana dashboard

**Symptoms:**
- Dashboard loads but shows "No data"
- InfluxDB has data

**Solution:**

1. **Test data source connection:**
   - Open Grafana → Configuration → Data Sources
   - Click InfluxDB
   - Click "Save & Test"
   - Should show "Data source is working"

2. **Check Flux query syntax:**
```flux
from(bucket: "sensors")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "sensor_data")
  |> filter(fn: (r) => r._field == "temperature")
```

3. **Verify time range:**
   - Top-right corner → Select "Last 1 hour"
   - If still no data, try "Last 24 hours"

---

### Issue: Grafana dashboard import fails

**Symptoms:**
```
Dashboard validation failed
```

**Solution:**
```bash
# Manually import via UI
# 1. Copy dashboard JSON content
cat visualization/dashboards/main_dashboard.json

# 2. In Grafana:
#    - Click "+" → Import
#    - Paste JSON
#    - Click Import
```

---

## AWS IoT Core Issues

### Issue: "Thing not found"

**Symptoms:**
```
An error occurred (ResourceNotFoundException) when calling DescribeThing
```

**Solution:**
```bash
# Create thing
aws iot create-thing --thing-name CT-001

# Or re-run setup
./scripts/setup_aws.sh
```

---

### Issue: "Policy not attached"

**Symptoms:**
- Device connects but can't publish
- Log shows "not authorized"

**Solution:**
```bash
# Get certificate ARN
CERT_ARN=$(cat certificates/cert_arn.txt)

# Attach policy
aws iot attach-policy \
  --policy-name ColdTrackPolicy \
  --target $CERT_ARN
```

---

### Issue: IoT Rule not triggering Lambda

**Symptoms:**
- Messages arrive at IoT Core
- Lambda never invoked

**Diagnosis:**
```bash
# Check rule exists
aws iot get-topic-rule --rule-name ProcessData

# Check Lambda permission
aws lambda get-policy --function-name ColdTrack-Process
```

**Solution:**
```bash
# Add Lambda permission for IoT
aws lambda add-permission \
  --function-name ColdTrack-Process \
  --statement-id IoTInvoke \
  --action lambda:InvokeFunction \
  --principal iot.amazonaws.com

# Re-create rule
./scripts/deploy_lambda.sh
```

---

## Network & Connectivity Issues

### Issue: "Connection timeout" or "Network unreachable"

**Symptoms:**
```
[Errno 60] Operation timed out
```

**Possible Causes:**
1. Firewall blocking port 8883
2. Internet connection down
3. AWS region issue

**Solution:**

1. **Test internet connectivity:**
```bash
ping google.com
```

2. **Test AWS IoT endpoint:**
```bash
nslookup $(cat certificates/iot_endpoint.txt)
telnet $(cat certificates/iot_endpoint.txt) 8883
```

3. **Check firewall:**
```bash
# Allow port 8883
sudo ufw allow 8883/tcp  # Linux
# Or configure Mac firewall settings
```

---

## Docker Issues

### Issue: "Cannot connect to Docker daemon"

**Symptoms:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solution:**
```bash
# Start Docker Desktop (Mac/Windows)
open -a Docker

# Or start Docker daemon (Linux)
sudo systemctl start docker
```

---

### Issue: "Port already in use"

**Symptoms:**
```
Error starting userland proxy: bind: address already in use
```

**Solution:**

1. **Check what's using the port:**
```bash
lsof -i :8086  # InfluxDB
lsof -i :3000  # Grafana
```

2. **Kill the process or change port in docker-compose.yml**

---

## Performance Issues

### Issue: High CPU usage from simulator

**Symptoms:**
- Simulator using 100% CPU
- System slowdown

**Solution:**
```bash
# Increase publish interval
# Edit device/simulator/config.json
{
  "publish_interval": 120  # Increase from 60 to 120 seconds
}
```

---

### Issue: InfluxDB using too much memory

**Symptoms:**
```
InfluxDB container using 2GB+ memory
```

**Solution:**
```bash
# Set memory limits in docker-compose.yml
services:
  influxdb:
    ...
    mem_limit: 1g
    mem_reservation: 512m
```

---

## Getting Help

If you can't resolve your issue:

1. **Check logs:**
```bash
# Simulator logs (console output)
# Lambda logs
aws logs tail /aws/lambda/ColdTrack-Process --follow

# InfluxDB logs
docker logs coldtrack-influxdb --tail 100

# Grafana logs
docker logs coldtrack-grafana --tail 100
```

2. **Create GitHub issue:**
   - https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System/issues
   - Include error messages and logs
   - Describe what you've tried

3. **Contact team:**
   - Email: [your-email]
   - Include your setup configuration

---

## Preventive Measures

### Regular Maintenance

```bash
# Weekly: Clear old logs
aws logs delete-log-group --log-group-name /aws/lambda/ColdTrack-Process

# Monthly: Backup InfluxDB
docker exec coldtrack-influxdb influx backup /tmp/backup
docker cp coldtrack-influxdb:/tmp/backup ./backups/

# Quarterly: Rotate certificates
# (See AWS IoT documentation)
```

### Monitoring Checklist

- [ ] Lambda error rate < 1%
- [ ] InfluxDB disk usage < 80%
- [ ] Grafana dashboard loading < 2s
- [ ] Message delivery rate > 99%
- [ ] All containers healthy
