#!/bin/bash

set -e

echo "=== Kubernetes Test Suite Report Generator ==="
echo

# Determine if we're running from test directory or project root
if [[ "$(basename "$PWD")" == "test" ]]; then
    cd ..
fi

# Create reports directory
mkdir -p test/reports

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cluster not accessible. Run ./scripts/setup-cluster.sh first"
    exit 1
fi

echo "Cluster is accessible"

# Ensure application is deployed
echo "Ensuring application is deployed..."
./scripts/deploy-app.sh > /dev/null 2>&1

echo "Waiting for deployment to stabilize..."
kubectl wait --for=condition=available --timeout=60s deployment/kub-app -n kub-app > /dev/null

echo "Running test suite with report generation..."

# Run the instrumented test suite from the test directory
cd test
python3 t4-validate-deployment.py

echo
echo "=== Report Generation Complete ==="
echo
echo "Available reports in ./test/reports/ directory:"
ls -la reports/*.html reports/*.json 2>/dev/null || echo "No report files found"

echo
echo "To view the HTML report:"
echo "  - Open test/reports/deployment_report_*.html in your browser"
echo "  - Or run: xdg-open test/reports/deployment_report_*.html"