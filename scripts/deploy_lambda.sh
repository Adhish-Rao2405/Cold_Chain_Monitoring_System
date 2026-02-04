#!/bin/bash

##############################################################################
# ColdTrack Lambda Deployment Script
# Packages and deploys Lambda functions to AWS
##############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Configuration
REGION="${AWS_REGION:-eu-west-2}"
LAMBDA_DIR="cloud/lambda"
LAMBDA_NAME="ColdTrack-Process"
LAMBDA_HANDLER="lambda_function.lambda_handler"
LAMBDA_RUNTIME="python3.11"
LAMBDA_TIMEOUT="${LAMBDA_TIMEOUT:-30}"
LAMBDA_MEMORY="${LAMBDA_MEMORY:-256}"

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
        exit 1
    fi
    print_success "AWS CLI installed"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    print_success "Python 3 installed"
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed"
        exit 1
    fi
    print_success "pip3 installed"
}

create_lambda_role() {
    print_header "Creating Lambda Execution Role"
    
    ROLE_NAME="ColdTrackLambdaRole"
    
    # Check if role exists
    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        print_info "Role already exists"
        ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    else
        # Create trust policy
        cat > /tmp/trust_policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
        
        # Create role
        print_info "Creating IAM role: $ROLE_NAME"
        ROLE_ARN=$(aws iam create-role \
            --role-name "$ROLE_NAME" \
            --assume-role-policy-document file:///tmp/trust_policy.json \
            --query 'Role.Arn' \
            --output text)
        
        # Attach basic execution policy
        aws iam attach-role-policy \
            --role-name "$ROLE_NAME" \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        
        print_success "Role created: $ROLE_ARN"
        
        # Wait for role to propagate
        print_info "Waiting for role to propagate (10 seconds)..."
        sleep 10
    fi
    
    echo "$ROLE_ARN"
}

package_lambda() {
    print_header "Packaging Lambda Function"
    
    LAMBDA_SOURCE="$LAMBDA_DIR/data_processor"
    PACKAGE_DIR="/tmp/coldtrack_lambda"
    
    # Clean up old package
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    
    # Copy Lambda function
    print_info "Copying Lambda function"
    cp "$LAMBDA_SOURCE/lambda_function.py" "$PACKAGE_DIR/"
    
    # Install dependencies
    if [ -f "$LAMBDA_SOURCE/requirements.txt" ]; then
        print_info "Installing dependencies"
        pip3 install -r "$LAMBDA_SOURCE/requirements.txt" -t "$PACKAGE_DIR/" --quiet
    fi
    
    # Create deployment package
    print_info "Creating deployment package"
    cd "$PACKAGE_DIR"
    zip -r /tmp/lambda_function.zip . > /dev/null
    cd - > /dev/null
    
    print_success "Lambda package created: /tmp/lambda_function.zip"
}

deploy_lambda() {
    print_header "Deploying Lambda Function"
    
    ROLE_ARN=$1
    
    # Check if function exists
    if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" &> /dev/null; then
        print_info "Updating existing Lambda function"
        
        aws lambda update-function-code \
            --function-name "$LAMBDA_NAME" \
            --zip-file fileb:///tmp/lambda_function.zip \
            --region "$REGION" \
            > /dev/null
        
        # Update configuration
        aws lambda update-function-configuration \
            --function-name "$LAMBDA_NAME" \
            --timeout "$LAMBDA_TIMEOUT" \
            --memory-size "$LAMBDA_MEMORY" \
            --environment Variables="{
                INFLUX_URL=${INFLUX_URL},
                INFLUX_TOKEN=${INFLUX_TOKEN},
                INFLUX_ORG=${INFLUX_ORG},
                INFLUX_BUCKET=${INFLUX_BUCKET},
                TEMP_MIN=${TEMP_MIN},
                TEMP_MAX=${TEMP_MAX},
                FREEZE_ALERT_THRESHOLD=${FREEZE_ALERT_THRESHOLD},
                BATTERY_LOW_THRESHOLD=${BATTERY_LOW_THRESHOLD},
                BATTERY_CRITICAL_THRESHOLD=${BATTERY_CRITICAL_THRESHOLD}
            }" \
            --region "$REGION" \
            > /dev/null
        
        print_success "Lambda function updated"
    else
        print_info "Creating new Lambda function"
        
        aws lambda create-function \
            --function-name "$LAMBDA_NAME" \
            --runtime "$LAMBDA_RUNTIME" \
            --role "$ROLE_ARN" \
            --handler "$LAMBDA_HANDLER" \
            --zip-file fileb:///tmp/lambda_function.zip \
            --timeout "$LAMBDA_TIMEOUT" \
            --memory-size "$LAMBDA_MEMORY" \
            --environment Variables="{
                INFLUX_URL=${INFLUX_URL},
                INFLUX_TOKEN=${INFLUX_TOKEN},
                INFLUX_ORG=${INFLUX_ORG},
                INFLUX_BUCKET=${INFLUX_BUCKET},
                TEMP_MIN=${TEMP_MIN},
                TEMP_MAX=${TEMP_MAX},
                FREEZE_ALERT_THRESHOLD=${FREEZE_ALERT_THRESHOLD},
                BATTERY_LOW_THRESHOLD=${BATTERY_LOW_THRESHOLD},
                BATTERY_CRITICAL_THRESHOLD=${BATTERY_CRITICAL_THRESHOLD}
            }" \
            --region "$REGION" \
            > /dev/null
        
        print_success "Lambda function created"
    fi
    
    # Get Lambda ARN
    LAMBDA_ARN=$(aws lambda get-function \
        --function-name "$LAMBDA_NAME" \
        --region "$REGION" \
        --query 'Configuration.FunctionArn' \
        --output text)
    
    echo "$LAMBDA_ARN"
}

