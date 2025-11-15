#!/usr/bin/env python3
"""
Test framework for Milestone 1: Base Infrastructure
Tests namespace creation, node status, and basic cluster health using pytest
"""

import subprocess
import json
import pytest
from typing import Dict, List, Any


class TestBaseInfrastructure:
    """Test class for Milestone 1 infrastructure validation"""

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

    def test_cluster_connectivity(self):
        """Test basic cluster API connectivity"""
        cluster_info = self.run_kubectl_command(["kubectl", "cluster-info"], output_format="text")
        
        assert "error" not in cluster_info, f"Cluster connectivity failed: {cluster_info.get('error')}"
        assert "running at" in cluster_info["stdout"], "Cluster API is not accessible"

    def test_cluster_nodes_ready(self):
        """Test that all cluster nodes are ready"""
        nodes = self.run_kubectl_command(["kubectl", "get", "nodes"])
        
        assert "error" not in nodes, f"Failed to get nodes: {nodes.get('error')}"
        
        ready_nodes = 0
        total_nodes = len(nodes["items"])
        
        for node in nodes["items"]:
            node_name = node["metadata"]["name"]
            conditions = node["status"]["conditions"]
            
            # Check if node is Ready
            node_ready = False
            for condition in conditions:
                if condition["type"] == "Ready" and condition["status"] == "True":
                    ready_nodes += 1
                    node_ready = True
                    break
            
            assert node_ready, f"Node {node_name} is not Ready"
        
        assert ready_nodes == total_nodes, f"Only {ready_nodes}/{total_nodes} nodes are ready"

    def test_system_pods_running(self):
        """Test that essential system pods are running"""
        pods = self.run_kubectl_command(["kubectl", "get", "pods", "-n", "kube-system"])
        
        assert "error" not in pods, f"Failed to get system pods: {pods.get('error')}"
        
        running_pods = 0
        total_pods = len(pods["items"])
        essential_pods = ["coredns", "traefik", "metrics-server"]
        
        for pod in pods["items"]:
            pod_name = pod["metadata"]["name"]
            phase = pod["status"]["phase"]
            
            # Jobs and install pods can be "Succeeded" which is also good
            if phase in ["Running", "Succeeded"]:
                running_pods += 1
        
        # Check if essential pods are present
        essential_found = 0
        for essential in essential_pods:
            for pod in pods["items"]:
                if essential in pod["metadata"]["name"]:
                    essential_found += 1
                    break
        
        assert running_pods >= total_pods * 0.8, f"Only {running_pods}/{total_pods} system pods are running"
        assert essential_found == len(essential_pods), f"Only {essential_found}/{len(essential_pods)} essential pods found"

    def test_namespace_creation(self):
        """Test that the application namespace exists and is active"""
        namespace = "kub-app"
        namespaces = self.run_kubectl_command(["kubectl", "get", "namespaces"])
        
        assert "error" not in namespaces, f"Failed to get namespaces: {namespaces.get('error')}"
        
        namespace_found = False
        for ns in namespaces["items"]:
            if ns["metadata"]["name"] == namespace:
                status = ns["status"]["phase"]
                assert status == "Active", f"Namespace '{namespace}' exists but status is '{status}'"
                namespace_found = True
                break
        
        assert namespace_found, f"Namespace '{namespace}' not found"


if __name__ == "__main__":
    # Run tests with pytest when executed directly
    import sys
    pytest.main([__file__] + sys.argv[1:])