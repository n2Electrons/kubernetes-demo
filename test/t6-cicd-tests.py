# CI/CD Pipeline Test Suite
import subprocess
import pytest
import json
import os

class TestCICD:
    """Test suite for CI/CD pipeline validation"""
    
    def test_dockerfile_exists(self):
        """Test that Dockerfile exists and is valid"""
        dockerfile_path = "ci/Dockerfile"
        assert os.path.exists(dockerfile_path), "Dockerfile should exist in ci/ directory"
        
        # Check if Dockerfile has required components
        with open(dockerfile_path, 'r') as f:
            content = f.read()
            assert "FROM nginx:alpine" in content, "Should use nginx:alpine base image"
            assert "EXPOSE" in content, "Should expose a port"
            assert "HEALTHCHECK" in content, "Should include health check"

    def test_nginx_config_exists(self):
        """Test that nginx.conf exists and has basic configuration"""
        nginx_conf_path = "ci/nginx.conf"
        assert os.path.exists(nginx_conf_path), "nginx.conf should exist"
        
        with open(nginx_conf_path, 'r') as f:
            content = f.read()
            assert "server {" in content, "Should have server block"
            assert "listen" in content, "Should have listen directive"
            assert "/health" in content, "Should have health check endpoint"

    def test_html_files_exist(self):
        """Test that required HTML files exist"""
        html_files = [
            "ci/html/404.html",
            "ci/html/50x.html"
        ]
        
        for html_file in html_files:
            assert os.path.exists(html_file), f"{html_file} should exist"

    def test_github_workflow_syntax(self):
        """Test that GitHub workflow file has valid YAML syntax"""
        workflow_path = ".github/workflows/ci-cd.yml"
        assert os.path.exists(workflow_path), "CI/CD workflow should exist"
        
        import yaml
        with open(workflow_path, 'r') as f:
            try:
                workflow = yaml.safe_load(f)
                assert "name" in workflow, "Workflow should have a name"
                # YAML parser converts 'on' to True, check for trigger section
                assert True in workflow or "on" in workflow, "Workflow should have triggers"
                assert "jobs" in workflow, "Workflow should have jobs"
            except yaml.YAMLError as e:
                pytest.fail(f"Invalid YAML in workflow file: {e}")

    def test_workflow_has_required_jobs(self):
        """Test that workflow has all required jobs"""
        workflow_path = ".github/workflows/ci-cd.yml"
        
        import yaml
        with open(workflow_path, 'r') as f:
            workflow = yaml.safe_load(f)
            
        required_jobs = [
            "lint",
            "test", 
            "security",
            "build",
            "deploy-dev",
            "deploy-prod"
        ]
        
        for job in required_jobs:
            assert job in workflow["jobs"], f"Job '{job}' should be defined in workflow"

    def test_workflow_triggers(self):
        """Test that workflow has correct triggers"""
        workflow_path = ".github/workflows/ci-cd.yml"
        
        import yaml
        with open(workflow_path, 'r') as f:
            workflow = yaml.safe_load(f)
            
        # YAML parser converts 'on' to True
        triggers = workflow.get(True, workflow.get("on", {}))
        assert "push" in triggers, "Should trigger on push"
        assert "pull_request" in triggers, "Should trigger on pull request"
        
        # Check branch configuration
        push_branches = triggers["push"]["branches"]
        assert "main" in push_branches, "Should trigger on main branch"
        assert "develop" in push_branches, "Should trigger on develop branch"

    def test_environment_configuration(self):
        """Test that environments are properly configured"""
        workflow_path = ".github/workflows/ci-cd.yml"
        
        import yaml
        with open(workflow_path, 'r') as f:
            workflow = yaml.safe_load(f)
            
        # Check if deploy jobs have environments
        deploy_dev = workflow["jobs"]["deploy-dev"]
        deploy_prod = workflow["jobs"]["deploy-prod"]
        
        assert "environment" in deploy_dev, "Deploy-dev should have environment"
        assert "environment" in deploy_prod, "Deploy-prod should have environment"
        assert deploy_dev["environment"] == "development", "Should deploy to development"
        assert deploy_prod["environment"] == "production", "Should deploy to production"

    def test_security_scanning_configured(self):
        """Test that security scanning is properly configured"""
        workflow_path = ".github/workflows/ci-cd.yml"
        
        import yaml
        with open(workflow_path, 'r') as f:
            workflow = yaml.safe_load(f)
            
        security_job = workflow["jobs"]["security"]
        steps = security_job["steps"]
        
        # Look for Trivy scanner
        trivy_step = None
        for step in steps:
            if "trivy" in step.get("name", "").lower():
                trivy_step = step
                break
                
        assert trivy_step is not None, "Should have Trivy security scanning step"

    def test_image_registry_configuration(self):
        """Test that container registry is properly configured"""
        workflow_path = ".github/workflows/ci-cd.yml"
        
        import yaml
        with open(workflow_path, 'r') as f:
            workflow = yaml.safe_load(f)
            
        env = workflow["env"]
        assert "REGISTRY" in env, "Should define container registry"
        assert "IMAGE_NAME" in env, "Should define image name"
        assert "ghcr.io" in env["REGISTRY"], "Should use GitHub Container Registry"

if __name__ == "__main__":
    print("Running CI/CD pipeline validation tests...")
    pytest.main([__file__, "-v"])