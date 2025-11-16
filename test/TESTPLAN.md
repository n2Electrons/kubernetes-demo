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

### t3-nginx-access.py
Tests for **NGINX Application Access and Performance**:
- HTTP response validation (200 status code)
- NGINX content verification (welcome page)
- Response headers validation
- Load balancing across multiple pods
- Service endpoint health checks
- Ingress routing functionality
- Basic performance and response time testing
- Concurrent request handling

### t4-validate-deployment.py
Tests for **Phase 3 - Deployment Validation and Load Testing**:
- **Deployment Validation**: Cluster connectivity, namespace existence, deployment status, service configuration, ingress setup, HPA configuration, HTTP accessibility, pod distribution
- **Load Testing**: Light load (5 users), medium load (10 users), heavy load with scaling (20 users), concurrent request handling, response time performance
- **Performance Metrics**: Requests per second, failure rates, response times, HPA scaling behavior
- **Integration Testing**: End-to-end validation combining all deployment and performance aspects

### t8-monitoring-tests.py
Tests for **Phase 8 - Monitoring Stack Deployment**:
- **Infrastructure Validation**: Monitoring namespace creation, monitoring stack deployment
- **Component Testing**: Prometheus metrics collection, Grafana dashboard accessibility, AlertManager configuration, Jaeger distributed tracing, Fluent Bit log aggregation
- **Service Integration**: Service discovery, metrics scraping, log collection, trace correlation
- **External Access**: Ingress configuration for Grafana and Jaeger dashboards

### t9-monitoring-status-tests.py
Tests for **Phase 9 - Monitoring Stack Status Validation**:
- **Infrastructure Tests**: Monitoring namespace validation, pod readiness verification, service accessibility testing, ingress configuration validation
- **Component-Specific Tests**: Prometheus API endpoint testing, Fluent Bit DaemonSet coverage validation
- **Integration Tests**: Complete monitoring stack status validation with comprehensive output display
- **Expected Components**: Prometheus (metrics), Grafana (visualization), AlertManager (alerting), Jaeger (tracing), Fluent Bit (logging)

## Phase 3 - Deployment Validation

### Comprehensive Testing

**t4-validate-deployment.py**
Complete deployment validation and load testing:
- **Deployment Health**: Cluster connectivity, namespace, deployment status, service endpoints, ingress configuration, HPA setup, HTTP accessibility, pod distribution
- **Load Testing**: Light, medium, and heavy load scenarios with performance metrics
- **Scaling Validation**: HPA behavior monitoring during load tests
- **Concurrent Handling**: Multi-threaded request testing
- **Performance Metrics**: Response times, throughput, failure rates

## Phase 8/9 - Monitoring Stack Validation

### Monitoring Deployment Testing

**t8-monitoring-tests.py**
Complete monitoring stack deployment validation:
- **Stack Deployment**: Monitoring namespace, pod deployment status, service configuration
- **Component Integration**: Prometheus metrics, Grafana dashboards, AlertManager rules, Jaeger tracing, Fluent Bit logging
- **Metrics Collection**: Kubelet metrics validation, service discovery verification
- **External Access**: Ingress validation for dashboard access

**t9-monitoring-status-tests.py**
Comprehensive monitoring stack status validation:
- **Infrastructure Validation**: Namespace existence, pod readiness (7 comprehensive tests)
- **Service Testing**: ClusterIP assignments, correct port configurations, endpoint validation
- **Component Verification**: Prometheus API endpoint accessibility, Fluent Bit DaemonSet coverage across all nodes
- **Integration Status**: Complete stack status display with real-time output validation
- **Expected Components**: All 5 monitoring components (Prometheus, Grafana, AlertManager, Jaeger, Fluent Bit) operational

### Running Phase 3 Validation

**Comprehensive validation and load testing:**
```bash
# Run all validation and load tests
./test/run-t4-tests.sh
```

