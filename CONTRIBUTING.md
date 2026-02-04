# Contributing to ColdTrack

Thank you for contributing to ColdTrack! This document provides guidelines for team collaboration.

## Team Structure

- **Adhish Rao** - Hardware & Electronics
- **Paul** - AI/ML & Freeze Scoring Algorithm
- **Louis** - Wireless Communication & Cloud Integration
- **Kevin** - Software Development

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Adhish-Rao2405/Cold_Chain_Monitoring_System.git
cd Cold_Chain_Monitoring_System
```

### 2. Set Up Development Environment

```bash
# Install dependencies
pip3 install -r requirements.txt

# Copy environment template
cp config/.env.example .env

# Start local services
docker-compose -f config/docker-compose.yml up -d
```

### 3. Create Your Branch

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Or bugfix branch
git checkout -b bugfix/issue-description
```

## Branch Naming Convention

- `feature/` - New features
- `bugfix/` - Bug fixes
- `hotfix/` - Urgent fixes
- `docs/` - Documentation updates
- `test/` - Test additions/fixes

Examples:
- `feature/gps-integration`
- `bugfix/lambda-timeout`
- `docs/api-reference-update`

## Workflow

### 1. Make Changes

```bash
# Make your changes
# Test locally
# Commit frequently with clear messages
```

### 2. Commit Guidelines

**Format:**
```
<type>: <short summary>

<detailed description>

<references>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code formatting
- `refactor`: Code restructuring
- `test`: Test additions
- `chore`: Maintenance tasks

**Examples:**

```bash
# Good commit message
git commit -m "feat: Add GPS tracking to device simulator

- Integrate NEO-6M GPS module code
- Add latitude/longitude to MQTT messages
- Update Lambda to store GPS data in InfluxDB

Relates to #12"

# Bad commit message
git commit -m "updated stuff"
```

### 3. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create PR on GitHub
# - Describe changes
# - Link related issues
# - Request review from team members
```

### 4. Code Review

- All code must be reviewed by at least one team member
- Address review comments
- Update PR as needed
- Once approved, squash and merge

## Code Standards

### Python Code

```python
# Follow PEP 8
# Use type hints
def process_temperature(temp: float, device_id: str) -> dict:
    """
    Process temperature reading and check alerts.
    
    Args:
        temp: Temperature in Celsius
        device_id: Device identifier
    
    Returns:
        dict: Processing result with alerts
    """
    pass

# Use descriptive variable names
# Add docstrings to functions
# Keep functions small and focused
```

### Shell Scripts

```bash
#!/bin/bash
# Use set -e for error handling
set -e

# Add comments for complex logic
# Use functions for reusability
# Print helpful messages
```

### Documentation

- Update README.md for major changes
- Add/update documentation in `docs/` folder
- Include examples and usage instructions
- Keep docs in sync with code

## Testing

### Run Tests Before Committing

```bash
# Run all tests
pytest tests/ -v

# Run specific test suite
pytest tests/unit/ -v

# Run with coverage
pytest tests/ --cov=device --cov=cloud
```

### Writing Tests

```python
# tests/unit/test_new_feature.py
import pytest

def test_new_feature():
    """Test description"""
    # Arrange
    input_data = {"key": "value"}
    
    # Act
    result = process_data(input_data)
    
    # Assert
    assert result["status"] == "success"
```

## Directory Structure

```
When adding new code:
- Device code → device/
- Lambda functions → cloud/lambda/
- Documentation → docs/
- Tests → tests/unit/ or tests/integration/
- Scripts → scripts/
```

## Communication

### GitHub Issues

Use for:
- Bug reports
- Feature requests
- Questions
- Task tracking

**Template:**
```markdown
## Description
Clear description of the issue

## Steps to Reproduce (for bugs)
1. Step one
2. Step two

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS: macOS/Linux/Windows
- Python version: 3.11
- Other relevant info
```

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Tested locally
- [ ] All tests passing

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No breaking changes (or documented)

## Related Issues
Closes #issue_number
```

## Development Areas

### Hardware (Adhish)

**Focus:**
- ESP32 firmware development
- Sensor integration (TMP112, DS18B20)
- GPS module (NEO-6M)
- RFID reader (RC522)
- Power management

**Files:**
- `device/esp32/`
- Hardware documentation

### AI/ML (Paul)

**Focus:**
- Freeze damage scoring algorithm
- Multi-dimensional analysis
- Predictive models
- Machine learning integration

**Files:**
- `cloud/lambda/freeze_scorer/`
- ML model files

### Wireless/Cloud (Louis)

**Focus:**
- GSM connectivity (SIM800L)
- MQTT optimization
- AWS IoT Core configuration
- Cloud infrastructure

**Files:**
- `cloud/iot/`
- `cloud/lambda/`
- `device/simulator/` (MQTT)

### Software (Kevin)

**Focus:**
- Overall system integration
- Dashboard development
- API endpoints
- Testing framework

**Files:**
- `visualization/`
- `tests/`
- Integration scripts

## Common Tasks

### Adding a New Lambda Function

```bash
# 1. Create directory
mkdir cloud/lambda/your_function

# 2. Add code
# cloud/lambda/your_function/lambda_function.py
# cloud/lambda/your_function/requirements.txt

# 3. Update deployment script
# scripts/deploy_lambda.sh

# 4. Add tests
# tests/unit/test_your_function.py

# 5. Update documentation
# docs/architecture.md
```

### Adding a New Sensor

```bash
# 1. Update simulator
# device/simulator/simulator.py

# 2. Update Lambda processor
# cloud/lambda/data_processor/lambda_function.py

# 3. Update InfluxDB schema
# database/influxdb/schema.flux

# 4. Add to Grafana dashboard
# visualization/dashboards/main_dashboard.json

# 5. Update documentation
```

## Deployment

### Development Environment

- Push to `develop` branch
- Automatic deployment via GitHub Actions
- Test in dev environment first

### Production Environment

- Merge to `main` branch
- Create release tag
- Deploy via CI/CD pipeline
- Monitor CloudWatch metrics

## Getting Help

**Questions?**
- Ask in GitHub Discussions
- Create issue with `question` label
- Contact team members directly

**Bugs?**
- Search existing issues first
- Create new issue with details
- Include error logs and environment info

## Project Timeline

**Phase 1 (January 2026)** ✅
- Core infrastructure
- Device simulator
- Basic monitoring

**Phase 2 (February 2026)** 🔄
- Multi-device support
- Advanced features
- GPS integration

**Phase 3 (March 2026)** 📝
- Hardware integration
- Field testing
- Optimization

**Phase 4 (April 2026)** 📝
- Final testing
- Documentation
- Project presentation

## Resources

- [AWS IoT Core Documentation](https://docs.aws.amazon.com/iot/)
- [InfluxDB Documentation](https://docs.influxdata.com/)
- [Grafana Documentation](https://grafana.com/docs/)
- [ESP32 Documentation](https://docs.espressif.com/)

## License

This project is part of academic coursework at UCL. See [LICENSE](LICENSE) for details.

---

**Thank you for contributing! 🚀**
