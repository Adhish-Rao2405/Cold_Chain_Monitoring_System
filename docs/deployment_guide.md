# ColdTrack Deployment Guide

Complete step-by-step guide for deploying ColdTrack from scratch.

## Prerequisites

### Required Software

```bash
# 1. Python 3.11+
python3 --version

# 2. Docker & Docker Compose
docker --version
docker-compose --version

# 3. AWS CLI
aws --version

# 4. Git
git --version

# 5. Node.js (optional, for npm)
node --version
```

### AWS Account Setup

1. **Create AWS Account** (if needed)
   - Visit https://aws.amazon.com/
   - Sign up for free tier

2. **Configure AWS CLI**
   ```bash
   aws configure
   ```
   Enter:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region: `eu-west-2`
   - Default output format: `json`

3. **Verify AWS Access**
   ```bash
   aws sts get-caller-identity
   ```

---

## Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git
cd Cold_Chain_Monitoring_System

# Verify structure
ls -la
```

---

## Step 2: Environment Configuration

### Create Environment File

```bash
# Copy example environment file
cp config/.env.example .env

# Edit configuration
nano .env
```

### Required Environment Variables

Update the following in `.env`:

```bash
# AWS Configuration
AWS_REGION=eu-west-2
AWS_ACCOUNT_ID=123456789012  # Replace with your AWS account ID

# InfluxDB Configuration
INFLUX_URL=http://localhost:8086
INFLUX_TOKEN=your-token-here  # Will be generated
INFLUX_ORG=coldtrack
INFLUX_BUCKET=sensors

# Temperature Thresholds
TEMP_MIN=2.0
TEMP_MAX=8.0
FREEZE_ALERT_THRESHOLD=0.0

# Battery Thresholds
BATTERY_LOW_THRESHOLD=20.0
BATTERY_CRITICAL_THRESHOLD=10.0
```

---

## Step 3: Start Local Services

### Start InfluxDB & Grafana

```bash
# Start Docker containers
docker-compose -f config/docker-compose.yml up -d

# Verify services are running
docker ps
```

Expected output:
```
CONTAINER ID   IMAGE              STATUS         PORTS
abc123         influxdb:2.7       Up 10 seconds  0.0.0.0:8086->8086/tcp
def456         grafana/grafana    Up 10 seconds  0.0.0.0:3000->3000/tcp
```

### Configure InfluxDB

1. **Open InfluxDB UI**
   ```bash
   open http://localhost:8086
   ```

2. **Initial Setup**
   - Username: `admin`
   - Password: `coldtrack2024`
   - Organization: `coldtrack`
   - Bucket: `sensors`

3. **Generate API Token**
   - Go to Settings → Tokens
   - Click "Generate API Token" → "All Access"
   - Copy token and update `.env` file
   ```bash
   INFLUX_TOKEN=your_generated_token_here
   ```

### Configure Grafana

1. **Open Grafana**
   ```bash
   open http://localhost:3000
   ```

2. **Login**
   - Username: `admin`
   - Password: `admin`
   - Change password when prompted

3. **Add InfluxDB Data Source**
   - Go to Configuration → Data Sources
   - Click "Add data source"
   - Select "InfluxDB"
   - Configure:
     - Query Language: `Flux`
     - URL: `http://influxdb:8086`
     - Organization: `coldtrack`
     - Token: `<your InfluxDB token>`
     - Default Bucket: `sensors`
   - Click "Save & Test"

---

## Step 4: Setup AWS IoT Core

### Run Automated Setup

```bash
# Make script executable
chmod +x scripts/setup_aws.sh

# Run setup script
./scripts/setup_aws.sh
```

This script will:
- Create IoT Thing (CT-001)
- Generate X.509 certificates
- Create IoT policy
- Attach policy to certificate
- Download Root CA
- Get IoT endpoint

### Manual Verification

1. **Check IoT Thing**
   ```bash
   aws iot describe-thing --thing-name CT-001
   ```

2. **Verify Certificates**
   ```bash
   ls -l certificates/
   ```
   Should see:
   - `device.crt`
   - `private.key`
   - `public.key`
   - `AmazonRootCA1.pem`
   - `iot_endpoint.txt`

3. **View IoT Endpoint**
   ```bash
   cat certificates/iot_endpoint.txt
   ```

---

## Step 5: Deploy Lambda Functions

