
#!/usr/bin/env bash
#
# Allows profile to control ICA-FIX behavior in built-in func proc module
#
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
#
# 2026 Mark C Nelson MNI
#------------------------------------------------------------------------------------------------------------------------------------

echo "[ds-mwc func_hooks.sh] loaded" >&2

micapipe_profile_func_fix_hook() {
  local mode="${MICAPIPE_FUNC_FIX_MODE:-default}"

  case "${mode}" in
    default)
      return 0
      ;;

    stop_at_fix)
      Info "Stopping before ICA-FIX for manual IC labeling / classifier training"

      # Persist ICA outputs before exit, since func_ICA lives in tmp
      mkdir -p "${MICAPIPE_FUNC_FIX_WORKDIR}/${idBIDS}"
      cp -r "${func_ICA}" "${MICAPIPE_FUNC_FIX_WORKDIR}/${idBIDS}/ICA_MELODIC"

      Info "Saved ICA outputs to: ${MICAPIPE_FUNC_FIX_WORKDIR}/${idBIDS}/ICA_MELODIC"
      return 10
      ;;

    manual_ic_remove)
      Info "Running manual IC removal instead of built-in ICA-FIX"

      # optional helper source
      if [[ -n "${MICAPIPE_PROFILE_IC_HELPERS:-}" && -f "${MICAPIPE_PROFILE_IC_HELPERS}" ]]; then
        # shellcheck disable=SC1090
        source "${MICAPIPE_PROFILE_IC_HELPERS}"
      fi

      : "${MICAPIPE_FUNC_IC_LABEL_FILE:?MICAPIPE_FUNC_IC_LABEL_FILE is not set}"

      local iclbls
      iclbls="$(getICs_by_id "${MICAPIPE_FUNC_IC_LABEL_FILE}" "${idBIDS}")" || return 1

      local mixdir="${func_ICA}/filtered_func_data.ica/melodic_mix"

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

