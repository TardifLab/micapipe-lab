#/bin/bash
#
# Master loader for dataset-specific profiles.
# Resolves the active dataset profile from MICAPIPE_PROFILE
# and exposes standard profile paths/helper functions.
#
# Expected to be sourced from the main micapipe router in micapipe-lab.
#
# 2026 Mark C Nelson MNI
#------------------------------------------------------------------------------------------------------------------------------------

echo "[profile_loader.sh] loaded" >&2

# --- This causes problems sometimes
## Check if profile_loader already sourced
#if [[ "${MICAPIPE_PROFILE_LOADER_INITIALIZED:-0}" == "1" ]]; then
#    return 0
#fi

# Guard against accidental execution instead of sourcing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: tardiflab/profile_loader.sh must be sourced, not executed." >&2
    exit 1
fi

# Optional debug flag:
#   export MICAPIPE_PROFILE_DEBUG=1
_micapipe_profile_debug() {
    if [[ "${MICAPIPE_PROFILE_DEBUG:-0}" == "1" ]]; then
        echo "[profile_loader] $*" >&2
    fi
}

# Require MICAPIPE (repo root) to be defined by router first
if [[ -z "${MICAPIPE:-}" ]]; then
    echo "ERROR: MICAPIPE is not defined before sourcing tardiflab/profile_loader.sh" >&2
    return 1
fi

# Namespace root for lab additions
export MICAPIPE_TARDIFLAB_DIR="${MICAPIPE}/tardiflab"
export MICAPIPE_PROFILES_DIR="${MICAPIPE_TARDIFLAB_DIR}/profiles"

# Initialize profile state
export MICAPIPE_PROFILE_ACTIVE="FALSE"
export MICAPIPE_PROFILE_NAME=""
export MICAPIPE_PROFILE_DIR=""
export MICAPIPE_PROFILE_INIT=""
export MICAPIPE_PROFILE_UTILS=""
export MICAPIPE_PROFILE_PARAMS=""
export MICAPIPE_PROFILE_MODULES=""
export MICAPIPE_PROFILE_DATASET=""

# Helper: whether a profile is active
micapipe_profile_enabled() {
    [[ "${MICAPIPE_PROFILE_ACTIVE}" == "TRUE" ]]
}

# Helper: whether a given file exists and is non-empty path
micapipe_profile_file_exists() {
    local f="$1"
    [[ -n "${f}" && -f "${f}" ]]
}

# Helper: source a file if it exists
micapipe_profile_source_if_exists() {
    local f="$1"
    if micapipe_profile_file_exists "${f}"; then
        _micapipe_profile_debug "Sourcing ${f}"
        # shellcheck disable=SC1090
        source "${f}"
        return 0
    fi
    return 1
}

# Helper: fail with profile-aware message
micapipe_profile_error() {
    echo "ERROR [profile:${MICAPIPE_PROFILE_NAME:-none}] $*" >&2
    return 1
}

# Resolve active profile from environment variable
if [[ -n "${MICAPIPE_PROFILE:-}" ]]; then
    export MICAPIPE_PROFILE_ACTIVE="TRUE"
    export MICAPIPE_PROFILE_NAME="${MICAPIPE_PROFILE}"
    export MICAPIPE_PROFILE_DIR="${MICAPIPE_PROFILES_DIR}/${MICAPIPE_PROFILE_NAME}"

    _micapipe_profile_debug "Requested profile: ${MICAPIPE_PROFILE_NAME}"
    _micapipe_profile_debug "Resolved profile dir: ${MICAPIPE_PROFILE_DIR}"

    # Basic validation
    if [[ ! -d "${MICAPIPE_PROFILE_DIR}" ]]; then
        echo "ERROR: Requested profile '${MICAPIPE_PROFILE_NAME}' does not exist." >&2
        echo "Expected directory: ${MICAPIPE_PROFILE_DIR}" >&2
        return 1
    fi

    # Standard optional files
    export MICAPIPE_PROFILE_INIT="${MICAPIPE_PROFILE_DIR}/init.sh"
    export MICAPIPE_PROFILE_UTILS="${MICAPIPE_PROFILE_DIR}/utilities.sh"
    export MICAPIPE_PROFILE_PARAMS="${MICAPIPE_PROFILE_DIR}/params.sh"
    export MICAPIPE_PROFILE_MODULES="${MICAPIPE_PROFILE_DIR}/modules.sh"
    export MICAPIPE_PROFILE_DATASET="${MICAPIPE_PROFILE_DIR}/dataset.sh"

    # Common-sense checks
    # 1) profile name should not contain path separators
    if [[ "${MICAPIPE_PROFILE_NAME}" == *"/"* ]]; then
        echo "ERROR: MICAPIPE_PROFILE should be a profile name, not a path." >&2
        return 1
    fi

    # 2) warn if profile directory exists but neither init nor utils nor params is present
    if [[ ! -f "${MICAPIPE_PROFILE_INIT}" && \
          ! -f "${MICAPIPE_PROFILE_UTILS}" && \
          ! -f "${MICAPIPE_PROFILE_PARAMS}" && \
          ! -f "${MICAPIPE_PROFILE_MODULES}" && \
          ! -f "${MICAPIPE_PROFILE_DATASET}" ]]; then
        echo "WARNING: Profile '${MICAPIPE_PROFILE_NAME}' exists but contains no recognized profile files." >&2
    fi
else
    _micapipe_profile_debug "No MICAPIPE_PROFILE set; using default micapipe behavior."
fi

# --- Removing this functionality for now
# Declare profile loading complete (to avoid repeated sourcing)
# Maybe remove later if we want profile_loader to load dataset-specific modules further down the line???
#export MICAPIPE_PROFILE_LOADER_INITIALIZED=1
