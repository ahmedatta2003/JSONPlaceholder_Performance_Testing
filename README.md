# JSONPlaceholder API – Performance Testing with Apache JMeter

## Project Overview

This project contains a complete performance testing suite for the **JSONPlaceholder API** (`https://jsonplaceholder.typicode.com`), a free REST API used for testing and prototyping. The test suite covers four performance test scenarios using **Apache JMeter 5.6+** with full parameterization, correlation, assertions, and automated CLI execution.

---

## API Under Test

| Base URL | `https://jsonplaceholder.typicode.com` |
|---|---|
| Protocol | HTTPS |
| Format | JSON |
| Auth | None required |

### Endpoints Tested

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/posts` | Retrieve all posts |
| GET | `/posts/{id}` | Retrieve single post by ID |
| GET | `/users` | Retrieve all users |
| GET | `/users/{id}` | Retrieve single user |
| GET | `/comments?postId={id}` | Get comments by post (correlated) |
| GET | `/todos` | Retrieve all todos |
| POST | `/posts` | Create new post |
| PUT | `/posts/{id}` | Full update of a post |
| PATCH | `/posts/{id}` | Partial update of a post |
| DELETE | `/posts/{id}` | Delete a post |

---

## Project Structure

```
JSONPlaceholder_Performance_Testing/
├── test-plans/
│   ├── 01_Load_Test.jmx          ← Main load test (100-500 users)
│   ├── 02_Stress_Test.jmx        ← Stress test (100 → 1000 users, staged)
│   ├── 03_Spike_Test.jmx         ← Spike test (burst 800 users in 10s)
│   └── 04_Light_Smoke_Test.jmx   ← Smoke/sanity test (5 users, 1 loop)
│
├── test-data/
│   └── users.csv                  ← 20 rows of parameterized test data
│
├── results/                       ← .jtl output files (auto-created)
├── reports/                       ← HTML dashboard reports (auto-created)
│
└── scripts/
    ├── run_tests.sh               ← Linux/macOS CLI runner
    └── run_tests.bat              ← Windows CLI runner
```

---

## Test Scenarios

### 1. Light / Smoke Test (`04_Light_Smoke_Test.jmx`)
- **Users:** 5 virtual users  
- **Loops:** 1 iteration each  
- **Ramp-up:** 5 seconds  
- **Purpose:** Sanity check — verify all endpoints are reachable and returning correct status codes before running heavier tests  
- **On failure:** Stops entire test (`stoptest`)

### 2. Load Test (`01_Load_Test.jmx`)
- **Users:** 100 concurrent users (GET) + 50 users (Write operations)  
- **Duration:** 300 seconds  
- **Ramp-up:** 60 seconds  
- **Purpose:** Validate system behavior under expected normal production load  
- **Includes:** Parameterization via CSV, correlation via JSON Extractor, response time assertions (< 3000ms)

### 3. Stress Test (`02_Stress_Test.jmx`)
- **Stages (sequential):**
  - Stage 1: 100 users × 120s — Baseline  
  - Stage 2: 300 users × 120s — Medium load  
  - Stage 3: 600 users × 120s — Heavy load  
  - Stage 4: 1000 users × 120s — Breaking point  
- **Purpose:** Find the point at which the system degrades or fails  
- **Total duration:** ~10 minutes

### 4. Spike Test (`03_Spike_Test.jmx`)
- **Pre-spike:** 20 users (60 seconds baseline)  
- **Spike:** 800 users ramped in 10 seconds (60 seconds)  
- **Post-spike:** 20 users (60 seconds recovery check)  
- **Purpose:** Simulate sudden traffic burst (e.g., flash sales, viral events) and measure recovery time

---

## Advanced JMeter Features Used

### Parameterization
- **CSV Data Set Config** reads `test-data/users.csv`
- Variables: `userId`, `userName`, `userEmail`, `postTitle`, `postBody`
- Mode: `recycle=true` — loops through all rows indefinitely
- Used in POST/PUT request bodies and path parameters (`/posts/${userId}`)

### Correlation
Two JSON Path Extractors are configured:
1. **`extractedPostId`** — extracts `$.id` from GET `/posts/{id}` response → used in subsequent GET `/comments?postId=${extractedPostId}`
2. **`createdPostId`** — extracts `$.id` from POST `/posts` response → used in PUT `/posts/${createdPostId}`

This simulates a real user flow where data from one request feeds the next.

### Assertions
- **Response Assertion:** Validates HTTP status codes (200, 201)
- **Duration Assertion:** Flags responses exceeding thresholds (2000ms – 5000ms)
- **JSON Path Assertion:** Verifies JSON structure in responses

### Timers
- `UniformRandomTimer` (1000ms base + 0-2000ms random) on GET operations
- `ConstantTimer` (500ms) on Smoke Test
- Simulates realistic think time between user actions

---

## Prerequisites

1. **Apache JMeter 5.6+** — [Download](https://jmeter.apache.org/download_jmeter.cgi)
2. **Java 11+** — Required by JMeter
3. Internet access to `jsonplaceholder.typicode.com`

### Verify Installation
```bash
# Check Java
java -version

# Check JMeter
/opt/apache-jmeter/bin/jmeter --version
```

---

## Running Tests

### Option A: JMeter GUI (Development & Debugging)
```bash
# Open JMeter GUI
/opt/apache-jmeter/bin/jmeter

