#!/bin/bash

# Generate load using existing test cases
echo "Generating load using test cases for dynamic Grafana dashboards..."

# Function to run tests in loop
run_continuous_tests() {
    local test_file=$1
    local iterations=$2
    
    echo "Running $test_file $iterations times..."
    for i in $(seq 1 $iterations); do
        echo "Iteration $i/$iterations - Running $test_file"
        python3 -m pytest $test_file -v --tb=no -q
        sleep 2
    done
}

# Function to run parallel test load
run_parallel_tests() {
    echo "Running parallel test load..."
    
    # Run infrastructure tests
    python3 -m pytest test/t1-infrastructure.py -v --tb=no &
    PID1=$!
    
    # Run nginx tests
    python3 -m pytest test/t3-nginx-access.py -v --tb=no &
    PID2=$!
    
    # Run deployment tests  
    python3 -m pytest test/t4-validate-deployment.py -v --tb=no &
    PID3=$!
    
    # Run monitoring tests
    python3 -m pytest test/t8-monitoring-tests.py -v --tb=no &
    PID4=$!
    
    # Wait for all to complete
    wait $PID1 $PID2 $PID3 $PID4
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
        echo "Running parallel mixed tests..."
        for i in {1..5}; do
            echo "Parallel run $i/5"
            run_parallel_tests
            sleep 5
        done
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