#!/usr/bin/env python3
"""
ColdTrack Device Simulator
Simulates an ESP32-based temperature monitoring device
Publishes data to AWS IoT Core via MQTT
"""

import json
import time
import random
import argparse
import sys
from datetime import datetime
from pathlib import Path

try:
    from awscrt import io, mqtt
    from awsiot import mqtt_connection_builder
except ImportError:
    print("❌ Error: AWS IoT SDK not installed")
    print("Run: pip install awsiotsdk")
    sys.exit(1)


class ColdTrackSimulator:
    """Simulates a ColdTrack temperature monitoring device"""
    
    def __init__(self, config_path="config.json"):
        """Initialize simulator with configuration"""
        self.config = self._load_config(config_path)
        self.mqtt_connection = None
        self.is_connected = False
        
    def _load_config(self, config_path):
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
            print(f"✅ Configuration loaded from {config_path}")
            return config
        except FileNotFoundError:
            print(f"❌ Config file not found: {config_path}")
            print("📝 Using default configuration")
            return self._default_config()
    
    def _default_config(self):
        """Return default configuration"""
        return {
            "device_id": "CT-001",
            "mqtt_endpoint": "REPLACE_WITH_YOUR_IOT_ENDPOINT",
            "topic_prefix": "coldtrack/sensors",
            "publish_interval": 60,
            "temp_range": [2.0, 8.0],
            "temp_variation": 2.0,
            "humidity_range": [50.0, 70.0],
            "humidity_variation": 10.0,
            "battery_initial": 100.0,
            "battery_drain_rate": 0.001,
            "certificates": {
                "root_ca": "../../certificates/AmazonRootCA1.pem",
                "device_cert": "../../certificates/device.crt",
                "private_key": "../../certificates/private.key"
            }
        }
    
    def connect(self):
        """Establish MQTT connection to AWS IoT Core"""
        print(f"\n🔌 Connecting to AWS IoT Core...")
        print(f"   Device: {self.config['device_id']}")
        print(f"   Endpoint: {self.config['mqtt_endpoint']}")
        
        try:
            # Create MQTT connection
            self.mqtt_connection = mqtt_connection_builder.mtls_from_path(
                endpoint=self.config['mqtt_endpoint'],
                cert_filepath=self.config['certificates']['device_cert'],
                pri_key_filepath=self.config['certificates']['private_key'],
                client_bootstrap=io.ClientBootstrap(
                    io.EventLoopGroup(1),
                    io.DefaultHostResolver(io.EventLoopGroup(1))
                ),
                ca_filepath=self.config['certificates']['root_ca'],
                client_id=self.config['device_id'],
                clean_session=False,
                keep_alive_secs=30
            )
            
            # Connect
            connect_future = self.mqtt_connection.connect()
            connect_future.result()
            self.is_connected = True
            print("✅ Connected to AWS IoT Core!\n")
            
        except Exception as e:
            print(f"❌ Connection failed: {str(e)}")
            print("\n💡 Troubleshooting:")
            print("   1. Check your IoT endpoint in config.json")
            print("   2. Verify certificate paths are correct")
            print("   3. Ensure certificates are valid and attached to IoT policy")
            sys.exit(1)
    
    def generate_sensor_data(self):
        """Generate realistic sensor data"""
        # Temperature with some randomness
        temp_base = random.uniform(
            self.config['temp_range'][0],
            self.config['temp_range'][1]
        )
        temperature = round(
            temp_base + random.uniform(
                -self.config['temp_variation'],
                self.config['temp_variation']
            ),
            2
        )
        
        # Humidity
        humidity = round(
            random.uniform(
                self.config['humidity_range'][0],
                self.config['humidity_range'][1]
            ) + random.uniform(
                -self.config['humidity_variation'],
                self.config['humidity_variation']
            ),
            2
        )
        
        # Battery (slowly draining)
        if not hasattr(self, 'battery_level'):
            self.battery_level = self.config['battery_initial']
        self.battery_level -= self.config['battery_drain_rate']
        self.battery_level = max(0.0, self.battery_level)
        
        # Simulate occasional freeze events for testing
        if random.random() < 0.05:  # 5% chance
            temperature = round(random.uniform(-2.0, 1.0), 2)
            print("🧊 Simulating freeze event!")
        
        return {
            "device_id": self.config['device_id'],
            "temperature": temperature,
            "humidity": humidity,
            "battery": round(self.battery_level, 2),
            "timestamp": int(time.time()),
            "latitude": 51.5074 + random.uniform(-0.01, 0.01),  # London area
            "longitude": -0.1278 + random.uniform(-0.01, 0.01),
            "rssi": random.randint(-90, -50),  # Signal strength
            "message_id": int(time.time() * 1000)
        }
    
    def publish_data(self, data):
        """Publish sensor data to AWS IoT Core"""
        topic = f"{self.config['topic_prefix']}/{self.config['device_id']}/data"
        
        try:
            self.mqtt_connection.publish(
                topic=topic,
                payload=json.dumps(data),
                qos=mqtt.QoS.AT_LEAST_ONCE
            )
            
            # Display published data
            temp_color = "🔴" if data['temperature'] < 2.0 else "🟢"
            print(f"{temp_color} [{datetime.now().strftime('%H:%M:%S')}] "
                  f"Temp: {data['temperature']:+.2f}°C | "
                  f"Humidity: {data['humidity']:.1f}% | "
                  f"Battery: {data['battery']:.1f}%")
            
            if data['temperature'] < 2.0:
                print(f"   ⚠️  FREEZE ALERT: {data['temperature']}°C")
            elif data['temperature'] > 8.0:
                print(f"   ⚠️  HIGH TEMP ALERT: {data['temperature']}°C")
                
        except Exception as e:
            print(f"❌ Publish failed: {str(e)}")
    
    def run(self):
        """Main simulation loop"""
        print("\n" + "="*60)
        print("🌡️  ColdTrack Device Simulator")
        print("="*60)
        print(f"Device ID: {self.config['device_id']}")
        print(f"Publish Interval: {self.config['publish_interval']}s")
        print(f"Temperature Range: {self.config['temp_range'][0]}°C to {self.config['temp_range'][1]}°C")
        print("="*60 + "\n")
        
        self.connect()
        
        print("📊 Publishing data... (Press Ctrl+C to stop)\n")
        
        try:
            while True:
                data = self.generate_sensor_data()
                self.publish_data(data)
                time.sleep(self.config['publish_interval'])
                
        except KeyboardInterrupt:
            print("\n\n⏹️  Stopping simulator...")
            self.disconnect()
    
    def disconnect(self):
        """Disconnect from AWS IoT Core"""
        if self.mqtt_connection and self.is_connected:
            print("🔌 Disconnecting from AWS IoT Core...")
            disconnect_future = self.mqtt_connection.disconnect()
            disconnect_future.result()
            print("✅ Disconnected successfully")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='ColdTrack Device Simulator'
    )
    parser.add_argument(
        '--config',
        default='config.json',
        help='Path to configuration file (default: config.json)'
    )
    parser.add_argument(
        '--interval',
        type=int,
        help='Override publish interval in seconds'
    )
    
    args = parser.parse_args()
    
    # Create and run simulator
    simulator = ColdTrackSimulator(args.config)
    
    # Override interval if specified
    if args.interval:
        simulator.config['publish_interval'] = args.interval
    
    simulator.run()


if __name__ == "__main__":
    main()