### Run Deployment Script

```bash
# Make script executable
chmod +x scripts/deploy_lambda.sh

# Deploy Lambda
./scripts/deploy_lambda.sh
```

This script will:
- Create Lambda execution role
- Install Python dependencies
- Package Lambda function
- Deploy to AWS
- Create IoT Rule for automatic triggering

### Verify Lambda Deployment

1. **Check Lambda Function**
   ```bash
   aws lambda get-function --function-name ColdTrack-Process
   ```

2. **Check IoT Rule**
   ```bash
   aws iot get-topic-rule --rule-name ProcessData
   ```

3. **Test Lambda Manually**
   ```bash
   # Create test event
   cat > test_event.json << EOF
   {
     "device_id": "CT-001",
     "temperature": 5.5,
     "humidity": 65.0,
     "battery": 85.0,
     "timestamp": $(date +%s)
   }
   EOF
   
   # Invoke Lambda
   aws lambda invoke \
     --function-name ColdTrack-Process \
     --payload file://test_event.json \
     --region eu-west-2 \
     output.json
   
   # View response
   cat output.json
   ```

---

## Step 6: Test MQTT Connection

### Run Connection Test

```bash
# Make script executable
chmod +x scripts/test_connection.sh

# Run test
./scripts/test_connection.sh
```

### Manual MQTT Test (Alternative)

```bash
# Install mosquitto (if needed)
# Mac: brew install mosquitto
# Linux: apt-get install mosquitto-clients

# Get IoT endpoint
IOT_ENDPOINT=$(cat certificates/iot_endpoint.txt)

# Publish test message
mosquitto_pub \
  --cafile certificates/AmazonRootCA1.pem \
  --cert certificates/device.crt \
  --key certificates/private.key \
  -h $IOT_ENDPOINT \
  -p 8883 \
  -t coldtrack/test \
  -m '{"test": "message"}' \
  -q 1 \
  -d
```

---

## Step 7: Run Device Simulator

### Install Python Dependencies

```bash
cd device/simulator
pip3 install -r requirements.txt
```

### Start Simulator

```bash
# Run simulator (Ctrl+C to stop)
python3 simulator.py
```

Expected output:
```
============================================================
🌡️  ColdTrack Device Simulator
============================================================
Device ID: CT-001
Publish Interval: 60s
Temperature Range: 2.0°C to 8.0°C
============================================================

🔌 Connecting to AWS IoT Core...
   Device: CT-001
   Endpoint: xxxxx.iot.eu-west-2.amazonaws.com
✅ Connected to AWS IoT Core!

📊 Publishing data... (Press Ctrl+C to stop)

🟢 [15:23:45] Temp: +5.23°C | Humidity: 65.4% | Battery: 100.0%
🟢 [15:24:45] Temp: +6.12°C | Humidity: 63.2% | Battery: 99.9%
```

---

## Step 8: Verify Data Pipeline

### Check Lambda Logs

```bash
# Tail Lambda logs in real-time
aws logs tail /aws/lambda/ColdTrack-Process --follow --region eu-west-2
```

Expected output:
```
2024-02-04T15:23:46.123Z START RequestId: abc-123
2024-02-04T15:23:46.234Z 📥 Received event: {"device_id":"CT-001",...}
2024-02-04T15:23:46.456Z ✅ Data written to InfluxDB: CT-001 - 5.23°C
2024-02-04T15:23:46.567Z END RequestId: abc-123
```

### Query InfluxDB

```bash
# Using InfluxDB CLI
docker exec -it coldtrack-influxdb influx query '
from(bucket: "sensors")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "sensor_data")
  |> filter(fn: (r) => r._field == "temperature")
  |> last()
'
```

### Check Grafana Dashboard

1. Open Grafana: http://localhost:3000
2. Go to Dashboards → Browse
3. Import dashboard from `visualization/dashboards/main_dashboard.json`
4. You should see live temperature data!

---

## Step 9: Import Grafana Dashboard

### Option 1: Manual Import

1. Open Grafana: http://localhost:3000
2. Click "+" → "Import"
3. Click "Upload JSON file"
4. Select `visualization/dashboards/main_dashboard.json`
5. Click "Import"

### Option 2: API Import

