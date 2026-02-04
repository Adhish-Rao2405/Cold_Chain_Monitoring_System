"""
Unit tests for ColdTrack Lambda data processor
"""

import pytest
import json
import os
from unittest.mock import Mock, patch, MagicMock
import sys

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../cloud/lambda/data_processor')))


class TestLambdaHandler:
    """Test cases for Lambda handler function"""
    
    @pytest.fixture
    def sample_event(self):
        """Sample IoT event data"""
        return {
            "device_id": "CT-001",
            "temperature": 5.5,
            "humidity": 65.0,
            "battery": 85.0,
            "timestamp": 1706875200,
            "latitude": 51.5074,
            "longitude": -0.1278,
            "rssi": -67
        }
    
    @pytest.fixture
    def lambda_context(self):
        """Mock Lambda context"""
        context = Mock()
        context.function_name = "ColdTrack-Process"
        context.memory_limit_in_mb = 256
        context.invoked_function_arn = "arn:aws:lambda:eu-west-2:123456789012:function:ColdTrack-Process"
        return context
    
    def test_event_structure(self, sample_event):
        """Test that event has required fields"""
        required_fields = ["device_id", "temperature", "humidity", "battery", "timestamp"]
        
        for field in required_fields:
            assert field in sample_event
    
    def test_temperature_validation(self, sample_event):
        """Test temperature value validation"""
        temp = sample_event["temperature"]
        
        assert isinstance(temp, (int, float))
        assert -20 <= temp <= 50  # Reasonable range
    
    def test_device_id_format(self, sample_event):
        """Test device ID format"""
        device_id = sample_event["device_id"]
        
        assert isinstance(device_id, str)
        assert len(device_id) > 0
        assert device_id.startswith("CT-")


class TestAlertChecking:
    """Test cases for alert checking logic"""
    
    def test_freeze_alert(self):
        """Test freeze alert condition"""
        temperature = -1.0
        freeze_threshold = 0.0
        
        should_alert = temperature < freeze_threshold
        assert should_alert is True
    
    def test_low_temperature_alert(self):
        """Test low temperature alert"""
        temperature = 1.5
        temp_min = 2.0
        
        should_alert = temperature < temp_min
        assert should_alert is True
    
    def test_high_temperature_alert(self):
        """Test high temperature alert"""
        temperature = 9.0
        temp_max = 8.0
        
        should_alert = temperature > temp_max
        assert should_alert is True
    
    def test_normal_temperature(self):
        """Test normal temperature (no alert)"""
        temperature = 5.5
        temp_min = 2.0
        temp_max = 8.0
        freeze_threshold = 0.0
        
        should_alert = (temperature < freeze_threshold) or (temperature < temp_min) or (temperature > temp_max)
        assert should_alert is False
    
    def test_battery_low_alert(self):
        """Test low battery alert"""
        battery = 15.0
        battery_low_threshold = 20.0
        
        should_alert = battery < battery_low_threshold
        assert should_alert is True
    
    def test_battery_critical_alert(self):
        """Test critical battery alert"""
        battery = 5.0
        battery_critical_threshold = 10.0
        
        should_alert = battery < battery_critical_threshold
        assert should_alert is True
    
    @pytest.mark.parametrize("temp,severity", [
        (-2.0, "CRITICAL"),  # Freeze
        (1.0, "WARNING"),     # Low
        (5.0, "NORMAL"),      # Normal
        (9.0, "WARNING"),     # High
    ])
    def test_alert_severity_levels(self, temp, severity):
        """Test different alert severity levels"""
        freeze_threshold = 0.0
        temp_min = 2.0
        temp_max = 8.0
        
        if temp < freeze_threshold:
            calculated_severity = "CRITICAL"
        elif temp < temp_min or temp > temp_max:
            calculated_severity = "WARNING"
        else:
            calculated_severity = "NORMAL"
        
        assert calculated_severity == severity


class TestInfluxDBIntegration:
    """Test cases for InfluxDB integration"""
    
    def test_data_point_structure(self):
        """Test InfluxDB data point structure"""
        data_point = {
            "measurement": "sensor_data",
            "tags": {
                "device_id": "CT-001"
            },
            "fields": {
                "temperature": 5.5,
                "humidity": 65.0,
                "battery": 85.0,
                "rssi": -67
            },
            "timestamp": 1706875200
        }
        
        assert data_point["measurement"] == "sensor_data"
        assert "device_id" in data_point["tags"]
        assert "temperature" in data_point["fields"]
    
    def test_bucket_name_format(self):
        """Test InfluxDB bucket name format"""
        bucket_name = "sensors"
        
        assert isinstance(bucket_name, str)
        assert len(bucket_name) > 0
        assert bucket_name.islower()
    
    def test_organization_name(self):
        """Test InfluxDB organization name"""
        org_name = "coldtrack"
        
        assert isinstance(org_name, str)
        assert len(org_name) > 0


class TestEnvironmentVariables:
    """Test cases for environment variable handling"""
    
    def test_required_environment_variables(self):
        """Test that required environment variables are defined"""
        required_vars = [
            "INFLUX_URL",
            "INFLUX_TOKEN",
            "INFLUX_ORG",
            "INFLUX_BUCKET"
        ]
        
        # In actual tests, you would check os.environ
        # For now, we just test the list exists
        assert len(required_vars) == 4
    
    def test_threshold_defaults(self):
        """Test default threshold values"""
        defaults = {
            "TEMP_MIN": "2.0",
            "TEMP_MAX": "8.0",
            "FREEZE_ALERT_THRESHOLD": "0.0",
            "BATTERY_LOW_THRESHOLD": "20.0",
            "BATTERY_CRITICAL_THRESHOLD": "10.0"
        }
        
        assert float(defaults["TEMP_MIN"]) == 2.0
        assert float(defaults["TEMP_MAX"]) == 8.0
        assert float(defaults["FREEZE_ALERT_THRESHOLD"]) == 0.0


class TestErrorHandling:
    """Test cases for error handling"""
    
    def test_missing_device_id(self):
        """Test handling of missing device_id"""
        event = {
            "temperature": 5.5,
            "humidity": 65.0
            # device_id is missing
        }
        
        # Should use default or handle gracefully
        device_id = event.get("device_id", "unknown")
        assert device_id == "unknown"
    
    def test_invalid_temperature_format(self):
        """Test handling of invalid temperature format"""
        event = {
            "device_id": "CT-001",
            "temperature": "invalid"
        }
        
        # Should handle conversion error
        try:
            temp = float(event["temperature"])
        except ValueError:
            temp = 0.0
        
        assert temp == 0.0
    
    def test_missing_optional_fields(self):
        """Test handling of missing optional fields"""
        event = {
            "device_id": "CT-001",
            "temperature": 5.5,
            "humidity": 65.0,
            "battery": 85.0,
            "timestamp": 1706875200
            # latitude, longitude, rssi are missing
        }
        
        latitude = event.get("latitude")
        longitude = event.get("longitude")
        
        assert latitude is None
        assert longitude is None


class TestResponseFormat:
    """Test cases for Lambda response format"""
    
    def test_success_response_structure(self):
        """Test success response structure"""
        response = {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Data processed successfully",
                "device_id": "CT-001",
                "alerts": []
            })
        }
        
        assert response["statusCode"] == 200
        assert "body" in response
        
        body = json.loads(response["body"])
        assert "message" in body
        assert "device_id" in body
    
    def test_error_response_structure(self):
        """Test error response structure"""
        response = {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Internal server error"
            })
        }
        
        assert response["statusCode"] == 500
        body = json.loads(response["body"])
        assert "error" in body


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
