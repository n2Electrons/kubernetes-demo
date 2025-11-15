# Test Framework

Test suite for validating each milestone of the Kubernetes GitOps project using pytest.

## Test Structure

### t1-infrastructure.py
Tests for **Milestone 1 - Base Infrastructure**:
- Cluster connectivity and API access
- Node readiness status
- System pods running (CoreDNS, Traefik, Metrics Server)
- Application namespace creation

### t2-multi-node.py
Tests for **Milestone 2 - Multi-node Application Deployment**:
- Application deployment configuration and replica count
- Pod distribution across multiple nodes
- Service configuration and endpoints
- Ingress routing configuration
- HPA (Horizontal Pod Autoscaler) setup
- Application accessibility through ingress
- Resource limits and requests validation
- Health checks (readiness and liveness probes)

### Running Tests

**Install dependencies:**
```bash
pip3 install -r test/requirements.txt
```

**Manual execution:**
```bash
# Run infrastructure tests
pytest test/t1-infrastructure.py -v

# Run multi-node deployment tests
pytest test/t2-multi-node.py -v

# Run all tests
pytest test/ -v
```

**Automated execution:**
```bash
# Run Milestone 1 tests (includes setup)
./test/run-t1-tests.sh

# Run Milestone 2 tests (includes deployment)
./test/run-t2-tests.sh
```

## Test Requirements

- Python 3.x
- pytest (installed via requirements.txt)
- kubectl configured and cluster accessible
- Cluster must be running (use `./scripts/setup-cluster.sh`)
- For t2 tests: Application must be deployed (automatic via test runner)

## Test Output

Pytest provides:
- Detailed test results with pass/fail status
- Clear assertion error messages
- Test execution summary
- Exit code 0 for success, non-zero for failure (CI/CD friendly)
- Multiple output formats (verbose, short, etc.)