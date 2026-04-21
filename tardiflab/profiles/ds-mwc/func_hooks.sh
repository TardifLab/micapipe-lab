#!/usr/bin/env bash
#
# These helpers allow for profile override of the built-in micapipe func proc module
#
# 2026 Mark C Nelson MNI
#------------------------------------------------------------------------------------------------------------------------------------

echo "[ds-mwc func_hooks.sh] loaded" >&2

# -------------------------------------------------------------------------
# --- Profile control of ICA-FIX
# -------------------------------------------------------------------------
# The user should set the value of MICAPIPE_FUNC_FIX_MODE prior to calling run_micapipe_module.sh
#
# Examples:
# - To stop at fix and perform IC labeling / classifier training:
# MICAPIPE_FUNC_FIX_MODE=stop_at_fix run_micapipe_module.sh ... --module FC
#
# - To perform manual denoising using labeled components:
# MICAPIPE_FUNC_FIX_MODE=manual_ic_remove \
# MICAPIPE_FUNC_IC_LABEL_FILE=/path/to/ic_lblFinalOutput.txt \
# run_micapipe_module.sh ... --module FC

micapipe_profile_func_fix_hook() {
  local mode="${MICAPIPE_FUNC_FIX_MODE:-default}"

  case "${mode}" in
    default)
      return 0
      ;;

    stop_at_fix)
      Info "Stopping before ICA-FIX for manual IC labeling / classifier training"

      [[ -d "${func_ICA}" ]] || { Error "ICA directory not found: ${func_ICA}"; return 1; }

      if [[ "${MICAPIPE_FUNC_STABLE_TMP:-0}" -eq 1 ]]; then
        Info "Stable tmp mode is enabled; ICA outputs will be reused in place: ${func_ICA}"
      else
        : "${MICAPIPE_FUNC_FIX_WORKDIR:?MICAPIPE_FUNC_FIX_WORKDIR is not set}"
        mkdir -p "${MICAPIPE_FUNC_FIX_WORKDIR}/${idBIDS}"
        cp -r "${func_ICA}" "${MICAPIPE_FUNC_FIX_WORKDIR}/${idBIDS}/ICA_MELODIC" || return 1
        Info "Saved ICA outputs to: ${MICAPIPE_FUNC_FIX_WORKDIR}/${idBIDS}/ICA_MELODIC"
      fi

      return 10
      ;;

    manual_ic_remove)
      Info "Running manual IC removal instead of built-in ICA-FIX"

      [[ -d "${func_ICA}" ]] || { Error "ICA directory not found: ${func_ICA}"; return 1; }

      if [[ -n "${MICAPIPE_PROFILE_IC_HELPERS:-}" && -f "${MICAPIPE_PROFILE_IC_HELPERS}" ]]; then
        # shellcheck disable=SC1090
        source "${MICAPIPE_PROFILE_IC_HELPERS}"
      fi

      declare -f getICs_by_id >/dev/null 2>&1 || { Error "getICs_by_id is not available"; return 1; }

      : "${MICAPIPE_FUNC_IC_LABEL_FILE:?MICAPIPE_FUNC_IC_LABEL_FILE is not set}"

      local iclbls
      iclbls="$(getICs_by_id "${MICAPIPE_FUNC_IC_LABEL_FILE}" "${idBIDS}")" || return 1

      [[ -n "${iclbls}" ]] || { Error "No IC labels found for ${idBIDS} in ${MICAPIPE_FUNC_IC_LABEL_FILE}"; return 1; }

      local mixdir="${func_ICA}/filtered_func_data.ica/melodic_mix"
      [[ -f "${mixdir}" ]] || { Error "melodic_mix not found: ${mixdir}"; return 1; }

      Do_cmd fsl_regfilt -i "${fmri_filtered}" -o "${fix_output}" -d "${mixdir}" -f "${iclbls}"
      Do_cmd 3dresample -orient LPI -prefix "${func_processed}" -inset "${fix_output}"

      export statusFIX="MANUAL"
      json_func "${func_proc_json}"

      return 11
      ;;

    *)
      Error "Unknown MICAPIPE_FUNC_FIX_MODE: ${mode}"
      return 1
      ;;
  esac
}

# -------------------------------------------------------------------------
# --- Profile control of ...
# -------------------------------------------------------------------------


