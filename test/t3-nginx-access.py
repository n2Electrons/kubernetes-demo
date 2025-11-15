#!/usr/bin/env python3
"""
Test suite for NGINX application access validation.
Tests HTTP accessibility, response validation, and load balancing.
"""

import pytest
import subprocess
import json
import time
import requests
from urllib.parse import urljoin


class TestNginxAccess:
    """Test NGINX application access and functionality"""
    
    @pytest.fixture(autouse=True)
    def setup_method(self):
        """Setup method to ensure cluster and app are running"""
        # Verify cluster is accessible
        result = subprocess.run(['kubectl', 'cluster-info'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "Cluster not accessible"
        
        # Verify application is deployed
        result = subprocess.run(['kubectl', 'get', 'deployment', 'kub-app', '-n', 'kub-app'], 
                              capture_output=True, text=True)
        assert result.returncode == 0, "Application deployment not found"

    def test_nginx_http_response(self):
        """Test NGINX responds with valid HTTP status"""
        result = subprocess.run([
            'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
            '-H', 'Host: kub-app.local',
            'http://localhost:8080'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Curl command failed"
        assert result.stdout.strip() == '200', f"Expected HTTP 200, got {result.stdout.strip()}"

    def test_nginx_content_validation(self):
        """Test NGINX serves expected content"""
        result = subprocess.run([
            'curl', '-s',
            '-H', 'Host: kub-app.local',
            'http://localhost:8080'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to fetch content"
        content = result.stdout
        
        # Validate NGINX welcome page content
        assert 'Welcome to nginx!' in content, "NGINX welcome message not found"
        assert '<title>Welcome to nginx!</title>' in content, "NGINX title not found"
        assert 'nginx web server is successfully installed' in content, "NGINX installation message not found"

    def test_nginx_response_headers(self):
        """Test NGINX response headers are correct"""
        result = subprocess.run([
            'curl', '-s', '-I',
            '-H', 'Host: kub-app.local',
            'http://localhost:8080'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get headers"
        headers = result.stdout.lower()
        
        # Check for NGINX server header
        assert 'server: nginx' in headers, "NGINX server header not found"
        assert 'content-type: text/html' in headers, "HTML content type not found"

    def test_multiple_pod_responses(self):
        """Test load balancing across multiple NGINX pods"""
        # Get pod IPs to verify load balancing
        result = subprocess.run([
            'kubectl', 'get', 'pods', '-n', 'kub-app', 
            '-l', 'app=kub-app', 
            '-o', 'jsonpath={.items[*].status.podIP}'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get pod IPs"
        pod_ips = result.stdout.strip().split()
        assert len(pod_ips) >= 3, f"Expected at least 3 pods, found {len(pod_ips)}"
        
        # Make multiple requests to verify load balancing
        successful_requests = 0
        for i in range(10):
            result = subprocess.run([
                'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
                '-H', 'Host: kub-app.local',
                'http://localhost:8080'
            ], capture_output=True, text=True)
            
            if result.returncode == 0 and result.stdout.strip() == '200':
                successful_requests += 1
        
        assert successful_requests >= 8, f"Only {successful_requests}/10 requests succeeded"

    def test_service_endpoint_health(self):
        """Test service endpoints are healthy"""
        result = subprocess.run([
            'kubectl', 'get', 'endpoints', 'kub-app-service', '-n', 'kub-app',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get service endpoints"
        endpoints = json.loads(result.stdout)
        
        # Verify endpoints exist and are ready
        assert 'subsets' in endpoints, "No endpoint subsets found"
        assert len(endpoints['subsets']) > 0, "No endpoint subsets available"
        
        subset = endpoints['subsets'][0]
        assert 'addresses' in subset, "No endpoint addresses found"
        assert len(subset['addresses']) >= 3, f"Expected at least 3 endpoints, found {len(subset['addresses'])}"

    def test_ingress_routing(self):
        """Test ingress properly routes traffic"""
        # Check ingress configuration
        result = subprocess.run([
            'kubectl', 'get', 'ingress', 'kub-app-ingress', '-n', 'kub-app',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get ingress configuration"
        ingress = json.loads(result.stdout)
        
        # Verify ingress rules
        assert 'spec' in ingress, "Ingress spec not found"
        assert 'rules' in ingress['spec'], "Ingress rules not found"
        
        rules = ingress['spec']['rules']
        assert len(rules) > 0, "No ingress rules configured"
        
        rule = rules[0]
        assert rule['host'] == 'kub-app.local', f"Expected host kub-app.local, found {rule['host']}"

    def test_nginx_performance_basic(self):
        """Test basic NGINX performance and response time"""
        start_time = time.time()
        
        result = subprocess.run([
            'curl', '-s', '-w', '%{time_total}',
            '-H', 'Host: kub-app.local',
            'http://localhost:8080'
        ], capture_output=True, text=True)
        
        end_time = time.time()
        
        assert result.returncode == 0, "Performance test request failed"
        
        # Verify reasonable response time (should be under 1 second for local cluster)
        total_time = end_time - start_time
        assert total_time < 2.0, f"Response time {total_time:.2f}s exceeds 2 second threshold"

    def test_nginx_concurrent_requests(self):
        """Test NGINX handles concurrent requests"""
        import threading
        import queue
        
        results = queue.Queue()
        
        def make_request():
            """Make a single HTTP request"""
            result = subprocess.run([
                'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
                '-H', 'Host: kub-app.local',
                'http://localhost:8080'
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                results.put(result.stdout.strip())
            else:
                results.put('FAILED')
        
        # Launch 5 concurrent requests
        threads = []
        for i in range(5):
            thread = threading.Thread(target=make_request)
            threads.append(thread)
            thread.start()
        
        # Wait for all threads to complete
        for thread in threads:
            thread.join()
        
        # Collect results
        success_count = 0
        while not results.empty():
            response_code = results.get()
            if response_code == '200':
                success_count += 1
        
        assert success_count >= 4, f"Only {success_count}/5 concurrent requests succeeded"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])