```bash
# Get Grafana admin credentials
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

# Import dashboard
curl -X POST \
  -H "Content-Type: application/json" \
  -d @visualization/dashboards/main_dashboard.json \
  http://$GRAFANA_USER:$GRAFANA_PASS@localhost:3000/api/dashboards/db
```

---

## Step 10: Configure Alerts (Optional)

### Create SNS Topic

```bash
# Create SNS topic for alerts
aws sns create-topic --name coldtrack-alerts --region eu-west-2

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-west-2:YOUR_ACCOUNT:coldtrack-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

### Update Lambda to Send Alerts

Edit `cloud/lambda/data_processor/lambda_function.py`:

```python
# Add SNS client
import boto3
sns = boto3.client('sns')

# In check_alerts() function, add:
if alerts:
    sns.publish(
        TopicArn='arn:aws:sns:eu-west-2:YOUR_ACCOUNT:coldtrack-alerts',
        Subject='ColdTrack Alert',
        Message=json.dumps(alerts)
    )
```

Redeploy Lambda:
```bash
./scripts/deploy_lambda.sh
```

---

## Verification Checklist

- [ ] InfluxDB running on port 8086
- [ ] Grafana running on port 3000
- [ ] AWS IoT Thing created (CT-001)
- [ ] Device certificates generated
- [ ] Lambda function deployed
- [ ] IoT Rule created
- [ ] Simulator publishing data
- [ ] Lambda processing messages
- [ ] Data visible in InfluxDB
- [ ] Grafana dashboard showing real-time data

---

## Troubleshooting

### Issue: Simulator can't connect to AWS IoT

**Solution:**
```bash
# Check IoT endpoint
cat certificates/iot_endpoint.txt

# Verify certificates exist
ls -l certificates/

# Test TLS connection
openssl s_client \
  -connect $(cat certificates/iot_endpoint.txt):8883 \
  -CAfile certificates/AmazonRootCA1.pem \
  -cert certificates/device.crt \
  -key certificates/private.key
```

### Issue: Lambda not triggering

**Solution:**
```bash
# Check IoT Rule
aws iot get-topic-rule --rule-name ProcessData

# Check Lambda permissions
aws lambda get-policy --function-name ColdTrack-Process

# View CloudWatch Logs
aws logs tail /aws/lambda/ColdTrack-Process --follow
```

### Issue: No data in Grafana

**Solution:**
```bash
# Check InfluxDB connection
curl http://localhost:8086/health

# Query InfluxDB directly
docker exec -it coldtrack-influxdb influx query '
from(bucket: "sensors") |> range(start: -1h)
'

# Verify Grafana data source
curl http://admin:admin@localhost:3000/api/datasources
```

### Issue: Docker containers not starting

**Solution:**
```bash
# Check Docker daemon
docker ps

# View container logs
docker logs coldtrack-influxdb
docker logs coldtrack-grafana

# Restart containers
docker-compose -f config/docker-compose.yml restart

# Clean restart
docker-compose -f config/docker-compose.yml down
docker-compose -f config/docker-compose.yml up -d
```

---

## Next Steps

After successful deployment:

1. **Monitor the System**
   - Watch CloudWatch metrics
   - Check Grafana dashboard regularly
   - Review Lambda logs

2. **Test Alert Scenarios**
   - Modify simulator to trigger freeze events
   - Verify alert notifications

3. **Add More Devices**
   - Create additional IoT Things
   - Deploy multiple simulators

4. **Optimize Performance**
   - Adjust Lambda memory/timeout
   - Tune InfluxDB retention policies
   - Optimize Grafana queries

5. **Prepare for Hardware**
   - Order ESP32 components
   - Set up development environment
   - Test hardware sensors

---

## Production Deployment

For production deployment, consider:

1. **Security Hardening**
   - Rotate certificates regularly
   - Use AWS Secrets Manager
   - Enable CloudTrail auditing
   - Configure VPC for Lambda

2. **High Availability**
   - Deploy InfluxDB cluster
   - Use Application Load Balancer for Grafana
   - Multi-AZ deployment

3. **Monitoring & Alerting**
   - Set up CloudWatch alarms
   - Configure PagerDuty integration
   - Enable detailed logging

4. **Backup & Recovery**
   - Automated InfluxDB snapshots
   - Cross-region replication
   - Disaster recovery testing

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System/issues
- Email: [your-email]
- Documentation: See `docs/` folder
