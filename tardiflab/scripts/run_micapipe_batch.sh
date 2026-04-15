#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
run_micapipe_batch.sh
---------------------
Route one logical module across many subjects/sessions, either locally or by
submitting cluster jobs.

Required:
  --config FILE          Path to launcher config file
  --profile NAME         Dataset profile name
  --module NAME          Logical module name

Optional:
  --mode MODE            local | cluster  (default: local)
  --subjects LIST        Comma-separated subjects, e.g. 01,02,03
  --sessions LIST        Comma-separated sessions, e.g. 1,2
  --queue NAME           Cluster queue (default: config DEFAULT_QUEUE)
  --vmem GB              Override per-job requested memory in GB
  --runner FILE          Override single-subject runner script
  --dry-run              Print commands and do not execute
  --help                 Show this message
  --                     Pass remaining arguments through to the module runner

Examples:
  # Debug one subject locally
  run_micapipe_batch.sh --config micapipe_lab_config.sh --profile ds-mwc --module volumetric \
      --mode local --subjects 01 --sessions 1 --profile ds-mwc

  # Submit DWI jobs for several subjects
  run_micapipe_batch.sh --config micapipe_lab_config.sh --profile ds-mwc --module dwi \
      --mode cluster --subjects 01,02,03 --sessions 1
EOF
}

CONFIG_FILE="${MICAPIPE_LAB_CONFIG:-}"
MODULE=""
MODE="local"
SUBJECTS_RAW=""
SESSIONS_RAW=""
PROFILE=""
QUEUE=""
VMEM_OVERRIDE=""
RUNNER=""
DRY_RUN=0
PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"; shift 2 ;;
    --profile)
      PROFILE="$2"; shift 2 ;;
    --module)
      MODULE="$2"; shift 2 ;;
    --mode)
      MODE="$2"; shift 2 ;;
    --subjects)
      SUBJECTS_RAW="$2"; shift 2 ;;
    --sessions)
      SESSIONS_RAW="$2"; shift 2 ;;
    --queue)
      QUEUE="$2"; shift 2 ;;
    --vmem)
      VMEM_OVERRIDE="$2"; shift 2 ;;
    --runner)
      RUNNER="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --help|-h)
      usage; exit 0 ;;
    --)
      shift
      PASSTHROUGH=("$@")
      break ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

if [[ -z "${CONFIG_FILE}" ]]; then
  echo "ERROR: no config file provided. Use --config or MICAPIPE_LAB_CONFIG." >&2
  exit 1
fi
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: config file not found: ${CONFIG_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

if [[ -z "${PROFILE}" ]]; then
  echo "ERROR: --profile is required." >&2
  exit 1
fi
if [[ -z "${MODULE}" ]]; then
  echo "ERROR: --module is required." >&2
  usage >&2
  exit 1
fi

export MICAPIPE_PROFILE="${PROFILE}"
#MICAPIPE="${MICAPIPE_ROOT}"
# shellcheck disable=SC1090
source "${MICAPIPE}/tardiflab/core/profile_loader.sh"

if ! micapipe_profile_enabled; then
  echo "ERROR: profile loader did not activate profile '${PROFILE}'." >&2
  exit 1
fi

if ! micapipe_profile_file_exists "${MICAPIPE_PROFILE_DATASET}"; then
  echo "ERROR: dataset.sh not found for profile '${PROFILE}'." >&2
  echo "Expected: ${MICAPIPE_PROFILE_DATASET}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${MICAPIPE_PROFILE_DATASET}"

: "${LOG_DIR:?ERROR: LOG_DIR must be defined in ${MICAPIPE_PROFILE_DATASET}}"

if [[ -z "${QUEUE}" ]]; then
  if [[ -n "${PROFILE_DEFAULT_QUEUE:-}" ]]; then
    QUEUE="${PROFILE_DEFAULT_QUEUE}"
  else
    QUEUE="${DEFAULT_QUEUE:-all.q}"
  fi
fi

if [[ -z "${RUNNER}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  RUNNER="${SCRIPT_DIR}/run_micapipe_module.sh"
fi
if [[ ! -x "${RUNNER}" ]]; then
  echo "ERROR: runner script is not executable: ${RUNNER}" >&2
  exit 1
fi

default_vmem_for_module() {
  if declare -f profile_default_vmem_for_module >/dev/null 2>&1; then
    profile_default_vmem_for_module "$1"
    return
  fi

  case "$1" in
    volumetric)       echo 6 ;;
    post_structural)  echo 3 ;;
    dwi)              echo 25 ;;
    noddi)            echo 10 ;;
    SC)               echo 50 ;;
    commit_prep)      echo 5 ;;
    commit)           echo 50 ;;
    connectomes)      echo 10 ;;
    FC)               echo 20 ;;
    pre_COMMIT)       echo 10 ;;
    proc_COMMIT)      echo 40 ;;
    conn_slice)       echo 5 ;;
    *)                echo 8 ;;
  esac
}

