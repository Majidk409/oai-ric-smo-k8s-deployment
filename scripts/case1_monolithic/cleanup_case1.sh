#!/usr/bin/env bash
# ==============================================================================
# cleanup_case1.sh - Tear down Case 1 RAN components (gNB and UE)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

log_step "Tearing down Case 1 RAN components in namespace '${NAMESPACE}'..."

log_info "Uninstalling UE release 'nrue' if present..."
khelm uninstall nrue 2>/dev/null || true

log_info "Uninstalling gNB release 'gnb' if present..."
khelm uninstall gnb 2>/dev/null || true

log_info "Waiting for pods to terminate..."
sleep 3
kctl get pods -l "app.kubernetes.io/name in (oai-gnb, oai-nr-ue)" 2>/dev/null || true

log_success "Case 1 cleanup completed."
