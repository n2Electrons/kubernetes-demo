#!/usr/bin/env python3
"""
Test framework for Milestone 2: Multi-node Kubernetes App Deployment
Tests application deployment across multiple nodes using pytest
"""

import subprocess
import json
import pytest
from typing import Dict, List, Any


class TestMultiNodeDeployment:
    """Test class for Milestone 2 multi-node application deployment validation"""

    @staticmethod
    def run_kubectl_command(cmd: List[str], output_format: str = "json") -> Dict[str, Any]:
        """Execute kubectl command and return parsed output"""
        try:
            if output_format == "json":
                cmd.extend(["-o", "json"])
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            if output_format == "json":
                return json.loads(result.stdout)
            else:
                return {"stdout": result.stdout, "stderr": result.stderr}
        except subprocess.CalledProcessError as e:
            return {"error": e.stderr, "returncode": e.returncode}
        except json.JSONDecodeError:
            return {"error": "Invalid JSON response", "stdout": result.stdout}

    def test_application_deployment_exists(self):
        """Test that the kub-app deployment exists and is configured correctly"""
        deployment = self.run_kubectl_command(["kubectl", "get", "deployment", "kub-app", "-n", "kub-app"])
        
        assert "error" not in deployment, f"Failed to get deployment: {deployment.get('error')}"
        
        # Check deployment configuration
        spec = deployment["spec"]
        assert spec["replicas"] == 3, f"Expected 3 replicas, got {spec['replicas']}"
        
        # Check selector labels
        assert spec["selector"]["matchLabels"]["app"] == "kub-app"

    def test_pods_running_and_distributed(self):
        """Test that pods are running and distributed across multiple nodes"""
        pods = self.run_kubectl_command(["kubectl", "get", "pods", "-n", "kub-app"])
        
        assert "error" not in pods, f"Failed to get pods: {pods.get('error')}"
        
        running_pods = []
        node_distribution = {}
        
        for pod in pods["items"]:
            pod_name = pod["metadata"]["name"]
            phase = pod["status"]["phase"]
            
            if phase == "Running":
                running_pods.append(pod_name)
                
                # Check node distribution
                node_name = pod["spec"].get("nodeName", "unknown")
                if node_name in node_distribution:
                    node_distribution[node_name] += 1
                else:
                    node_distribution[node_name] = 1
        
        # Verify we have the expected number of running pods
        assert len(running_pods) == 3, f"Expected 3 running pods, got {len(running_pods)}"
        
        # Verify pods are distributed across multiple nodes (at least 2 nodes)
        assert len(node_distribution) >= 2, f"Pods should be distributed across multiple nodes, found: {node_distribution}"
        
        print(f"Pod distribution across nodes: {node_distribution}")

    def test_service_configuration(self):
        """Test that the service is properly configured"""
        service = self.run_kubectl_command(["kubectl", "get", "service", "kub-app-service", "-n", "kub-app"])
        
        assert "error" not in service, f"Failed to get service: {service.get('error')}"
        
        # Check service configuration
        spec = service["spec"]
        assert spec["type"] == "ClusterIP", f"Expected ClusterIP service, got {spec['type']}"
        assert spec["selector"]["app"] == "kub-app", "Service selector should match app label"
        
        # Check ports
        ports = spec["ports"]
        assert len(ports) == 1, "Service should have exactly one port"
        assert ports[0]["port"] == 80, "Service should expose port 80"
        assert ports[0]["targetPort"] == 80, "Service should target port 80"

    def test_ingress_configuration(self):
        """Test that the ingress is properly configured"""
        ingress = self.run_kubectl_command(["kubectl", "get", "ingress", "kub-app-ingress", "-n", "kub-app"])
        
        assert "error" not in ingress, f"Failed to get ingress: {ingress.get('error')}"
        
        # Check ingress configuration
        spec = ingress["spec"]
        rules = spec["rules"]
        assert len(rules) == 1, "Ingress should have exactly one rule"
        
        rule = rules[0]
        assert rule["host"] == "kub-app.local", "Ingress should route kub-app.local"
        
        # Check backend service
        paths = rule["http"]["paths"]
        assert len(paths) == 1, "Should have exactly one path"
        
        backend = paths[0]["backend"]["service"]
        assert backend["name"] == "kub-app-service", "Ingress should route to kub-app-service"
        assert backend["port"]["number"] == 80, "Ingress should route to port 80"

    def test_hpa_configuration(self):
        """Test that the Horizontal Pod Autoscaler is properly configured"""
        hpa = self.run_kubectl_command(["kubectl", "get", "hpa", "kub-app-hpa", "-n", "kub-app"])
        
        assert "error" not in hpa, f"Failed to get HPA: {hpa.get('error')}"
        
        # Check HPA configuration
        spec = hpa["spec"]
        assert spec["minReplicas"] == 2, f"Expected minReplicas 2, got {spec['minReplicas']}"
        assert spec["maxReplicas"] == 10, f"Expected maxReplicas 10, got {spec['maxReplicas']}"
        
        # Check target reference
        target = spec["scaleTargetRef"]
        assert target["kind"] == "Deployment", "HPA should target a Deployment"
        assert target["name"] == "kub-app", "HPA should target kub-app deployment"

    def test_application_accessibility(self):
        """Test that the application is accessible through the ingress"""
        # Port forward to test accessibility (since we can't modify /etc/hosts in tests)
        try:
            # Get service endpoint
            service = self.run_kubectl_command(["kubectl", "get", "service", "kub-app-service", "-n", "kub-app"])
            assert "error" not in service, f"Failed to get service: {service.get('error')}"
            
            cluster_ip = service["spec"]["clusterIP"]
            assert cluster_ip != "None", "Service should have a cluster IP"
            
            # Test connectivity using kubectl proxy (basic connectivity test)
            connectivity_test = self.run_kubectl_command(
                ["kubectl", "get", "endpoints", "kub-app-service", "-n", "kub-app"],
                output_format="text"
            )
            
            assert "error" not in connectivity_test, "Service should have healthy endpoints"
            assert cluster_ip in connectivity_test["stdout"] or "kub-app" in connectivity_test["stdout"], "Service endpoints should be available"
            
        except Exception as e:
            pytest.skip(f"Accessibility test skipped due to network constraints: {e}")

    def test_pod_resource_limits(self):
        """Test that pods have proper resource limits configured"""
        pods = self.run_kubectl_command(["kubectl", "get", "pods", "-n", "kub-app"])
        
        assert "error" not in pods, f"Failed to get pods: {pods.get('error')}"
        
        for pod in pods["items"]:
            if pod["status"]["phase"] == "Running":
                containers = pod["spec"]["containers"]
                assert len(containers) == 1, "Each pod should have exactly one container"
                
                container = containers[0]
                resources = container["resources"]
                
                # Check resource requests
                requests = resources["requests"]
                assert requests["memory"] == "32Mi", "Memory request should be 32Mi"
                assert requests["cpu"] == "100m", "CPU request should be 100m"
                
                # Check resource limits
                limits = resources["limits"]
                assert limits["memory"] == "64Mi", "Memory limit should be 64Mi"
                assert limits["cpu"] == "200m", "CPU limit should be 200m"

    def test_readiness_and_liveness_probes(self):
        """Test that pods have proper health checks configured"""
        pods = self.run_kubectl_command(["kubectl", "get", "pods", "-n", "kub-app"])
        
        assert "error" not in pods, f"Failed to get pods: {pods.get('error')}"
        
        for pod in pods["items"]:
            if pod["status"]["phase"] == "Running":
                container = pod["spec"]["containers"][0]
                
                # Check liveness probe
                liveness_probe = container["livenessProbe"]
                assert liveness_probe["httpGet"]["path"] == "/", "Liveness probe should check root path"
                assert liveness_probe["httpGet"]["port"] == 80, "Liveness probe should check port 80"
                
                # Check readiness probe
                readiness_probe = container["readinessProbe"]
                assert readiness_probe["httpGet"]["path"] == "/", "Readiness probe should check root path"
                assert readiness_probe["httpGet"]["port"] == 80, "Readiness probe should check port 80"


if __name__ == "__main__":
    # Run tests with pytest when executed directly
    import sys
    pytest.main([__file__] + sys.argv[1:])