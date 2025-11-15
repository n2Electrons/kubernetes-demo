# Test Framework

Test suite for validating each milestone of the Kubernetes GitOps project using pytest.

## Test Structure

### t1-infrastructure.py
Tests for **Milestone 1 - Base Infrastructure**:
- Cluster connectivity and API access
- Node readiness status
- System pods running (CoreDNS, Traefik, Metrics Server)
- Application namespace creation

### Running Tests

**Install dependencies:**
```bash
pip3 install -r test/requirements.txt
```

**Manual execution:**
```bash
# Run infrastructure tests with pytest
pytest test/t1-infrastructure.py -v

# Run with specific output format
pytest test/t1-infrastructure.py -v --tb=short
```

**Automated execution:**
```bash
# Run all tests for Milestone 1 (includes setup)
./test/run-t1-tests.sh
```

## Test Requirements

- Python 3.x
- pytest (installed via requirements.txt)
- kubectl configured and cluster accessible
- Cluster must be running (use `./scripts/setup-cluster.sh`)

## Test Output

Pytest provides:
- Detailed test results with pass/fail status
- Clear assertion error messages
- Test execution summary
- Exit code 0 for success, non-zero for failure (CI/CD friendly)
- Multiple output formats (verbose, short, etc.)