**Manual testing:**
```bash
# Run deployment validation and load tests directly
pytest test/t4-validate-deployment.py -v -s
```

**Individual test categories:**
```bash
# Deployment validation only
pytest test/t4-validate-deployment.py::TestDeploymentValidation -v

# Load testing only  
pytest test/t4-validate-deployment.py::TestLoadTesting -v -s
```

### Running Monitoring Stack Validation

**Phase 8 - Monitoring deployment testing:**
```bash
# Run monitoring stack deployment tests
python3 test/t8-monitoring-tests.py -v

# Run automated monitoring deployment
./scripts/setup-monitoring.sh
```

**Phase 9 - Monitoring status validation:**
```bash
# Run monitoring status tests
python3 test/t9-monitoring-status-tests.py

# Run with verbose output
python3 test/t9-monitoring-status-tests.py -v
```

**Complete monitoring validation:**
```bash
# Manual monitoring stack status check (executed by t9 tests)
echo "=== Monitoring Stack Status ===" && \
kubectl get pods -n monitoring && \
echo -e "\n=== Services ===" && \
kubectl get svc -n monitoring && \
echo -e "\n=== Ingresses ===" && \
kubectl get ingress -n monitoring
```

## Test Reporting

### Comprehensive Reports

The test suite generates detailed reports including:

**HTML Report Features:**
- Executive summary with key metrics
- Cluster status and node information
- Application deployment details
- Pod distribution across nodes
- Performance testing results with charts
- Test conclusions and recommendations

**JSON Reports:**
- `cluster_status_*.json` - Detailed cluster information
- `application_status_*.json` - Application deployment data
- `performance_results_*.json` - Load testing metrics

### Generating Reports

**Automated report generation:**
```bash
# Generate reports during test execution
./test/run-t4-tests.sh

# Generate reports independently
./test/generate-reports.sh
```

**Manual report generation:**
```bash
# Run tests with reporting
python3 test/t4-validate-deployment.py

# Generate report from existing data
python3 -c "from test.test_reporter import generate_comprehensive_report; generate_comprehensive_report()"
```

**Report Location:**
- Reports are saved to `./test/reports/` directory
- HTML reports: `deployment_report_YYYYMMDD_HHMMSS.html`
- JSON reports: `*_status_YYYYMMDD_HHMMSS.json`

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

# Run NGINX access tests
pytest test/t3-nginx-access.py -v

# Run deployment validation and load tests
pytest test/t4-validate-deployment.py -v

# Run monitoring stack deployment tests
python3 test/t8-monitoring-tests.py -v

# Run monitoring status validation tests
python3 test/t9-monitoring-status-tests.py -v

# Run all tests
pytest test/ -v
```

**Automated execution:**
```bash
# Run Milestone 1 tests (includes setup)
./test/run-t1-tests.sh

# Run Milestone 2 tests (includes deployment)
./test/run-t2-tests.sh

# Run NGINX access tests (includes deployment)
./test/run-t3-tests.sh

# Run Phase 3 validation and load tests
./test/run-t4-tests.sh
```

## Test Requirements

- Python 3.x
- pytest (installed via requirements.txt)
- kubectl configured and cluster accessible
- Cluster must be running (use `./scripts/setup-cluster.sh`)
- For t2 tests: Application must be deployed (automatic via test runner)
- For t8/t9 tests: Monitoring stack must be deployed (use `./scripts/setup-monitoring.sh`)

### Monitoring Stack Dependencies

**Phase 8/9 Requirements:**
- kubectl configured for cluster access
- Monitoring stack deployed in 'monitoring' namespace
- All monitoring components operational: Prometheus, Grafana, AlertManager, Jaeger, Fluent Bit
- Ingress configuration for external dashboard access

## Test Output

Pytest provides:
- Detailed test results with pass/fail status
- Clear assertion error messages
- Test execution summary
- Exit code 0 for success, non-zero for failure (CI/CD friendly)
- Multiple output formats (verbose, short, etc.)