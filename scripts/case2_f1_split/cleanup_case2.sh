#!/usr/bin/env bash
# ==============================================================================
# cleanup_case2.sh - Tear down Case 2 RAN components (CU, DU, and UE)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

log_step "Tearing down Case 2 RAN components in namespace '${NAMESPACE}'..."

log_info "Uninstalling UE release 'nrue' if present..."
khelm uninstall nrue 2>/dev/null || true

log_info "Uninstalling DU release 'du' (or case2-du) if present..."
khelm uninstall du 2>/dev/null || true
khelm uninstall case2-du 2>/dev/null || true

log_info "Uninstalling CU release 'cu' (or case2-cu) if present..."
khelm uninstall cu 2>/dev/null || true
khelm uninstall case2-cu 2>/dev/null || true

log_info "Waiting for pods to terminate..."
sleep 3
kctl get pods -l "app.kubernetes.io/name in (oai-cu, oai-du, oai-nr-ue)" 2>/dev/null || true

log_success "Case 2 cleanup completed."
