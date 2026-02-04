# ColdTrack Architecture Documentation

## System Overview

ColdTrack is a five-layer IoT architecture designed for real-time RSV vaccine cold chain monitoring with sub-1.5 second alert latency and multi-dimensional freeze damage assessment.

## Architecture Layers

### Layer 1: Device Layer (Edge)

**Components:**
- ESP32-WROOM-32 microcontroller
- TMP112 precision temperature sensor (primary)
- DS18B20 temperature sensor (redundancy)
- NEO-6M GPS module
- RC522 RFID reader
- SIM800L GSM module
- 18650 Li-ion battery (3.7V, 3000mAh)

**Responsibilities:**
- Temperature sampling (every 60 seconds)
- GPS location tracking
- RFID vaccine identification
- Data packetization
- MQTT message publishing
- Power management

**Communication Protocol:**
- MQTT over TLS 1.2
- QoS Level: 1 (At Least Once)
- Topic Structure: `coldtrack/sensors/{device_id}/data`

**Message Format:**
```json
{
  "device_id": "CT-001",
  "temperature": 5.23,
  "humidity": 65.4,
  "battery": 87.2,
  "latitude": 51.5074,
  "longitude": -0.1278,
  "rssi": -67,
  "timestamp": 1706875200,
  "message_id": 1706875200000
}
```

---

### Layer 2: Connectivity Layer (AWS IoT Core)

**Components:**
- AWS IoT Core (Device Gateway)
- X.509 certificates for authentication
- IoT Thing Registry
- IoT Policy for authorization
- IoT Rules Engine

**Responsibilities:**
- Device authentication & authorization
- Secure MQTT broker
- Message routing
- Device shadow management
- Rule-based message processing

**Security:**
- Mutual TLS authentication
- Per-device X.509 certificates
- Fine-grained IoT policies
- Encrypted in-transit (TLS 1.2)

**IoT Rule Configuration:**
```sql
SELECT * FROM 'coldtrack/sensors/+/data'
```

**Actions:**
1. Lambda function invocation
2. (Future) S3 archival
3. (Future) SNS notifications

---

### Layer 3: Processing Layer (AWS Lambda)

**Lambda Functions:**

#### 1. **Data Processor** (`ColdTrack-Process`)
- **Runtime:** Python 3.11
- **Memory:** 256MB
- **Timeout:** 30s
- **Triggers:** AWS IoT Rule

**Responsibilities:**
- Validate incoming sensor data
- Store data in InfluxDB
- Check alert thresholds
- Trigger alert handlers

**Environment Variables:**
```
INFLUX_URL=http://your-influxdb:8086
INFLUX_TOKEN=your-token
INFLUX_ORG=coldtrack
INFLUX_BUCKET=sensors
TEMP_MIN=2.0
TEMP_MAX=8.0
FREEZE_ALERT_THRESHOLD=0.0
```

#### 2. **Alert Handler** (Future)
- SNS notification dispatch
- Email/SMS alerts
- Webhook callbacks

#### 3. **Freeze Scorer** (Future)
- Multi-dimensional freeze damage calculation
- Depth, duration, frequency analysis
- Vaccine viability assessment

---

### Layer 4: Storage Layer (InfluxDB)

**Database:** InfluxDB 2.x (Time-Series Database)

**Data Model:**

**Measurement:** `sensor_data`

**Tags:**
- `device_id` (indexed)

**Fields:**
- `temperature` (float)
- `humidity` (float)
- `battery` (float)
- `latitude` (float, optional)
- `longitude` (float, optional)
- `rssi` (integer)

**Timestamp:** Unix epoch (seconds)

**Retention Policy:**
- 90 days for raw data
- 1 year for downsampled data (hourly aggregates)
- Infinite for freeze events

**Continuous Queries:**
```flux
// Hourly averages
from(bucket: "sensors")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "sensor_data")
  |> aggregateWindow(every: 1h, fn: mean)
  |> to(bucket: "sensors_hourly")

// Freeze event detection
from(bucket: "sensors")
  |> range(start: -1h)
  |> filter(fn: (r) => r._field == "temperature")
  |> filter(fn: (r) => r._value < 2.0)
  |> to(bucket: "freeze_events")
```

---

### Layer 5: Visualization Layer (Grafana)

**Dashboards:**

#### 1. **Main Dashboard**
- Real-time temperature gauge
- Temperature history graph (last 24h)
- Humidity & battery gauges
- Alert history table
- Device status indicators

#### 2. **Freeze Analysis Dashboard** (Future)
- Freeze event timeline
- Freeze severity heatmap
- Multi-dimensional scoring
- Vaccine viability predictions