create_iot_rule() {
    print_header "Creating IoT Rule"
    
    LAMBDA_ARN=$1
    RULE_NAME="ProcessData"
    
    # Add Lambda permission for IoT
    print_info "Adding Lambda permission for IoT"
    aws lambda add-permission \
        --function-name "$LAMBDA_NAME" \
        --statement-id "IoTInvoke" \
        --action "lambda:InvokeFunction" \
        --principal iot.amazonaws.com \
        --region "$REGION" \
        > /dev/null 2>&1 || print_info "Permission already exists"
    
    # Check if rule exists
    if aws iot get-topic-rule --rule-name "$RULE_NAME" --region "$REGION" &> /dev/null; then
        print_info "Deleting existing IoT rule"
        aws iot delete-topic-rule --rule-name "$RULE_NAME" --region "$REGION"
    fi
    
    # Create rule
    print_info "Creating IoT rule: $RULE_NAME"
    
    cat > /tmp/iot_rule.json << EOF
{
  "sql": "SELECT * FROM 'coldtrack/sensors/+/data'",
  "actions": [
    {
      "lambda": {
        "functionArn": "$LAMBDA_ARN"
      }
    }
  ],
  "ruleDisabled": false
}
EOF
    
    aws iot create-topic-rule \
        --rule-name "$RULE_NAME" \
        --topic-rule-payload file:///tmp/iot_rule.json \
        --region "$REGION"
    
    print_success "IoT rule created: $RULE_NAME"
}

display_summary() {
    print_header "Deployment Complete! 🎉"
    
    echo -e "${GREEN}Lambda function deployed successfully!${NC}\n"
    
    echo "📋 Configuration:"
    echo "  • Function: $LAMBDA_NAME"
    echo "  • Runtime: $LAMBDA_RUNTIME"
    echo "  • Timeout: ${LAMBDA_TIMEOUT}s"
    echo "  • Memory: ${LAMBDA_MEMORY}MB"
    echo "  • Region: $REGION"
    echo ""
    echo "🔗 AWS Console Links:"
    echo "  • Lambda: https://console.aws.amazon.com/lambda/home?region=$REGION#/functions/$LAMBDA_NAME"
    echo "  • IoT Rules: https://console.aws.amazon.com/iot/home?region=$REGION#/rulehub"
    echo ""
    echo "🧪 Test Lambda:"
    echo "  aws lambda invoke --function-name $LAMBDA_NAME --region $REGION output.json"
    echo ""
    echo "📊 View Logs:"
    echo "  aws logs tail /aws/lambda/$LAMBDA_NAME --follow --region $REGION"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    print_header "ColdTrack Lambda Deployment"
    
    check_prerequisites
    ROLE_ARN=$(create_lambda_role)
    package_lambda
    LAMBDA_ARN=$(deploy_lambda "$ROLE_ARN")
    create_iot_rule "$LAMBDA_ARN"
    display_summary
}

# Run main function
main