parse_csv_or_default() {
  local raw="$1"
  shift
  local -a defaults=("$@")
  if [[ -n "${raw}" ]]; then
    IFS=',' read -r -a out <<< "${raw}"
    printf '%s\n' "${out[@]}"
  else
    printf '%s\n' "${defaults[@]}"
  fi
}

SUBJECTS=()
SESSIONS=()
mapfile -t SUBJECTS < <(parse_csv_or_default "${SUBJECTS_RAW}" "${DEFAULT_SUBJECTS[@]:-}")
mapfile -t SESSIONS < <(parse_csv_or_default "${SESSIONS_RAW}" "${DEFAULT_SESSIONS[@]:-}")

if [[ ${#SUBJECTS[@]} -eq 0 || -z "${SUBJECTS[0]}" ]]; then
  echo "ERROR: no subjects provided and DEFAULT_SUBJECTS is empty in ${MICAPIPE_PROFILE_DATASET}." >&2
  exit 1
fi
if [[ ${#SESSIONS[@]} -eq 0 || -z "${SESSIONS[0]}" ]]; then
  echo "ERROR: no sessions provided and DEFAULT_SESSIONS is empty in ${MICAPIPE_PROFILE_DATASET}." >&2
  exit 1
fi

VMEM="${VMEM_OVERRIDE:-$(default_vmem_for_module "${MODULE}")}"

mkdir -p "${LOG_DIR}"
LOG_FUNC_DIR="${LOG_DIR}/${MODULE}"
mkdir -p "${LOG_FUNC_DIR}"

submit_local() {
  local sub="$1"
  local ses="$2"

  local cmd=(
    "${RUNNER}"
    --config "${CONFIG_FILE}"
    --profile "${PROFILE}"
    --sub "${sub}"
    --ses "${ses}"
    --module "${MODULE}"
  )
  if [[ ${#PASSTHROUGH[@]} -gt 0 ]]; then
    cmd+=(-- "${PASSTHROUGH[@]}")
  fi

  echo "[local] ${cmd[*]}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 0
  fi
  "${cmd[@]}"
}

submit_cluster() {
  local sub="$1"
  local ses="$2"
  local ses_label="ses-${ses#ses-}"
  local sub_label="sub-${sub#sub-}"
  local work_dir="${LOG_FUNC_DIR}/${sub_label}_${ses_label}"
  mkdir -p "${work_dir}"

  local job_name="${MODULE}_${sub#sub-}_${ses#ses-}"
  local cmd=(
    "${QBATCH_BIN:-qbatch}"
    -q "${QUEUE}"
    -verbose
    -l "h_vmem=${VMEM}G"
    -N "${job_name}"
    /usr/bin/time --verbose
    "${RUNNER}"
    --config "${CONFIG_FILE}"
    --profile "${PROFILE}"
    --sub "${sub}"
    --ses "${ses}"
    --module "${MODULE}"
  )
  if [[ ${#PASSTHROUGH[@]} -gt 0 ]]; then
    cmd+=(-- "${PASSTHROUGH[@]}")
  fi

  echo "[cluster] cd ${work_dir} && ${cmd[*]}"
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 0
  fi

  (
    cd "${work_dir}"
    "${cmd[@]}"
  )
}

case "${MODE}" in
  local|cluster) ;;
  *)
    echo "ERROR: --mode must be 'local' or 'cluster'." >&2
    exit 1 ;;
esac

for sub in "${SUBJECTS[@]}"; do
  for ses in "${SESSIONS[@]}"; do
    if [[ "${MODE}" == "local" ]]; then
      submit_local "${sub}" "${ses}"
    else
      submit_cluster "${sub}" "${ses}"
    fi
  done
done
