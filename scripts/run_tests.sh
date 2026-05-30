#!/bin/bash
# ============================================================
# JSONPlaceholder API - JMeter Performance Test Runner
# ============================================================
# Usage:
#   ./run_tests.sh                    -> Run all tests
#   ./run_tests.sh smoke              -> Run smoke test only
#   ./run_tests.sh load               -> Run load test only
#   ./run_tests.sh stress             -> Run stress test only
#   ./run_tests.sh spike              -> Run spike test only
#   ./run_tests.sh report             -> Generate HTML report only
# ============================================================

set -e

# ── Configuration ──────────────────────────────────────────
JMETER_HOME="${JMETER_HOME:-/opt/apache-jmeter}"
JMETER_BIN="$JMETER_HOME/bin/jmeter"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLANS_DIR="$PROJECT_DIR/test-plans"
RESULTS_DIR="$PROJECT_DIR/results"
REPORTS_DIR="$PROJECT_DIR/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Helpers ────────────────────────────────────────────────
print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   JSONPlaceholder API - Performance Test Runner          ║${NC}"
    echo -e "${CYAN}║   Timestamp: $TIMESTAMP                          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_jmeter() {
    if [ ! -f "$JMETER_BIN" ]; then
        echo -e "${RED}[ERROR] JMeter not found at: $JMETER_BIN${NC}"
        echo -e "${YELLOW}[INFO]  Set JMETER_HOME environment variable or install JMeter at /opt/apache-jmeter${NC}"
        echo -e "${YELLOW}[INFO]  Download: https://jmeter.apache.org/download_jmeter.cgi${NC}"
        exit 1
    fi
    JMETER_VERSION=$("$JMETER_BIN" --version 2>&1 | grep "Version" | head -1)
    echo -e "${GREEN}[OK] JMeter found: $JMETER_VERSION${NC}"
}

create_dirs() {
    mkdir -p "$RESULTS_DIR" "$REPORTS_DIR"
    echo -e "${GREEN}[OK] Directories ready${NC}"
}

# ── Test Runner ────────────────────────────────────────────
run_test() {
    local TEST_NAME="$1"
    local JMX_FILE="$2"
    local JTL_FILE="$3"
    local REPORT_DIR="$4"
    local EXTRA_PROPS="$5"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}[START] Running: $TEST_NAME${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  JMX File  : $JMX_FILE"
    echo -e "  JTL Output: $JTL_FILE"
    echo -e "  Report Dir: $REPORT_DIR"
    echo ""

    # Remove old JTL to avoid append issues
    [ -f "$JTL_FILE" ] && rm -f "$JTL_FILE"
    [ -d "$REPORT_DIR" ] && rm -rf "$REPORT_DIR"

    START_TIME=$(date +%s)

    "$JMETER_BIN" \
        -n \
        -t "$JMX_FILE" \
        -l "$JTL_FILE" \
        -e \
        -o "$REPORT_DIR" \
        -Jsummariser.interval=10 \
        $EXTRA_PROPS \
        2>&1 | tee "$RESULTS_DIR/${TEST_NAME}_${TIMESTAMP}.log"

    EXIT_CODE=${PIPESTATUS[0]}
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}[PASS] $TEST_NAME completed in ${DURATION}s${NC}"
        echo -e "${GREEN}[REPORT] HTML report: $REPORT_DIR/index.html${NC}"
    else
        echo -e "${RED}[FAIL] $TEST_NAME failed with exit code $EXIT_CODE${NC}"
    fi

    return $EXIT_CODE
}

