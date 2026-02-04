"""
ColdTrack Data Processor Lambda
Processes incoming sensor data from AWS IoT Core
Stores data in InfluxDB and triggers alerts if needed
"""

import json
import os
from datetime import datetime
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS


def lambda_handler(event, context):
    """
    Lambda handler for processing sensor data
    
    Args:
        event: Sensor data from AWS IoT Core
        context: Lambda context object
    
    Returns:
        dict: Response with status code and message
    """
    
    print(f"📥 Received event: {json.dumps(event)}")
    
    try:
        # Extract sensor data
        device_id = event.get('device_id', 'unknown')
        temperature = float(event.get('temperature', 0))
        humidity = float(event.get('humidity', 0))
        battery = float(event.get('battery', 100))
        timestamp = int(event.get('timestamp', datetime.now().timestamp()))
        latitude = event.get('latitude')
        longitude = event.get('longitude')
        rssi = event.get('rssi', 0)
        
        # Connect to InfluxDB
        client = InfluxDBClient(
            url=os.environ.get('INFLUX_URL', 'http://localhost:8086'),
            token=os.environ['INFLUX_TOKEN'],
            org=os.environ.get('INFLUX_ORG', 'coldtrack')
        )
        
        # Create data point
        point = Point("sensor_data") \
            .tag("device_id", device_id) \
            .field("temperature", temperature) \
            .field("humidity", humidity) \
            .field("battery", battery) \
            .field("rssi", rssi)
        
        # Add GPS coordinates if available
        if latitude and longitude:
            point.field("latitude", float(latitude))
            point.field("longitude", float(longitude))
        
        point.time(timestamp, WritePrecision.S)
        
        # Write to InfluxDB
        bucket = os.environ.get('INFLUX_BUCKET', 'sensors')
        write_api = client.write_api(write_options=SYNCHRONOUS)
        write_api.write(bucket=bucket, record=point)
        
        print(f"✅ Data written to InfluxDB: {device_id} - {temperature}°C")
        
        # Check for alerts
        alerts = check_alerts(device_id, temperature, humidity, battery)
        
        if alerts:
            print(f"⚠️  Alerts triggered: {alerts}")
            # Here you would invoke alert_handler Lambda or send SNS notification
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Data processed successfully',
                'device_id': device_id,
                'alerts': alerts
            })
        }
        
    except Exception as e:
        print(f"❌ Error processing data: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
    finally:
        if 'client' in locals():
            client.close()


def check_alerts(device_id, temperature, humidity, battery):
    """
    Check if any alert conditions are met
    
    Args:
        device_id: Device identifier
        temperature: Current temperature in Celsius
        humidity: Current humidity percentage
        battery: Battery level percentage
    
    Returns:
        list: List of alert messages
    """
    alerts = []
    
    # Temperature thresholds
    temp_min = float(os.environ.get('TEMP_MIN', 2.0))
    temp_max = float(os.environ.get('TEMP_MAX', 8.0))
    freeze_threshold = float(os.environ.get('FREEZE_ALERT_THRESHOLD', 0.0))
    
    # Check temperature alerts
    if temperature < freeze_threshold:
        alerts.append({
            'type': 'FREEZE',
            'severity': 'CRITICAL',
            'message': f'Freeze alert! Temperature: {temperature}°C',
            'device_id': device_id
        })
    elif temperature < temp_min:
        alerts.append({
            'type': 'LOW_TEMP',
            'severity': 'WARNING',
            'message': f'Temperature below minimum: {temperature}°C (Min: {temp_min}°C)',
            'device_id': device_id
        })
    elif temperature > temp_max:
        alerts.append({
            'type': 'HIGH_TEMP',
            'severity': 'WARNING',
            'message': f'Temperature above maximum: {temperature}°C (Max: {temp_max}°C)',
            'device_id': device_id
        })
    
    # Check battery alerts
    battery_low_threshold = float(os.environ.get('BATTERY_LOW_THRESHOLD', 20.0))
    battery_critical_threshold = float(os.environ.get('BATTERY_CRITICAL_THRESHOLD', 10.0))
    
    if battery < battery_critical_threshold:
        alerts.append({
            'type': 'BATTERY_CRITICAL',
            'severity': 'CRITICAL',
            'message': f'Critical battery level: {battery}%',
            'device_id': device_id
        })
    elif battery < battery_low_threshold:
        alerts.append({
            'type': 'BATTERY_LOW',
            'severity': 'WARNING',
            'message': f'Low battery level: {battery}%',
            'device_id': device_id
        })
    
    # Check humidity (optional)
    humidity_min = float(os.environ.get('HUMIDITY_MIN', 30.0))
    humidity_max = float(os.environ.get('HUMIDITY_MAX', 80.0))
    
    if humidity < humidity_min or humidity > humidity_max:
        alerts.append({
            'type': 'HUMIDITY_ALERT',
            'severity': 'INFO',
            'message': f'Humidity out of range: {humidity}%',
            'device_id': device_id
        })
    
    return alerts
