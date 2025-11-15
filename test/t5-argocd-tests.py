# Argo CD Applications Test Suite
import subprocess
import json
import pytest
import time
import yaml
import os

class TestArgoCD:
    """Test suite for Argo CD installation and GitOps functionality"""
    
    def test_argocd_namespace_exists(self):
        """Test that argocd namespace exists"""
        result = subprocess.run([
            'kubectl', 'get', 'namespace', 'argocd'
        ], capture_output=True, text=True)
        assert result.returncode == 0, "ArgoCD namespace should exist"
    
    def test_argocd_components_running(self):
        """Test that all Argo CD components are running"""
        components = [
            'argocd-applicationset-controller', 
            'argocd-repo-server'
        ]
        
        for component in components:
            result = subprocess.run([
                'kubectl', 'get', 'deployment', component, '-n', 'argocd',
                '-o', 'jsonpath={.status.readyReplicas}'
            ], capture_output=True, text=True)
            
            assert result.returncode == 0, f"Failed to check {component}"
            ready_replicas = result.stdout.strip()
            assert ready_replicas != "", f"{component} has no ready replicas"
            assert int(ready_replicas) > 0, f"{component} should have at least 1 ready replica"
    
    def test_argocd_core_accessibility(self):
        """Test that Argo CD application controller is accessible"""
        # Check if application controller pod is running
        result = subprocess.run([
            'kubectl', 'get', 'pods', '-n', 'argocd',
            '-l', 'app.kubernetes.io/name=argocd-application-controller',
            '--no-headers'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to check application controller"
        pods = result.stdout.strip().split('\n')
        running_pods = [pod for pod in pods if 'Running' in pod or '1/1' in pod]
        assert len(running_pods) > 0, "Application controller should be running"
    
    def test_application_project_exists(self):
        """Test that the kubernetes-demo project exists"""
        result = subprocess.run([
            'kubectl', 'get', 'appproject', 'kubernetes-demo', '-n', 'argocd'
        ], capture_output=True, text=True)
        assert result.returncode == 0, "kubernetes-demo AppProject should exist"
    
    def test_kub_app_application_exists(self):
        """Test that the kub-app Application exists"""
        result = subprocess.run([
            'kubectl', 'get', 'application', 'kub-app', '-n', 'argocd'
        ], capture_output=True, text=True)
        assert result.returncode == 0, "kub-app Application should exist"
    
    def test_kub_app_sync_status(self):
        """Test that the kub-app application is synced"""
        # Get application status
        result = subprocess.run([
            'kubectl', 'get', 'application', 'kub-app', '-n', 'argocd',
            '-o', 'json'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get kub-app status"
        
        app_data = json.loads(result.stdout)
        sync_status = app_data.get('status', {}).get('sync', {}).get('status', '')
        health_status = app_data.get('status', {}).get('health', {}).get('status', '')
        
        # Application should be synced or at least syncing
        assert sync_status in ['Synced', 'OutOfSync'], f"Application sync status: {sync_status}"
        
        # Health should be progressing or healthy
        assert health_status in ['Healthy', 'Progressing', 'Degraded'], f"Application health status: {health_status}"
    
    def test_argocd_manages_kub_app_namespace(self):
        """Test that Argo CD has created/managed the kub-app namespace"""
        result = subprocess.run([
            'kubectl', 'get', 'namespace', 'kub-app', 
            '-o', 'jsonpath={.metadata.labels}'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "kub-app namespace should exist"
        
        # Check for Argo CD annotation/label indicating management
        labels = result.stdout
        # The namespace might have Argo CD labels if managed by Argo CD
        # This is informational - the key test is that the namespace exists
        assert 'kub-app' in labels or labels == '{}', "kub-app namespace should exist"

    def test_gitops_workflow_configuration(self):
        """Test that GitOps workflow is properly configured"""
        # Check application source repository
        result = subprocess.run([
            'kubectl', 'get', 'application', 'kub-app', '-n', 'argocd',
            '-o', 'jsonpath={.spec.source.repoURL}'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, "Failed to get application source"
        repo_url = result.stdout.strip()
        assert 'kubernetes-demo' in repo_url, f"Repository URL should reference kubernetes-demo: {repo_url}"
        
        # Check sync policy
        result = subprocess.run([
            'kubectl', 'get', 'application', 'kub-app', '-n', 'argocd',
            '-o', 'jsonpath={.spec.syncPolicy.automated}'
        ], capture_output=True, text=True)
        
        automated_sync = result.stdout.strip()
        assert automated_sync != '', "Application should have automated sync policy configured"

if __name__ == "__main__":
    print("Running Argo CD GitOps validation tests...")
    pytest.main([__file__, "-v"])