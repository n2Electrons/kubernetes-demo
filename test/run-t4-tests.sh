#!/bin/bash

set -e

echo "Running Phase 3 Deployment Validation Tests with pytest..."

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "Cluster not accessible. Starting cluster..."
    ./scripts/setup-cluster.sh
fi

echo "Cluster is accessible"

# Ensure application is deployed
echo "Ensuring application is deployed..."
./scripts/deploy-app.sh

echo "Waiting for deployment to stabilize..."
kubectl wait --for=condition=available --timeout=60s deployment/kub-app -n kub-app

echo "Checking application accessibility..."
if curl -s -H "Host: kub-app.local" http://localhost:8080 > /dev/null; then
    echo "Application is accessible"
else
    echo "Application not accessible, waiting longer..."
    sleep 10
fi

echo "Running comprehensive deployment validation and load tests..."
cd "$(dirname "$0")/.."
python3 -m pytest test/t4-validate-deployment.py -v -s

echo
echo "Generating comprehensive test reports..."
cd "$(dirname "$0")/.."
python3 -c "
import sys
sys.path.append('test')
from test_reporter import generate_comprehensive_report
import os, json

results = []
try:
    if os.path.exists('test/load_test_results.json'):
        with open('test/load_test_results.json', 'r') as f:
            results = json.load(f)
        print(f'Loaded {len(results)} load test results from file')
        os.remove('test/load_test_results.json')  # Cleanup
    else:
        print('No load test results file found, generating basic report')
except Exception as e:
    print(f'Error loading results: {e}')

# Change to test directory for report generation
os.chdir('test')
report_file = generate_comprehensive_report(results)
print(f'Report generated: {report_file}')
"

echo "Deployment validation and load testing complete!"
echo "Check the 'test/reports/' directory for detailed HTML and JSON reports."