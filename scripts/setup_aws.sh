#!/bin/bash

##############################################################################
# ColdTrack AWS IoT Core Setup Script
# This script automates the setup of AWS IoT Core infrastructure
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEVICE_ID="${DEVICE_ID:-CT-001}"
REGION="${AWS_REGION:-eu-west-2}"
POLICY_NAME="ColdTrackPolicy"
RULE_NAME="ProcessData"
LAMBDA_NAME="ColdTrack-Process"
CERT_DIR="certificates"

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
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo "Install: https://aws.amazon.com/cli/"
        exit 1
    fi
    print_success "AWS CLI installed"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        echo "Run: aws configure"
        exit 1
    fi
    print_success "AWS credentials configured"
    
    # Check jq for JSON parsing
    if ! command -v jq &> /dev/null; then
        print_info "jq not installed (optional but recommended)"
        echo "Install: brew install jq (Mac) or apt-get install jq (Linux)"
    else
        print_success "jq installed"
    fi
}

create_certificates() {
    print_header "Creating Device Certificates"
    
    # Create certificates directory
    mkdir -p "$CERT_DIR"
    cd "$CERT_DIR"
    
    # Generate certificates
    print_info "Generating certificates for device: $DEVICE_ID"
    
    CERT_OUTPUT=$(aws iot create-keys-and-certificate \
        --set-as-active \
        --certificate-pem-outfile device.crt \
        --private-key-outfile private.key \
        --public-key-outfile public.key \
        --region "$REGION" \
        --output json)
    
    CERT_ARN=$(echo "$CERT_OUTPUT" | jq -r '.certificateArn')
    
    if [ -z "$CERT_ARN" ]; then
        print_error "Failed to create certificates"
        exit 1
    fi
    
    print_success "Certificates created"
    echo "Certificate ARN: $CERT_ARN"
    
    # Save certificate ARN
    echo "$CERT_ARN" > cert_arn.txt
    
    # Download root CA
    print_info "Downloading Amazon Root CA"
    wget -q https://www.amazontrust.com/repository/AmazonRootCA1.pem
    print_success "Root CA downloaded"
    
    cd ..
    
    echo "$CERT_ARN"
}

create_iot_thing() {
    print_header "Creating IoT Thing"
    
    # Create thing
    print_info "Creating IoT Thing: $DEVICE_ID"
    
    aws iot create-thing \
        --thing-name "$DEVICE_ID" \
        --region "$REGION" \
        > /dev/null 2>&1 || {
            print_info "Thing already exists, continuing..."
        }
    
    print_success "IoT Thing created: $DEVICE_ID"
}

create_iot_policy() {
    print_header "Creating IoT Policy"
    
    # Create policy document
    cat > /tmp/iot_policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iot:Connect",
        "iot:Publish",
        "iot:Subscribe",
        "iot:Receive"
      ],
      "Resource": "*"
    }
  ]
}
EOF
    
    # Create policy
    print_info "Creating IoT policy: $POLICY_NAME"
    
    aws iot create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/iot_policy.json \
        --region "$REGION" \
        > /dev/null 2>&1 || {
            print_info "Policy already exists, continuing..."
        }
    
    print_success "IoT Policy created: $POLICY_NAME"
}

attach_policy() {
    print_header "Attaching Policy to Certificate"
    
    CERT_ARN=$(cat "$CERT_DIR/cert_arn.txt")
    
    print_info "Attaching policy to certificate"
    
    aws iot attach-policy \
        --policy-name "$POLICY_NAME" \
        --target "$CERT_ARN" \
        --region "$REGION"
    
    print_success "Policy attached to certificate"
}

attach_thing() {
    print_header "Attaching Certificate to Thing"
    
    CERT_ARN=$(cat "$CERT_DIR/cert_arn.txt")
    
    print_info "Attaching certificate to thing"
    
    aws iot attach-thing-principal \
        --thing-name "$DEVICE_ID" \
        --principal "$CERT_ARN" \
        --region "$REGION"
    
    print_success "Certificate attached to thing"
}

get_iot_endpoint() {
    print_header "Getting IoT Endpoint"
    
    IOT_ENDPOINT=$(aws iot describe-endpoint \
        --endpoint-type iot:Data-ATS \
        --region "$REGION" \
        --output text)
    
    print_success "IoT Endpoint: $IOT_ENDPOINT"
    
    # Save endpoint to file
    echo "$IOT_ENDPOINT" > "$CERT_DIR/iot_endpoint.txt"
    
    echo "$IOT_ENDPOINT"
}

update_simulator_config() {
    print_header "Updating Simulator Configuration"
    
    IOT_ENDPOINT=$(cat "$CERT_DIR/iot_endpoint.txt")
    CONFIG_FILE="device/simulator/config.json"
    
    if [ -f "$CONFIG_FILE" ]; then
        print_info "Updating $CONFIG_FILE with IoT endpoint"
        
        # Update endpoint in config
        sed -i.bak "s|REPLACE_WITH_YOUR_IOT_ENDPOINT|$IOT_ENDPOINT|g" "$CONFIG_FILE"
        
        print_success "Simulator config updated"
    else
        print_error "Config file not found: $CONFIG_FILE"
    fi
}

display_summary() {
    print_header "Setup Complete! 🎉"
    
    IOT_ENDPOINT=$(cat "$CERT_DIR/iot_endpoint.txt")
    
    echo -e "${GREEN}Your AWS IoT Core infrastructure is ready!${NC}\n"
    
    echo "📋 Configuration Details:"
    echo "  • Device ID: $DEVICE_ID"
    echo "  • Region: $REGION"
    echo "  • IoT Endpoint: $IOT_ENDPOINT"
    echo "  • Policy: $POLICY_NAME"
    echo ""
    echo "📁 Certificates saved in: $CERT_DIR/"
    echo "  • device.crt"
    echo "  • private.key"
    echo "  • public.key"
    echo "  • AmazonRootCA1.pem"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Test connection: ./scripts/test_connection.sh"
    echo "  2. Run simulator: cd device/simulator && python simulator.py"
    echo "  3. Deploy Lambda: ./scripts/deploy_lambda.sh"
    echo ""
    print_info "Keep your certificates secure and never commit them to Git!"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header "ColdTrack AWS IoT Core Setup"
    
    check_prerequisites
    CERT_ARN=$(create_certificates)
    create_iot_thing
    create_iot_policy
    attach_policy
    attach_thing
    get_iot_endpoint
    update_simulator_config
    display_summary
}

# Run main function
main
