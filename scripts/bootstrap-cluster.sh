#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=scripts/_lib.sh
source "$(dirname "${0}")/_lib.sh"

export LOG_LEVEL="${LOG_LEVEL:-debug}"
ROOT_DIR="$(git rev-parse --show-toplevel)"

# Apply the Talos configuration to all the nodes
function apply_talos_config() {
    log debug "Applying Talos configuration"

    local talos_controlplane_file="${ROOT_DIR}/talos/${CLUSTER_NAME}/controlplane.yaml.j2"
    local talos_worker_file="${ROOT_DIR}/talos/${CLUSTER_NAME}/worker.yaml.j2"

    if [[ ! -f ${talos_controlplane_file} ]]; then
        log error "No Talos machine files found for controlplane" "file=${talos_controlplane_file}"
    fi

    # Skip worker configuration if no worker file is found
    if [[ ! -f ${talos_worker_file} ]]; then
        log warn "No Talos machine files found for worker" "file=${talos_worker_file}"
        talos_worker_file=""
    fi

    # Apply the Talos configuration to the controlplane and worker nodes
    for file in ${talos_controlplane_file} ${talos_worker_file}; do
        if ! nodes=$(talosctl config info --output json 2>/dev/null | jq --exit-status --raw-output '.nodes | join(" ")') || [[ -z "${nodes}" ]]; then
            log error "No Talos nodes found"
        fi

        log debug "Talos nodes discovered" "nodes=${nodes}"

        # Apply the Talos configuration
        for node in ${nodes}; do
            log debug "Applying Talos node configuration" "node=${node}"

            if ! machine_config=$(bash "${ROOT_DIR}/scripts/render-talos-machine-config.sh" "${file}" "${ROOT_DIR}/talos/${CLUSTER_NAME}/nodes/${node}.yaml.j2") || [[ -z "${machine_config}" ]]; then
                exit 1
            fi

            log info "Talos node configuration rendered successfully" "node=${node}"

            if ! output=$(echo "${machine_config}" | talosctl --nodes "${node}" apply-config --insecure --file /dev/stdin 2>&1);
            then
                if [[ "${output}" == *"certificate required"* ]]; then
                    log warn "Talos node is already configured, skipping apply of config" "node=${node}"
                    continue
                fi
                log error "Failed to apply Talos node configuration" "node=${node}" "output=${output}"
            fi

            log info "Talos node configuration applied successfully" "node=${node}"
        done
    done
}

# Bootstrap Talos on a controller node
function bootstrap_talos() {
    log debug "Bootstrapping Talos"

    if ! controller=$(talosctl config info --output json | jq --exit-status --raw-output '.endpoints[]' | shuf -n 1) || [[ -z "${controller}" ]]; then
        log error "No Talos controller found"
    fi

    log debug "Talos controller discovered" "controller=${controller}"

    until output=$(talosctl --nodes "${controller}" bootstrap 2>&1 || true) && [[ "${output}" == *"AlreadyExists"* ]]; do
        log info "Talos bootstrap in progress, waiting 10 seconds..." "controller=${controller}"
        sleep 10
    done

    log info "Talos is bootstrapped" "controller=${controller}"
}

# Fetch the kubeconfig from a controller node
function fetch_kubeconfig() {
    log debug "Fetching kubeconfig"

    if ! controller=$(talosctl config info --output json | jq --exit-status --raw-output '.endpoints[]' | shuf -n 1) || [[ -z "${controller}" ]]; then
        log error "No Talos controller found"
    fi

    if ! talosctl kubeconfig --nodes "${controller}" --force --force-context-name "${CLUSTER_NAME}" "$(basename "${KUBECONFIG}")" &>/dev/null; then
        log error "Failed to fetch kubeconfig"
    fi

    log info "Kubeconfig fetched successfully"
}