generate_combined_report() {
    echo ""
    echo -e "${CYAN}[INFO] Combining all JTL results into master report...${NC}"

    # Combine all JTL files (skip header for files after first)
    MASTER_JTL="$RESULTS_DIR/master_results_${TIMESTAMP}.jtl"
    FIRST=true
    for JTL in "$RESULTS_DIR"/*.jtl; do
        if [ -f "$JTL" ] && [[ "$JTL" != *"master"* ]]; then
            if $FIRST; then
                cp "$JTL" "$MASTER_JTL"
                FIRST=false
            else
                tail -n +2 "$JTL" >> "$MASTER_JTL"
            fi
        fi
    done

    if [ -f "$MASTER_JTL" ]; then
        MASTER_REPORT="$REPORTS_DIR/master_report_${TIMESTAMP}"
        mkdir -p "$MASTER_REPORT"
        "$JMETER_BIN" \
            -g "$MASTER_JTL" \
            -o "$MASTER_REPORT" \
            2>&1

        echo -e "${GREEN}[DONE] Master report: $MASTER_REPORT/index.html${NC}"
    fi
}

print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    TEST EXECUTION SUMMARY                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    for REPORT in "$REPORTS_DIR"/*/; do
        if [ -f "$REPORT/index.html" ]; then
            REPORT_NAME=$(basename "$REPORT")
            echo -e "  ${GREEN}✓${NC} $REPORT_NAME/index.html"
        fi
    done
    echo ""
    echo -e "  ${YELLOW}Open any report file in a browser to view full dashboard${NC}"
    echo ""
}

# ── Main Entry Point ───────────────────────────────────────
print_header
check_jmeter
create_dirs

MODE="${1:-all}"

case "$MODE" in
    smoke|light)
        run_test \
            "Smoke_Test" \
            "$PLANS_DIR/04_Light_Smoke_Test.jmx" \
            "$RESULTS_DIR/smoke_test_results.jtl" \
            "$REPORTS_DIR/smoke_report_${TIMESTAMP}"
        ;;
    load)
        run_test \
            "Load_Test" \
            "$PLANS_DIR/01_Load_Test.jmx" \
            "$RESULTS_DIR/load_test_results.jtl" \
            "$REPORTS_DIR/load_report_${TIMESTAMP}" \
            "-JTHREADS=100 -JRAMP_UP=60 -JDURATION=300"
        ;;
    stress)
        run_test \
            "Stress_Test" \
            "$PLANS_DIR/02_Stress_Test.jmx" \
            "$RESULTS_DIR/stress_test_results.jtl" \
            "$REPORTS_DIR/stress_report_${TIMESTAMP}"
        ;;
    spike)
        run_test \
            "Spike_Test" \
            "$PLANS_DIR/03_Spike_Test.jmx" \
            "$RESULTS_DIR/spike_test_results.jtl" \
            "$REPORTS_DIR/spike_report_${TIMESTAMP}"
        ;;
    report)
        generate_combined_report
        ;;
    all)
        echo -e "${YELLOW}[INFO] Running full test suite: Smoke → Load → Stress → Spike${NC}"

        run_test \
            "Smoke_Test" \
            "$PLANS_DIR/04_Light_Smoke_Test.jmx" \
            "$RESULTS_DIR/smoke_test_results.jtl" \
            "$REPORTS_DIR/smoke_report_${TIMESTAMP}"

        run_test \
            "Load_Test" \
            "$PLANS_DIR/01_Load_Test.jmx" \
            "$RESULTS_DIR/load_test_results.jtl" \
            "$REPORTS_DIR/load_report_${TIMESTAMP}" \
            "-JTHREADS=100 -JRAMP_UP=60 -JDURATION=300"

        run_test \
            "Stress_Test" \
            "$PLANS_DIR/02_Stress_Test.jmx" \
            "$RESULTS_DIR/stress_test_results.jtl" \
            "$REPORTS_DIR/stress_report_${TIMESTAMP}"

        run_test \
            "Spike_Test" \
            "$PLANS_DIR/03_Spike_Test.jmx" \
            "$RESULTS_DIR/spike_test_results.jtl" \
            "$REPORTS_DIR/spike_report_${TIMESTAMP}"

        generate_combined_report
        ;;
    *)
        echo -e "${RED}[ERROR] Unknown mode: $MODE${NC}"
        echo "Usage: $0 [smoke|load|stress|spike|report|all]"
        exit 1
        ;;
esac

print_summary
echo -e "${GREEN}[DONE] All tests completed at $(date)${NC}"
