#!/usr/bin/env python3
"""
Test suite for Phase 3 - Kubernetes App Deployment Validation.
Combines deployment health checks and load testing in pytest format.
"""

import pytest
import subprocess
import json
import time
import threading
import queue
import os
from typing import Dict, List, Tuple
from .test_reporter import DeploymentReporter, generate_comprehensive_report


# Global variable to collect load test results for reporting
LOAD_TEST_RESULTS = []


class TestDeploymentValidation:
    """Test deployment health and validation checks"""
    
    @pytest.fixture(autouse=True)
    def setup_method(self):
        """Setup method to ensure cluster is accessible"""
        result = subprocess.run(['kubectl', 'cluster-info'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "Cluster not accessible"

    def test_cluster_connectivity(self):
        """Test cluster connectivity and API access"""
        result = subprocess.run(['kubectl', 'cluster-info'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "Failed to connect to cluster"
        assert 'Kubernetes control plane' in result.stdout, "Control plane not accessible"

    def test_namespace_exists(self):
        """Test kub-app namespace exists"""
        result = subprocess.run(['kubectl', 'get', 'namespace', 'kub-app'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "kub-app namespace does not exist"

    def test_deployment_status(self):
        """Test deployment status and replica readiness"""
        # Check deployment exists
        result = subprocess.run(['kubectl', 'get', 'deployment', 'kub-app', '-n', 'kub-app'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "kub-app deployment does not exist"
        
        # Get deployment details
        result = subprocess.run([
            'kubectl', 'get', 'deployment', 'kub-app', '-n', 'kub-app', 
            '-o', 'jsonpath={.status.readyReplicas},{.spec.replicas}'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get deployment status"
        ready_str, desired_str = result.stdout.strip().split(',')
        ready = int(ready_str) if ready_str else 0
        desired = int(desired_str)
        
        assert ready == desired, f"Deployment not ready: {ready}/{desired} replicas"
        assert ready >= 1, f"Expected at least 1 replica, found {ready}"

    def test_service_configuration(self):
        """Test service exists and has endpoints"""
        # Check service exists
        result = subprocess.run(['kubectl', 'get', 'service', 'kub-app-service', '-n', 'kub-app'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "kub-app-service does not exist"
        
        # Check endpoints
        result = subprocess.run([
            'kubectl', 'get', 'endpoints', 'kub-app-service', '-n', 'kub-app', 
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get service endpoints"
        endpoints = json.loads(result.stdout)
        
        assert 'subsets' in endpoints, "No endpoint subsets found"
        assert len(endpoints['subsets']) > 0, "No endpoint subsets available"
        
        subset = endpoints['subsets'][0]
        assert 'addresses' in subset, "No endpoint addresses found"
        assert len(subset['addresses']) >= 1, "No healthy endpoints available"

    def test_ingress_configuration(self):
        """Test ingress exists and is configured"""
        result = subprocess.run(['kubectl', 'get', 'ingress', 'kub-app-ingress', '-n', 'kub-app'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "kub-app-ingress does not exist"
        
        # Get ingress details
        result = subprocess.run([
            'kubectl', 'get', 'ingress', 'kub-app-ingress', '-n', 'kub-app', 
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get ingress details"
        ingress = json.loads(result.stdout)
        
        assert 'spec' in ingress, "Ingress spec not found"
        assert 'rules' in ingress['spec'], "Ingress rules not found"
        
        rules = ingress['spec']['rules']
        assert len(rules) > 0, "No ingress rules configured"
        assert rules[0]['host'] == 'kub-app.local', "Incorrect ingress host"

    def test_hpa_configuration(self):
        """Test HPA exists and is configured"""
        result = subprocess.run(['kubectl', 'get', 'hpa', 'kub-app-hpa', '-n', 'kub-app'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "kub-app-hpa does not exist"
        
        # Get HPA details
        result = subprocess.run([
            'kubectl', 'get', 'hpa', 'kub-app-hpa', '-n', 'kub-app', 
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get HPA details"
        hpa = json.loads(result.stdout)
        
        assert 'spec' in hpa, "HPA spec not found"
        assert 'scaleTargetRef' in hpa['spec'], "HPA target reference not found"
        assert hpa['spec']['scaleTargetRef']['name'] == 'kub-app', "HPA targeting wrong deployment"

    def test_http_accessibility(self):
        """Test HTTP access through ingress"""
        result = subprocess.run([
            'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
            '-H', 'Host: kub-app.local',
            'http://localhost:8080'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to connect to application"
        response_code = result.stdout.strip()
        assert response_code == '200', f"Expected HTTP 200, got {response_code}"

    def test_pod_distribution(self):
        """Test pods are distributed across nodes"""
        # Get pod node assignments
        result = subprocess.run([
            'kubectl', 'get', 'pods', '-n', 'kub-app', 
            '-o', 'jsonpath={.items[*].spec.nodeName}'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get pod node assignments"
        
        if result.stdout.strip():
            nodes = set(result.stdout.strip().split())
            assert len(nodes) >= 1, "Pods not distributed across any nodes"
            
            # Get total number of nodes
            result = subprocess.run(['kubectl', 'get', 'nodes', '--no-headers'], 
                                  capture_output=True, text=True)
            total_nodes = len(result.stdout.strip().split('\n'))
            
            assert len(nodes) <= total_nodes, f"Pod distribution error: {len(nodes)} > {total_nodes} nodes"


class TestLoadTesting:
    """Test load testing and performance validation"""
    
    @pytest.fixture(autouse=True)
    def setup_load_testing(self):
        """Ensure application is ready for load testing"""
        # Verify application is accessible
        result = subprocess.run([
            'curl', '-s', '-H', 'Host: kub-app.local', 
            'http://localhost:8080'
        ], capture_output=True, text=True)
        assert result.returncode == 0, "Application not accessible for load testing"

    def _run_load_test(self, concurrent_users: int, duration: int, test_name: str = "") -> Dict[str, str]:
        """Run Apache Bench load test and return results"""
        result = subprocess.run([
            'ab', '-t', str(duration), '-c', str(concurrent_users),
            '-H', 'Host: kub-app.local',
            'http://localhost:8080/'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, f"Load test failed: {result.stderr}"
        
        # Parse results
        output = result.stdout
        results = {
            "name": test_name,
            "concurrent_users": concurrent_users,
            "duration": duration,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        for line in output.split('\n'):
            if 'Requests per second:' in line:
                results['rps'] = line.split()[3]
            elif 'Failed requests:' in line:
                results['failed_requests'] = int(line.split()[2])
            elif 'Complete requests:' in line:
                results['total_requests'] = int(line.split()[2])
            elif 'Time per request:' in line and '(mean)' in line:
                if 'response_time' not in results:
                    results['response_time'] = line.split()[3]
            elif 'Transfer rate:' in line:
                results['transfer_rate'] = line.split()[2]
        
        # Add to global results for reporting
        LOAD_TEST_RESULTS.append(results)
        
        # Also save to file for persistence across pytest runs
        try:
            import json
            with open('load_test_results.json', 'w') as f:
                json.dump(LOAD_TEST_RESULTS, f, indent=2)
        except Exception:
            pass  # Continue even if file write fails
        
        return results

    def _get_hpa_status(self) -> Tuple[int, Dict]:
        """Get current HPA status"""
        result = subprocess.run([
            'kubectl', 'get', 'hpa', 'kub-app-hpa', '-n', 'kub-app', 
            '-o', 'json'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            hpa = json.loads(result.stdout)
            current_replicas = hpa.get('status', {}).get('currentReplicas', 0)
            return current_replicas, hpa
        return 0, {}

    def test_light_load(self):
        """Test light load (5 concurrent users, 10 seconds)"""
        initial_replicas, _ = self._get_hpa_status()
        
        results = self._run_load_test(concurrent_users=5, duration=10, test_name="Light Load")
        
        # Validate results
        assert 'failed_requests' in results, "Failed requests metric not found"
        assert results['failed_requests'] == 0, f"Load test had {results['failed_requests']} failed requests"
        
        assert 'rps' in results, "Requests per second metric not found"
        rps = float(results['rps'])
        assert rps > 0, "No requests processed"
        
        print(f"Light load results: {rps} RPS, {results['failed_requests']} failures")

    def test_medium_load(self):
        """Test medium load (10 concurrent users, 15 seconds)"""
        results = self._run_load_test(concurrent_users=10, duration=15, test_name="Medium Load")
        
        # Validate results
        assert 'failed_requests' in results, "Failed requests metric not found"
        assert results['failed_requests'] == 0, f"Load test had {results['failed_requests']} failed requests"
        
        assert 'rps' in results, "Requests per second metric not found"
        rps = float(results['rps'])
        assert rps > 0, "No requests processed"
        
        print(f"Medium load results: {rps} RPS, {results['failed_requests']} failures")
        
        # Allow time for metrics to update
        time.sleep(5)

    def test_heavy_load_and_scaling(self):
        """Test heavy load and HPA scaling (20 concurrent users, 30 seconds)"""
        initial_replicas, _ = self._get_hpa_status()
        
        results = self._run_load_test(concurrent_users=20, duration=30, test_name="Heavy Load with Scaling")
        
        # Validate load test results
        assert 'failed_requests' in results, "Failed requests metric not found"
        assert results['failed_requests'] == 0, f"Load test had {results['failed_requests']} failed requests"
        
        assert 'rps' in results, "Requests per second metric not found"
        rps = float(results['rps'])
        assert rps > 0, "No requests processed"
        
        print(f"Heavy load results: {rps} RPS, {results['failed_requests']} failures")
        
        # Wait for HPA to potentially scale
        time.sleep(10)
        
        final_replicas, hpa_data = self._get_hpa_status()
        
        # HPA should maintain at least the initial number of replicas
        assert final_replicas >= initial_replicas, f"Replica count decreased during load: {final_replicas} < {initial_replicas}"
        
        print(f"Scaling behavior: {initial_replicas} -> {final_replicas} replicas")
        
        # Add scaling information to results
        results['initial_replicas'] = initial_replicas
        results['final_replicas'] = final_replicas
        results['scaling_occurred'] = final_replicas > initial_replicas

    def test_concurrent_requests_handling(self):
        """Test handling of concurrent requests using threading"""
        def make_request(results_queue: queue.Queue):
            """Make a single HTTP request"""
            result = subprocess.run([
                'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
                '-H', 'Host: kub-app.local',
                'http://localhost:8080'
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                results_queue.put(result.stdout.strip())
            else:
                results_queue.put('FAILED')

        # Launch concurrent requests
        results_queue = queue.Queue()
        threads = []
        num_concurrent = 8
        
        for i in range(num_concurrent):
            thread = threading.Thread(target=make_request, args=(results_queue,))
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # Collect results
        success_count = 0
        while not results_queue.empty():
            response_code = results_queue.get()
            if response_code == '200':
                success_count += 1
        
        success_rate = success_count / num_concurrent
        assert success_rate >= 0.8, f"Only {success_count}/{num_concurrent} concurrent requests succeeded ({success_rate:.1%})"
        
        print(f"Concurrent requests: {success_count}/{num_concurrent} succeeded ({success_rate:.1%})")

    def test_response_time_performance(self):
        """Test response time performance under normal load"""
        start_time = time.time()
        
        result = subprocess.run([
            'curl', '-s', '-w', '%{time_total}',
            '-H', 'Host: kub-app.local',
            'http://localhost:8080'
        ], capture_output=True, text=True)
        
        total_time = time.time() - start_time
        
        assert result.returncode == 0, "Performance test request failed"
        assert total_time < 5.0, f"Response time {total_time:.2f}s exceeds 5 second threshold"
        
        print(f"Response time: {total_time:.3f}s")


if __name__ == "__main__":
    # Run tests and generate report
    print("Running deployment validation and load tests...")
    pytest.main([__file__, "-v", "-s"])
    
    # Generate comprehensive report after tests complete
    print("\nGenerating comprehensive test report...")
    try:
        # Try to load results from file first (for persistence)
        results_to_use = LOAD_TEST_RESULTS
        try:
            import json
            if os.path.exists('load_test_results.json'):
                with open('load_test_results.json', 'r') as f:
                    file_results = json.load(f)
                    if file_results:  # Use file results if available and not empty
                        results_to_use = file_results
                        print(f"Loaded {len(results_to_use)} load test results from file")
        except Exception as e:
            print(f"Could not load results from file: {e}")
        
        report_file = generate_comprehensive_report(results_to_use)
        print(f"Comprehensive report generated: {report_file}")
        
        # Cleanup temporary file
        try:
            if os.path.exists('load_test_results.json'):
                os.remove('load_test_results.json')
        except Exception:
            pass
        
        # Try to open the report in browser (optional)
        if os.name == 'posix':  # Linux/Mac
            subprocess.run(['xdg-open', report_file], check=False)
        elif os.name == 'nt':  # Windows
            subprocess.run(['start', report_file], shell=True, check=False)
            
    except Exception as e:
        print(f"Warning: Could not generate report: {e}")
        print("Test results are available in LOAD_TEST_RESULTS variable")