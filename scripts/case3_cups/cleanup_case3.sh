#!/usr/bin/env bash
# ==============================================================================
# cleanup_case3.sh - Tear down Case 3 CUPS components (CU-CP, CU-UP, DU, and UE)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

log_step "Tearing down Case 3 CUPS RAN components in namespace '${NAMESPACE}'..."

log_info "Uninstalling UE release 'nrue' if present..."
khelm uninstall nrue 2>/dev/null || true

log_info "Uninstalling DU release 'du' (or case2-du) if present..."
khelm uninstall du 2>/dev/null || true

log_info "Uninstalling CU-UP release 'cuup' (or case3-cuup) if present..."
khelm uninstall cuup 2>/dev/null || true
khelm uninstall case3-cuup 2>/dev/null || true

log_info "Uninstalling CU-CP release 'cucp' (or case3-cucp) if present..."
khelm uninstall cucp 2>/dev/null || true
khelm uninstall case3-cucp 2>/dev/null || true

log_info "Waiting for pods to terminate..."
sleep 3
kctl get pods -l "app.kubernetes.io/name in (oai-cu-cp, oai-cu-up, oai-du, oai-nr-ue)" 2>/dev/null || true

log_success "Case 3 cleanup completed."
