#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# BeeNut Master Fault Injection & Edge Case Test Suite
# ==============================================================================
# This script performs automated fault injection checks against the BeeNut
# Flutter UI and C++ Native Daemon to verify system resilience.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "======================================================================"
echo "⚡ RUNNING BEENUT FAULT INJECTION & EDGE CASE TEST SUITE"
echo "======================================================================"

FAILED=0

pass_test() {
    echo -e "  [PASS] $1"
}

fail_test() {
    echo -e "  [FAIL] $1"
    FAILED=$((FAILED + 1))
}

# Test Case 1: Missing Config Handling
echo "[1/4] Testing Missing/Corrupt Machine Config Resilience..."
if flutter test test/models_test.dart > /dev/null 2>&1; then
    pass_test "Config schema handles empty / missing JSON keys gracefully"
else
    fail_test "Config schema failed on empty / missing keys"
fi

# Test Case 2: Kiosk Pause & Blur Visual State
echo "[2/4] Testing Camera Pause & Blur Filter Safety..."
if flutter test test/kiosk_pause_blur_test.dart > /dev/null 2>&1; then
    pass_test "Kiosk pause UI displays blur filter overlay and disables AI boxes cleanly"
else
    fail_test "Kiosk pause UI test failed"
fi

# Test Case 3: Catalog Selection Bounds & Overflow Protection
echo "[3/4] Testing Catalog Part Switcher & Extreme Digit Bounds..."
if flutter test test/part_selection_catalog_test.dart > /dev/null 2>&1; then
    pass_test "Catalog part selector and large count bounds stay overflow-free"
else
    fail_test "Catalog part selector or count bounds test failed"
fi

# Test Case 4: Native C++ Engine Service Tests (if built)
echo "[4/4] Testing Native C++ Engine Logic & State Machine..."
if [ -f "${ROOT_DIR}/service/build/tests/service_tests" ]; then
    if "${ROOT_DIR}/service/build/tests/service_tests" > /dev/null 2>&1; then
        pass_test "Native C++ daemon tests passed successfully"
    else
        fail_test "Native C++ daemon tests failed"
    fi
else
    echo "  [SKIP] Native C++ daemon test binary not built yet (service/build/tests/service_tests)"
fi

echo "======================================================================"
if [ "$FAILED" -eq 0 ]; then
    echo "🎉 ALL FAULT INJECTION TESTS PASSED SUCCESSFULLY!"
    exit 0
else
    echo "❌ $FAILED FAULT INJECTION TEST(S) FAILED."
    exit 1
fi
