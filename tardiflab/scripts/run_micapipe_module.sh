#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
run_micapipe_module.sh
----------------------
Run one micapipe module for one subject/session.

Required:
  --config FILE          Path to launcher config file
  --profile NAME         Dataset profile name
  --sub ID               Subject ID without "sub-" prefix, e.g. 01
  --module NAME          Logical module name

Optional:
  --ses ID               Session number or label, e.g. 1 or ses-1 (default: 1)
  --dry-run              Print command and exit
  --help                 Show this message
  --                     Pass remaining arguments directly to micapipe
EOF
}

CONFIG_FILE="${MICAPIPE_LAB_CONFIG:-}"
SUB=""
SES="1"
MODULE=""
PROFILE=""
DRY_RUN=0
PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"; shift 2 ;;
    --profile)
      PROFILE="$2"; shift 2 ;;
    --sub)
      SUB="$2"; shift 2 ;;
    --ses)
      SES="$2"; shift 2 ;;
    --module)
      MODULE="$2"; shift 2 ;;
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
if [[ -z "${SUB}" || -z "${MODULE}" ]]; then
  echo "ERROR: --sub and --module are required." >&2
  usage >&2
  exit 1
fi

if [[ ! -x "${MICAPIPE_BIN}" ]]; then
  echo "ERROR: MICAPIPE_BIN is not executable: ${MICAPIPE_BIN}" >&2
  exit 1
fi

export MICAPIPE_PROFILE="${PROFILE}"

# Resolve profile and dataset files
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

# Required dataset vars
: "${BIDS_DIR:?ERROR: BIDS_DIR must be defined in ${MICAPIPE_PROFILE_DATASET}}"
: "${OUT_DIR:?ERROR: OUT_DIR must be defined in ${MICAPIPE_PROFILE_DATASET}}"
: "${LOG_DIR:?ERROR: LOG_DIR must be defined in ${MICAPIPE_PROFILE_DATASET}}"

# Normalize IDs
SUB="${SUB#sub-}"
if [[ "${SES}" != ses-* ]]; then
  SES="ses-${SES}"
fi

build_micapipe_args() {
  local module="$1"
  case "${module}" in
    volumetric)
      printf '%s\n' "-proc_structural"
      ;;
    post_structural)
      printf '%s\n' "-post_structural"
      ;;
    dwi)
      printf '%s\n' "-dwi_upscale" "-proc_dwi"
      ;;
    SC)
      printf '%s\n' "-tracts" "3M" "-filter" "COMMIT" "-reg_lambda" "15e-1" "-SC"
      ;;
    FC)
      printf '%s\n' "-nocleanup" "-NSR" "-dropTR" "-manual_ICRemoval" "-noFIX" "-proc_func"
      ;;
    *)
      return 127
      ;;
  esac
}

maybe_run_custom_module() {
  if [[ -n "${MICAPIPE_CUSTOM_MODULE_DISPATCH:-}" && -f "${MICAPIPE_CUSTOM_MODULE_DISPATCH}" ]]; then
    # shellcheck disable=SC1090
    source "${MICAPIPE_CUSTOM_MODULE_DISPATCH}"
    if declare -f micapipe_custom_module_dispatch >/dev/null 2>&1; then
      micapipe_custom_module_dispatch "${MODULE}" "${SUB}" "${SES}" "${PASSTHROUGH[@]}"
      return $?
    fi
  fi
  return 127
}

MODULE_ARGS=()
if mapfile -t MODULE_ARGS < <(build_micapipe_args "${MODULE}"); then
  :
else
  MODULE_ARGS=()
fi

if [[ ${#MODULE_ARGS[@]} -eq 0 ]]; then
  if maybe_run_custom_module; then
    exit 0
  else
    echo "ERROR: unrecognized module '${MODULE}' and no custom handler accepted it." >&2
    exit 1
  fi
fi

CMD=(
  "${MICAPIPE_BIN}"
  -sub "${SUB}"
  -out "${OUT_DIR}"
  -bids "${BIDS_DIR}"
  -ses "${SES}"
  "${MODULE_ARGS[@]}"
  "${PASSTHROUGH[@]}"
)

echo "Profile : ${MICAPIPE_PROFILE}"
echo "Subject : sub-${SUB}"
echo "Session : ${SES}"
echo "Module  : ${MODULE}"
echo "Command : ${CMD[*]}"

if [[ "${DRY_RUN}" == "1" ]]; then
  exit 0
fi

exec "${CMD[@]}"