# Talos requires the nodes to be 'Ready=False' before applying resources
function wait_for_nodes() {
    log debug "Waiting for nodes to be available"

    # Skip waiting if all nodes are 'Ready=True'
    if kubectl wait nodes --for=condition=Ready=True --all --timeout=2s &>/dev/null; then
        log info "Nodes are available and ready, skipping wait for nodes"
        return
    fi

    # Wait for all nodes to be 'Ready=False'
    nodes_count=$(talosctl config info --output json 2>/dev/null | jq --exit-status --raw-output '.nodes[]' | wc -l)
    until [ "$(kubectl wait nodes --for=condition=Ready=False --all --timeout=10s 2> /dev/null | wc -l)" = "${nodes_count}" ]; do
        log info "Nodes are not available, waiting for nodes to be available. Retrying in 10 seconds..."
        sleep 10
    done

    # Wait for system pods
    for system_pod in kube-apiserver kube-controller-manager kube-scheduler; do
      until [ "$(kubectl -n kube-system wait pods --for=condition=Ready -l "app.kubernetes.io/name=${system_pod}" --all --timeout=10s 2> /dev/null | wc -l)" -ge 3 ]; do
            log info "System pods are not available, waiting for nodes to be available. Retrying in 10 seconds..."
            sleep 10
        done
    done
}

# CRDs to be applied before the helmfile charts are installed
function apply_crds() {
    log debug "Applying CRDs"

    mapfile -t crds < <(yq '.[]' "${ROOT_DIR}/bootstrap/crds.yaml")

    for crd in "${crds[@]}"; do
        if kubectl diff --filename "${crd}" &>/dev/null; then
            log info "CRDs are up-to-date" "crd=${crd}"
            continue
        fi
        if kubectl apply --server-side --filename "${crd}" &>/dev/null; then
            log info "CRDs applied" "crd=${crd}"
        else
            log error "Failed to apply CRDs" "crd=${crd}"
        fi
    done
}

# Resources to be applied before the helmfile charts are installed
function apply_resources() {
    log debug "Applying resources"

    local -r resources_file="${ROOT_DIR}/bootstrap/resources.yaml.j2"

    if ! output=$(render_template "${resources_file}") || [[ -z "${output}" ]]; then
        exit 1
    fi

    if echo "${output}" | kubectl diff --filename - &>/dev/null; then
        log info "Resources are up-to-date"
        return
    fi

    if echo "${output}" | kubectl apply --server-side --filename - &>/dev/null; then
        log info "Resources applied"
    else
        log error "Failed to apply resources"
    fi
}

# Apply Helm releases using helmfile
function apply_helm_releases() {
    log debug "Applying Helm releases with helmfile"

    local -r helmfile_file="${ROOT_DIR}/bootstrap/helmfile.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log error "File does not exist" "file=${helmfile_file}"
    fi

    if ! helmfile --file "${helmfile_file}" apply --hide-notes --skip-diff-on-install --suppress-diff --suppress-secrets; then
        log error "Failed to apply Helm releases"
    fi

    log info "Helm releases applied successfully"
}

# Provision cluster
function provision_cluster_via_argocd() {
    log debug "Provisioning cluster via ArgoCD"

    local -r app_file="${ROOT_DIR}/kubernetes/clusters/${CLUSTER_NAME}/application.yaml"

    if [[ ! -f "${app_file}" ]]; then
        log error "File does not exist" "file=${app_file}"
    fi

    if ! kubectl apply --filename "${app_file}"; then
        log error "Failed to apply ArgoCD application"
    fi

    log info "Cluster provisioned successfully"
}

function main() {
    check_env BWS_ACCESS_TOKEN CLUSTER_NAME KUBECONFIG KUBERNETES_VERSION TALOS_VERSION
    check_cli bws helmfile jq kubectl kustomize minijinja-cli talosctl yq

    if ! bws project list &>/dev/null; then
        log error "Failed to authenticate with Bitwarden CLI"
    fi

    # Bootstrap the Talos node configuration
    apply_talos_config
    bootstrap_talos
    fetch_kubeconfig

    # Apply resources and Helm releases
    wait_for_nodes
    apply_crds
    apply_resources
    apply_helm_releases
    provision_cluster_via_argocd

    log info "Congrats! The cluster is bootstrapped and ArgoCD is syncing the Git repository"
}

main "$@"