# File > Open > select any .jmx from test-plans/
# Click the green Play button ▶
```
> **Note:** GUI mode is for test design only. Use CLI mode for actual test execution.

### Option B: CLI (Recommended for Test Execution)

**Linux / macOS:**
```bash
# Make script executable
chmod +x scripts/run_tests.sh

# Run smoke test first
./scripts/run_tests.sh smoke

# Run load test
./scripts/run_tests.sh load

# Run stress test
./scripts/run_tests.sh stress

# Run spike test
./scripts/run_tests.sh spike

# Run all tests in sequence
./scripts/run_tests.sh all
```

**Windows:**
```cmd
scripts\run_tests.bat smoke
scripts\run_tests.bat load
scripts\run_tests.bat stress
scripts\run_tests.bat spike
scripts\run_tests.bat all
```

### Option C: Manual JMeter CLI Command
```bash
# General syntax
jmeter -n -t <test.jmx> -l <results.jtl> -e -o <report-dir>

# Load test with parameter override
jmeter -n \
  -t test-plans/01_Load_Test.jmx \
  -l results/load_results.jtl \
  -e -o reports/load_report \
  -JTHREADS=200 \
  -JRAMP_UP=120 \
  -JDURATION=600

# Smoke test
jmeter -n \
  -t test-plans/04_Light_Smoke_Test.jmx \
  -l results/smoke_results.jtl \
  -e -o reports/smoke_report
```

### Override Test Parameters at Runtime
```bash
# Run load test with 200 users instead of default 100
jmeter -n -t test-plans/01_Load_Test.jmx \
  -JTHREADS=200 \
  -JRAMP_UP=90 \
  -JDURATION=600 \
  -l results/load_200users.jtl \
  -e -o reports/load_200users_report
```

---

## Reports & Analysis

After each test run, an HTML dashboard is generated in `reports/`. Open `index.html` in any browser.

### Key Metrics to Analyze

| Metric | Target | Location in Report |
|--------|--------|--------------------|
| **APDEX Score** | > 0.85 (satisfied) | Dashboard Overview |
| **Average Response Time** | < 1000ms | Statistics Table |
| **90th Percentile (P90)** | < 2000ms | Response Time Percentiles |
| **95th Percentile (P95)** | < 3000ms | Response Time Percentiles |
| **99th Percentile (P99)** | < 5000ms | Response Time Percentiles |
| **Throughput (req/sec)** | Maximize | Throughput Over Time |
| **Error Rate** | < 1% | Statistics Table |
| **Active Threads** | Matches config | Active Threads Over Time |

### APDEX Thresholds
- **Satisfied:** Response time ≤ 500ms
- **Tolerating:** 500ms < Response time ≤ 1500ms
- **Frustrated:** Response time > 1500ms

### Interpreting Results

**Good Performance Signs:**
- APDEX > 0.85
- Error rate < 1%
- Response time increases linearly (not exponentially) with users
- System recovers quickly after spike

**Performance Bottleneck Signs:**
- Error rate spikes above 5% at high user counts
- P99 latency > 10x average latency
- Throughput plateaus while user count increases
- System does not recover to baseline after spike ends

---

## JTL File Analysis

JTL files in `results/` can be analyzed with:
```bash
# Generate report from existing JTL
jmeter -g results/load_test_results.jtl -o reports/manual_report

# View JTL as CSV (it IS a CSV)
head -5 results/load_test_results.jtl
```

JTL columns: `timeStamp, elapsed, label, responseCode, responseMessage, threadName, dataType, success, failureMessage, bytes, sentBytes, grpThreads, allThreads, URL, Latency, IdleTime, Connect`

---

## Performance Test Best Practices Applied

1. **Always run Smoke Test first** — catches configuration errors before wasting time
2. **Non-GUI mode for execution** — GUI adds overhead and distorts results
3. **Think time between requests** — simulates real human behavior
4. **Parameterization** — avoids server-side caching from repeated identical requests
5. **Correlation** — links dynamic values across requests for realistic flows
6. **Assertions** — catches functional regression during performance runs
7. **Separate Thread Groups** — read vs write operations have different concurrency levels
8. **Ramp-up period** — gradual user arrival prevents artificial spike at start
9. **Duration-based tests** — more realistic than fixed loop counts

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `JMeter not found` | Update `JMETER_HOME` in script or check installation path |
| `Connection refused` | Check internet access to jsonplaceholder.typicode.com |
| `CSV file not found` | Run scripts from project root, or use absolute paths in CSV Data Set |
| `OutOfMemoryError` | Increase JVM heap: edit `jmeter.bat`/`jmeter.sh`, set `-Xms1g -Xmx4g` |
| `Report dir exists` | Delete old report directory before re-running, or use timestamped dirs |
| High error rate on 1000 users | JSONPlaceholder is a free service with rate limits — expected behavior |

---

## Tools & Technologies

| Tool | Version | Purpose |
|------|---------|---------|
| Apache JMeter | 5.6.3 | Test execution engine |
| Java JDK | 11+ | JMeter runtime |
| JSONPlaceholder API | - | System under test |
| JMeter HTML Dashboard | Built-in | Report visualization |
| CSV Data Set Config | Built-in | Parameterization |
| JSON Path Extractor | Built-in | Correlation |
| Bash / Batch scripts | - | Automated CLI execution |

---

*Project: JSONPlaceholder API Performance Testing Suite*  
*Tool: Apache JMeter 5.6.3*
