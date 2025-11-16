#!/bin/bash

# Generate load using existing test cases
echo "Generating load using test cases for dynamic Grafana dashboards..."

# Function to run continuous tests
run_continuous_tests() {
    local test_file=$1
    local iterations=$2
    
    echo "Running $test_file $iterations times with load generation..."
    for i in $(seq 1 $iterations); do
        echo "Iteration $i/$iterations - Running $test_file"
        
        # Add some load generation alongside tests
        if [[ "$test_file" == *"t3-nginx"* ]]; then
            # For nginx tests, also create HTTP traffic
            kubectl run traffic-gen-$i --image=busybox --restart=Never --rm -- sh -c "
            for j in {1..20}; do 
                wget -q -O- http://nginx-service.default.svc.cluster.local/ 2>/dev/null || true
                sleep 0.1
            done" 2>/dev/null &
        elif [[ "$test_file" == *"t4-validate"* ]]; then
            # For deployment tests, add scaling activity
            kubectl scale deployment nginx-deployment --replicas=$((i % 3 + 1)) >/dev/null 2>&1 &
        fi
        
        python3 -m pytest $test_file -v --tb=no -q
        sleep 3
    done
}

# Function to run parallel test load
run_parallel_tests() {
    echo "Running parallel test load with sustained activity..."
    
    # Create background continuous load
    echo "Starting continuous background tests..."
    
    # Continuous infrastructure checks (every 10 seconds)
    (while true; do 
        python3 -m pytest test/t1-infrastructure.py -v --tb=no -q >/dev/null 2>&1
        sleep 10
    done) &
    INFRA_PID=$!
    
    # Continuous nginx access tests (every 5 seconds) 
    (while true; do 
        python3 -m pytest test/t3-nginx-access.py -v --tb=no -q >/dev/null 2>&1
        sleep 5
    done) &
    NGINX_PID=$!
    
    # Deployment scaling activity (every 15 seconds)
    (while true; do 
        kubectl scale deployment nginx-deployment --replicas=3 >/dev/null 2>&1
        sleep 8
        kubectl scale deployment nginx-deployment --replicas=1 >/dev/null 2>&1
        sleep 7
    done) &
    SCALE_PID=$!
    
    # Pod creation/deletion activity
    (while true; do 
        kubectl run test-load-pod-$(date +%s) --image=busybox --restart=Never -- sleep 30 >/dev/null 2>&1
        sleep 10
        kubectl delete pod -l run --timeout=5s >/dev/null 2>&1
        sleep 5
    done) &
    POD_PID=$!
    
    echo "Background load generators started:"
    echo "  - Infrastructure checks (PID: $INFRA_PID)"
    echo "  - Nginx access tests (PID: $NGINX_PID)" 
    echo "  - Deployment scaling (PID: $SCALE_PID)"
    echo "  - Pod lifecycle (PID: $POD_PID)"
    echo ""
    echo "Load will run for 2 minutes..."
    echo "Watch your Grafana dashboards now!"
    
    # Let it run for 2 minutes
    sleep 120
    
    echo "Stopping load generators..."
    kill $INFRA_PID $NGINX_PID $SCALE_PID $POD_PID 2>/dev/null
    
    # Clean up test pods
    kubectl delete pod -l run --timeout=10s >/dev/null 2>&1
    
    echo "Parallel test execution completed"
}

# Menu options
echo ""
echo "Choose load generation method:"
echo "1. Continuous infrastructure tests (t1) - generates cluster activity"
echo "2. Continuous nginx tests (t3) - generates HTTP traffic and pod activity"
echo "3. Continuous deployment tests (t4) - generates deployment/scaling activity"
echo "4. All monitoring tests (t8+t9) - generates comprehensive monitoring data"
echo "5. Parallel mixed tests - runs multiple test types simultaneously"
echo "6. Full test suite loop - runs all tests in sequence repeatedly"

read -p "Select option (1-6): " choice

case $choice in
    1)
        echo "Running infrastructure tests continuously..."
        run_continuous_tests "test/t1-infrastructure.py" 10
        ;;
    2)
        echo "Running nginx access tests continuously..."
        run_continuous_tests "test/t3-nginx-access.py" 15
        ;;
    3)
        echo "Running deployment validation tests continuously..."
        run_continuous_tests "test/t4-validate-deployment.py" 12
        ;;
    4)
        echo "Running monitoring tests continuously..."
        run_continuous_tests "test/t8-monitoring-tests.py" 8
        run_continuous_tests "test/t9-monitoring-status-tests.py" 8
        ;;
    5)
        echo "Running sustained parallel load..."
        echo "This will generate continuous activity for 2 minutes."
        echo "Go to Grafana now and watch the dashboards update!"
        echo ""
        run_parallel_tests
        ;;
    6)
        echo "Running full test suite loop..."
        for i in {1..3}; do
            echo "Full suite iteration $i/3"
            python3 -m pytest test/t1-infrastructure.py test/t3-nginx-access.py test/t4-validate-deployment.py test/t8-monitoring-tests.py -v --tb=no
            sleep 3
        done
        ;;
    *)
        echo "Invalid option. Running default mixed load..."
        run_parallel_tests
        ;;
esac

echo ""
echo "Test-based load generation completed!"
echo ""
echo "Check your Grafana dashboards now:"
echo "- Dashboard 315: Overall cluster activity from infrastructure tests"
echo "- Dashboard 747: Deployment activity from validation tests" 
echo "- Dashboard 6336: Pod activity from nginx tests"
echo "- Dashboard 3662: Prometheus activity from monitoring tests"
echo ""
echo "Set Grafana time range to 'Last 15 minutes' and refresh rate to 5s for best results."