#### 3. **Fleet Management Dashboard** (Future)
- Multi-device overview
- GPS tracking map
- Device health monitoring
- Battery life predictions

**Alert Rules:**
```
Alert: Critical Freeze
Condition: temperature < 0°C
Frequency: Every 1 minute
Notification: Email + SMS
```

---

## Data Flow

```
1. ESP32 reads sensors (60s interval)
     ↓
2. Device publishes MQTT message to AWS IoT Core
     ↓ (< 500ms)
3. IoT Rule triggers Lambda function
     ↓ (< 200ms)
4. Lambda validates & writes to InfluxDB
     ↓ (< 300ms)
5. Lambda checks alert thresholds
     ↓ (< 100ms)
6. Alert handler sends notifications (if triggered)
     ↓
7. Grafana displays real-time data (10s refresh)

Total latency: < 1.5 seconds
```

---

## Performance Targets

| Metric | Target | Actual |
|--------|--------|--------|
| Alert Latency | < 1.5s | TBD |
| Message Delivery Rate | > 99.8% | TBD |
| Battery Life | > 3 years | TBD |
| Data Loss | < 0.1% | TBD |
| Cost per Unit | ~£3 | TBD |

---

## Scalability

**Current Capacity:**
- Devices: 1 (CT-001)
- Messages/second: 1/60
- Data points/day: 1,440

**Target Capacity:**
- Devices: 1,000
- Messages/second: ~17
- Data points/day: 1,440,000

**Scaling Strategy:**
- AWS IoT Core: Auto-scales (no limit)
- Lambda: Concurrent execution (1,000 default)
- InfluxDB: Horizontal scaling with clustering
- Grafana: Load balancer with multiple instances

---

## Security

### Device Security
- X.509 certificate per device
- Private key stored in secure element
- TLS 1.2 encryption
- Certificate rotation (annual)

### Cloud Security
- IAM roles with least privilege
- VPC isolation (future)
- Encryption at rest (InfluxDB)
- CloudTrail audit logging

### Data Privacy
- No PII collected
- GDPR compliant
- Data retention policies
- Right to erasure support

---

## Monitoring & Observability

**CloudWatch Metrics:**
- Lambda invocation count
- Lambda error rate
- Lambda duration
- IoT message count
- IoT connection failures

**CloudWatch Alarms:**
- Lambda error rate > 1%
- Lambda throttling
- IoT connection failures
- InfluxDB disk usage > 80%

**Logging:**
- Lambda logs → CloudWatch Logs
- IoT logs → CloudWatch Logs
- Application logs → InfluxDB
- Grafana audit logs → file system

---

## Disaster Recovery

**Backup Strategy:**
- InfluxDB: Daily snapshots to S3
- Grafana dashboards: Version control (Git)
- Certificates: Encrypted S3 storage
- Lambda code: Version control (Git)

**Recovery Time Objective (RTO):** 1 hour
**Recovery Point Objective (RPO):** 24 hours

---

## Cost Analysis

### Monthly AWS Costs (1 device)

| Service | Usage | Cost |
|---------|-------|------|
| IoT Core | 43,200 messages/month | ~£0.10 |
| Lambda | 43,200 invocations | ~£0.01 |
| CloudWatch | Logs & metrics | ~£0.50 |
| **Total** | | **~£0.61/month** |

### Hardware Costs (per unit)

| Component | Cost |
|-----------|------|
| ESP32-WROOM-32 | £3.50 |
| TMP112 | £1.20 |
| DS18B20 | £0.80 |
| NEO-6M GPS | £5.00 |
| RC522 RFID | £1.50 |
| SIM800L | £3.00 |
| Battery & misc | £2.00 |
| **Total** | **~£17.00** |

*Note: Target £3/unit achievable with bulk ordering*

---

## Future Enhancements

### Phase 2 (February 2026)
- Multi-device support
- GPS tracking visualization
- RFID vaccine identification
- Advanced freeze scoring

### Phase 3 (March 2026)
- Real ESP32 hardware
- Field testing
- Power optimization
- Over-the-air updates

### Phase 4 (April 2026)
- Machine learning predictions
- Predictive maintenance
- Route optimization
- Integration with vaccine databases

---

## References

- [AWS IoT Core Documentation](https://docs.aws.amazon.com/iot/)
- [InfluxDB Documentation](https://docs.influxdata.com/)
- [Grafana Documentation](https://grafana.com/docs/)
- [ESP32 Technical Reference](https://www.espressif.com/en/support/documents/technical-documents)
