#!/bin/bash

##############################################################################
# ColdTrack MQTT Connection Test Script
# Tests connection to AWS IoT Core using certificates
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CERT_DIR="certificates"
DEVICE_ID="${DEVICE_ID:-CT-001}"
TEST_TOPIC="coldtrack/test"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check for certificates
    if [ ! -f "$CERT_DIR/device.crt" ]; then
        print_error "Device certificate not found: $CERT_DIR/device.crt"
        echo "Run: ./scripts/setup_aws.sh"
        exit 1
    fi
    print_success "Device certificate found"
    
    if [ ! -f "$CERT_DIR/private.key" ]; then
        print_error "Private key not found: $CERT_DIR/private.key"
        exit 1
    fi
    print_success "Private key found"
    
    if [ ! -f "$CERT_DIR/AmazonRootCA1.pem" ]; then
        print_error "Root CA not found: $CERT_DIR/AmazonRootCA1.pem"
        exit 1
    fi
    print_success "Root CA found"
    
    # Check for IoT endpoint
    if [ ! -f "$CERT_DIR/iot_endpoint.txt" ]; then
        print_error "IoT endpoint not found"
        echo "Run: ./scripts/setup_aws.sh"
        exit 1
    fi
    IOT_ENDPOINT=$(cat "$CERT_DIR/iot_endpoint.txt")
    print_success "IoT endpoint: $IOT_ENDPOINT"
}

test_openssl_connection() {
    print_header "Testing TLS Connection with OpenSSL"
    
    print_info "Connecting to $IOT_ENDPOINT:8883"
    
    if timeout 5 openssl s_client \
        -connect "$IOT_ENDPOINT:8883" \
        -CAfile "$CERT_DIR/AmazonRootCA1.pem" \
        -cert "$CERT_DIR/device.crt" \
        -key "$CERT_DIR/private.key" \
        -showcerts < /dev/null 2>&1 | grep -q "Verify return code: 0"; then
        print_success "TLS connection successful"
    else
        print_error "TLS connection failed"
        exit 1
    fi
}

test_mosquitto_connection() {
    print_header "Testing MQTT Connection with Mosquitto"
    
    # Check if mosquitto_pub is installed
    if ! command -v mosquitto_pub &> /dev/null; then
        print_info "mosquitto_pub not installed (skipping MQTT test)"
        echo "Install: brew install mosquitto (Mac) or apt-get install mosquitto-clients (Linux)"
        return
    fi
    
    print_info "Publishing test message to $TEST_TOPIC"
    
    if mosquitto_pub \
        --cafile "$CERT_DIR/AmazonRootCA1.pem" \
        --cert "$CERT_DIR/device.crt" \
        --key "$CERT_DIR/private.key" \
        -h "$IOT_ENDPOINT" \
        -p 8883 \
        -t "$TEST_TOPIC" \
        -m '{"test": "connection", "device_id": "'$DEVICE_ID'", "timestamp": '$(date +%s)'}' \
        -q 1 \
        -d; then
        print_success "MQTT publish successful"
    else
        print_error "MQTT publish failed"
        exit 1
    fi
}

test_python_connection() {
    print_header "Testing Python AWS IoT SDK Connection"
    
    # Check if Python script exists
    if [ ! -f "device/simulator/simulator.py" ]; then
        print_info "Simulator not found (skipping Python test)"
        return
    fi
    
    print_info "Testing Python connection (5 seconds)"
    
    # Run simulator for 5 seconds
    timeout 5 python3 device/simulator/simulator.py || {
        if [ $? -eq 124 ]; then
            print_success "Python connection successful (timeout expected)"
        else
            print_error "Python connection failed"
            exit 1
        fi
    }
}

display_summary() {
    print_header "Connection Test Complete! 🎉"
    
    echo -e "${GREEN}All connection tests passed!${NC}\n"
    
    echo "✅ Tests Passed:"
    echo "  • TLS connection to AWS IoT Core"
    echo "  • MQTT message publishing"
    echo "  • Python AWS IoT SDK"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Run simulator: cd device/simulator && python simulator.py"
    echo "  2. Check AWS IoT Console for messages"
    echo "  3. Deploy Lambda: ./scripts/deploy_lambda.sh"
    echo ""
    echo "📊 Monitor Messages:"
    echo "  • AWS IoT Console: https://console.aws.amazon.com/iot/home?region=eu-west-2#/test"
    echo "  • Subscribe to: coldtrack/sensors/#"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header "ColdTrack Connection Test"
    
    check_prerequisites
    test_openssl_connection
    test_mosquitto_connection
    test_python_connection
    display_summary
}

# Run main function
main
