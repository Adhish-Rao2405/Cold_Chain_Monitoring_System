# ColdTrack - RSV Vaccine Cold Chain Monitoring System

![ColdTrack Architecture](docs/architecture_diagram.png)

**IoT-enabled temperature monitoring system for RSV vaccine transportation with multi-dimensional freeze damage assessment**

## 🎯 Project Overview

ColdTrack is an MSc capstone project addressing vaccine cold chain failures that compromise ~7% of vaccines globally. The system specifically targets RSV vaccine transportation, combining real-time monitoring with AI-powered freeze damage scoring.

### Key Features

- ⚡ **Sub-1.5s alert latency** for critical temperature excursions
- 📊 **Multi-dimensional freeze scoring** (depth, duration, frequency)
- 🔍 **RFID-based vaccine identification** with dynamic thresholds
- 📍 **GPS tracking** for location-aware monitoring
- ☁️ **Cloud-native architecture** with AWS IoT Core
- 💰 **~£3 per unit** cost target for scalability

## 🏗️ Architecture

```
ESP32 Device → AWS IoT Core → Lambda Functions → InfluxDB → Grafana
  (Layer 1)      (Layer 2)       (Layer 3)      (Layer 4)   (Layer 5)
```

### Technology Stack

- **Hardware**: ESP32-WROOM-32, TMP112, DS18B20, NEO-6M GPS, RC522 RFID
- **Connectivity**: SIM800L (GSM/GPRS), MQTT over TLS 1.2
- **Cloud**: AWS IoT Core, Lambda, SNS
- **Database**: InfluxDB 2.x (time-series)
- **Visualization**: Grafana 10.x
- **Languages**: Python 3.11, C (ESP-IDF), Flux

## 🚀 Quick Start

### Prerequisites

```bash
# Install dependencies
python3 --version  # 3.11+
docker --version   # 20.10+
aws --version      # 2.x
```

### 1. Clone & Setup

```bash
git clone https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git
cd Cold_Chain_Monitoring_System
cp config/.env.example .env
```

### 2. Start Local Services

```bash
# Start InfluxDB + Grafana
docker-compose -f config/docker-compose.yml up -d

# Verify services
curl http://localhost:8086/health  # InfluxDB
curl http://localhost:3000          # Grafana
```

### 3. Setup AWS IoT Core

```bash
# Run automated setup
./scripts/setup_aws.sh

# This creates:
# - IoT Thing (CT-001)
# - Device certificates
# - IoT policy
# - IoT rule for Lambda
```

### 4. Deploy Lambda Functions

```bash
./scripts/deploy_lambda.sh
```

### 5. Run Device Simulator

```bash
cd device/simulator
pip install -r requirements.txt
python simulator.py
```

### 6. Access Grafana

Open http://localhost:3000
- Username: `admin`
- Password: `admin`

**You should see live temperature data within 60 seconds! 🎉**

## 📁 Project Structure

```
ColdTrack/
├── device/          # Device code (simulator + ESP32)
├── cloud/           # AWS infrastructure (IoT, Lambda)
├── database/        # InfluxDB schemas & queries
├── visualization/   # Grafana dashboards
├── scripts/         # Setup & deployment scripts
├── tests/           # Test suite
└── docs/            # Documentation
```

See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for detailed structure.

## 🧪 Testing

```bash
# Unit tests
pytest tests/unit/

# Integration tests
pytest tests/integration/

# Test MQTT connection
./scripts/test_connection.sh
```

## 📊 Monitoring

- **Grafana Dashboard**: http://localhost:3000
- **InfluxDB UI**: http://localhost:8086
- **AWS IoT Console**: https://console.aws.amazon.com/iot
- **Lambda Logs**: `aws logs tail /aws/lambda/ColdTrack-Process --follow`

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# AWS Configuration
AWS_REGION=eu-west-2
AWS_ACCOUNT_ID=your_account_id

# InfluxDB Configuration
INFLUX_URL=http://localhost:8086
INFLUX_TOKEN=your_token
INFLUX_ORG=coldtrack
INFLUX_BUCKET=sensors

# Alert Thresholds
TEMP_MIN=2.0
TEMP_MAX=8.0
FREEZE_ALERT_THRESHOLD=0.0
```

### Device Configuration

Edit `device/simulator/config.json`:

```json
{
  "device_id": "CT-001",
  "mqtt_endpoint": "xxxxx.iot.eu-west-2.amazonaws.com",
  "topic": "coldtrack/sensors/CT-001/data",
  "publish_interval": 60,
  "temp_range": [2.0, 8.0]
}
```

## 📚 Documentation

- [Architecture Details](docs/architecture.md)
- [API Reference](docs/api_reference.md)
- [Deployment Guide](docs/deployment_guide.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🎯 Development Roadmap

### Phase 1: Core System (January 2026) ✅
- [x] AWS IoT Core setup
- [x] Device simulator
- [x] Lambda data processor
- [x] InfluxDB integration
- [x] Basic Grafana dashboard

### Phase 2: Enhanced Features (February 2026) 🔄
- [ ] Multi-device support
- [ ] GPS tracking integration
- [ ] RFID vaccine identification
- [ ] Advanced freeze scoring algorithm
- [ ] Email/SMS alerts via SNS

### Phase 3: Hardware Integration (March 2026) 📝
- [ ] ESP32 firmware
- [ ] Sensor integration (TMP112, DS18B20)
- [ ] GSM connectivity (SIM800L)
- [ ] Power optimization
- [ ] Field testing

### Phase 4: Testing & Refinement (April 2026) 📝
- [ ] End-to-end testing
- [ ] Performance optimization
- [ ] Documentation completion
- [ ] Final presentation preparation

## 👥 Team

- **Adhish Rao** - Hardware & Electronics
- **Paul** - AI/ML & Freeze Scoring Algorithm
- **Louis** - Wireless Communication & Cloud Integration
- **Kevin** - Software Development

**Supervisor**: Dr. Akin Delibasi  
**Institution**: University College London  
**Course**: MSc Designing Sensor Systems  
**Deadline**: April 2026

## 📄 License

This project is part of academic coursework at UCL.

## 🙏 Acknowledgments

- UCL Department of Computer Science
- Dr. Akin Delibasi for project supervision
- AWS Educate for cloud credits
- Open-source community for tools and libraries

## 📞 Contact

For questions or collaboration:
- **GitHub**: [@Adhish-Rao2405](https://github.com/Adhish-Rao2405)
- **Project Repository**: [ColdTrack](https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System)

---

**Built with ❤️ for safer vaccine transportation**
