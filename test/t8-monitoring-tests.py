# Observability Stack Tests
import subprocess
import pytest
import json
import time
import requests

class TestMonitoringStack:
    """Test suite for observability components validation"""

    def test_monitoring_namespace_exists(self):
        """Test that monitoring namespace is created"""
        result = subprocess.run([
            'kubectl', 'get', 'namespace', 'monitoring'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Monitoring namespace should exist"

    def test_prometheus_deployment(self):
        """Test Prometheus deployment status"""
        result = subprocess.run([
            'kubectl', 'get', 'deployment', 'prometheus', '-n', 'monitoring',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get Prometheus deployment"
        
        deployment = json.loads(result.stdout)
        assert deployment['status']['readyReplicas'] >= 1, "Prometheus should have ready replicas"

    def test_grafana_deployment(self):
        """Test Grafana deployment status"""
        result = subprocess.run([
            'kubectl', 'get', 'deployment', 'grafana', '-n', 'monitoring',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get Grafana deployment"
        
        deployment = json.loads(result.stdout)
        assert deployment['status']['readyReplicas'] >= 1, "Grafana should have ready replicas"

    def test_alertmanager_deployment(self):
        """Test AlertManager deployment status"""
        result = subprocess.run([
            'kubectl', 'get', 'deployment', 'alertmanager', '-n', 'monitoring',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get AlertManager deployment"
        
        deployment = json.loads(result.stdout)
        assert deployment['status']['readyReplicas'] >= 1, "AlertManager should have ready replicas"

    def test_jaeger_deployment(self):
        """Test Jaeger deployment status"""
        result = subprocess.run([
            'kubectl', 'get', 'deployment', 'jaeger', '-n', 'monitoring',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get Jaeger deployment"
        
        deployment = json.loads(result.stdout)
        assert deployment['status']['readyReplicas'] >= 1, "Jaeger should have ready replicas"

    def test_fluent_bit_daemonset(self):
        """Test Fluent Bit DaemonSet status"""
        result = subprocess.run([
            'kubectl', 'get', 'daemonset', 'fluent-bit', '-n', 'monitoring',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get Fluent Bit DaemonSet"
        
        daemonset = json.loads(result.stdout)
        assert daemonset['status']['numberReady'] >= 1, "Fluent Bit should have ready pods"

    def test_prometheus_service_accessibility(self):
        """Test Prometheus service is accessible"""
        # Port forward Prometheus service
        port_forward = subprocess.Popen([
            'kubectl', 'port-forward', 'svc/prometheus', '9091:9090', '-n', 'monitoring'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        try:
            time.sleep(5)  # Wait for port forward to establish
            
            response = requests.get('http://localhost:9091/api/v1/query', 
                                  params={'query': 'up'}, timeout=10)
            assert response.status_code == 200, "Prometheus API should be accessible"
            
            data = response.json()
            assert data['status'] == 'success', "Prometheus query should succeed"
            
        finally:
            port_forward.terminate()
            port_forward.wait()

    def test_grafana_service_accessibility(self):
        """Test Grafana service is accessible"""
        # Port forward Grafana service
        port_forward = subprocess.Popen([
            'kubectl', 'port-forward', 'svc/grafana', '3001:3000', '-n', 'monitoring'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        try:
            time.sleep(5)  # Wait for port forward to establish
            
            response = requests.get('http://localhost:3001/api/health', timeout=10)
            assert response.status_code == 200, "Grafana should be accessible"
            
            health_data = response.json()
            assert health_data['database'] == 'ok', "Grafana database should be healthy"
            
        finally:
            port_forward.terminate()
            port_forward.wait()

    def test_alertmanager_service_accessibility(self):
        """Test AlertManager service is accessible"""
        # Port forward AlertManager service
        port_forward = subprocess.Popen([
            'kubectl', 'port-forward', 'svc/alertmanager', '9094:9093', '-n', 'monitoring'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        try:
            time.sleep(5)  # Wait for port forward to establish
            
            response = requests.get('http://localhost:9094/-/healthy', timeout=10)
            assert response.status_code == 200, "AlertManager should be accessible"
            
        finally:
            port_forward.terminate()
            port_forward.wait()

    def test_jaeger_service_accessibility(self):
        """Test Jaeger UI is accessible"""
        # Port forward Jaeger service
        port_forward = subprocess.Popen([
            'kubectl', 'port-forward', 'svc/jaeger', '16687:16686', '-n', 'monitoring'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        try:
            time.sleep(5)  # Wait for port forward to establish
            
            response = requests.get('http://localhost:16687/', timeout=10)
            assert response.status_code == 200, "Jaeger UI should be accessible"
            
        finally:
            port_forward.terminate()
            port_forward.wait()

    def test_metrics_collection(self):
        """Test that metrics are being collected"""
        # Port forward Prometheus service
        port_forward = subprocess.Popen([
            'kubectl', 'port-forward', 'svc/prometheus', '9090:9090', '-n', 'monitoring'
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        try:
            time.sleep(5)  # Wait for port forward to establish
            
            # Check for basic connectivity
            response = requests.get('http://localhost:9090/api/v1/query', 
                                  params={'query': 'up'}, timeout=10)
            assert response.status_code == 200, "Should be able to connect to Prometheus"
            
            # Check for pod metrics (using kubelet metrics which should be available)
            response = requests.get('http://localhost:9090/api/v1/query', 
                                  params={'query': 'kubelet_running_pods'}, timeout=10)
            assert response.status_code == 200, "Should be able to query Kubernetes metrics"
            
            data = response.json()
            assert data['status'] == 'success', "Metrics query should succeed"
            assert len(data['data']['result']) > 0, "Should have pod metrics"
            
        finally:
            port_forward.terminate()
            port_forward.wait()

    def test_ingress_configuration(self):
        """Test ingress configurations for monitoring services"""
        # Check Grafana ingress
        result = subprocess.run([
            'kubectl', 'get', 'ingress', 'grafana-ingress', '-n', 'monitoring',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Grafana ingress should exist"
        
        ingress = json.loads(result.stdout)
        rules = ingress['spec']['rules']
        assert len(rules) > 0, "Grafana ingress should have rules"
        assert rules[0]['host'] == 'grafana.local', "Grafana ingress should have correct host"

    def test_service_monitors(self):
        """Test that services are properly configured for monitoring"""
        # Check that services have proper labels for monitoring
        result = subprocess.run([
            'kubectl', 'get', 'service', '-n', 'monitoring', '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Should be able to list monitoring services"
        
        services = json.loads(result.stdout)
        service_names = [svc['metadata']['name'] for svc in services['items']]
        
        expected_services = ['prometheus', 'grafana', 'alertmanager', 'jaeger', 'fluent-bit']
        for service in expected_services:
            assert service in service_names, f"Service {service} should exist"

    def test_config_maps(self):
        """Test that configuration maps are properly created"""
        config_maps = [
            'prometheus-config',
            'grafana-config', 
            'alertmanager-config',
            'fluent-bit-config'
        ]
        
        for cm_name in config_maps:
            result = subprocess.run([
                'kubectl', 'get', 'configmap', cm_name, '-n', 'monitoring'
            ], capture_output=True, text=True)
            
            assert result.returncode == 0, f"ConfigMap {cm_name} should exist"

if __name__ == "__main__":
    print("Running monitoring stack validation tests...")
    pytest.main([__file__, "-v"])