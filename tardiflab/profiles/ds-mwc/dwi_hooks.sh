#!/usr/bin/env bash
#
# These helpers allow for profile override of the built-in micapipe DWI proc module
#
# 2026 Mark C Nelson MNI
#------------------------------------------------------------------------------------------------------------------------------------

echo "[ds-mwc dwi_hooks.sh] loaded" >&2

# -------------------------------------------------------------------------
# --- DEGIBBS
# -------------------------------------------------------------------------
# The user should set the value of MICAPIPE_DWI_DENOISE_MODE prior to calling run_micapipe_module.sh
#
# Examples: (see micapipe-lab/tardiflab/docs/example-calls.txt for more info)
# MICAPIPE_DWI_DENOISE_MODE=default run_micapipe_module.sh ... --module dwi
# MICAPIPE_DWI_DENOISE_MODE=lab_degibbs run_micapipe_module.sh ... --module dwi
#

micapipe_profile_dwi_denoise_hook() {
  local mode="${MICAPIPE_DWI_DENOISE_MODE:-default}"

  case "${mode}" in
    default)
      return 0
      ;;

    debug)
      Info "Profile DWI denoise hook is active in DEBUG mode"
      Info "MICAPIPE_DWI_DENOISE_MODE      : ${MICAPIPE_DWI_DENOISE_MODE:-unset}"
      Info "MICAPIPE_DWI_HOOK_DRY_RUN      : ${MICAPIPE_DWI_HOOK_DRY_RUN:-unset}"
      Info "MICAPIPE_DWI_RPG_DEGIBBS_DIR   : ${MICAPIPE_DWI_RPG_DEGIBBS_DIR:-unset}"
      Info "MICAPIPE_DWI_PARTIAL_FOURIER_FACTOR : ${MICAPIPE_DWI_PARTIAL_FOURIER_FACTOR:-unset}"

      Info "dwi_cat       : ${dwi_cat:-unset}"
      Info "dwi_dns       : ${dwi_dns:-unset}"
      Info "dwi_resPCA    : ${dwi_resPCA:-unset}"
      Info "dwi_resGibss  : ${dwi_resGibss:-unset}"
      Info "proc_dwi      : ${proc_dwi:-unset}"
      Info "tmp           : ${tmp:-unset}"
      Info "idBIDS        : ${idBIDS:-unset}"
      Info "threads       : ${threads:-unset}"

      if [[ -n "${dwi_cat:-}" && -f "${dwi_cat}" ]]; then
        local partial_fourier
        partial_fourier="$(mrinfo "${dwi_cat}" -property PartialFourier 2>/dev/null || true)"
        Info "Detected PartialFourier from mrinfo: ${partial_fourier:-unset}"

        if [[ "${partial_fourier}" == "1" ]]; then
          Info "DEBUG: would use standard mrdegibbs branch"
        else
          Info "DEBUG: would use custom RPG degibbs branch"
        fi
      else
        Info "DEBUG: dwi_cat is unset or not found; cannot inspect PartialFourier"
      fi

      Info "DEBUG mode returns 0, so built-in micapipe DWI denoise/degibbs behavior will run"
      return 0
      ;;

    lab_degibbs)
      Info "Profile DWI denoise hook is active in LAB_DEGIBBS mode"

      if [[ "${MICAPIPE_DWI_HOOK_DRY_RUN:-0}" -eq 1 ]]; then
        Info "DWI hook dry-run is enabled; printing intended commands only"

        Info "Would run: dwidenoise ${dwi_cat} ${tmp}/MP-PCA_dwi.mif -nthreads ${threads} -noise ${proc_dwi}/${idBIDS}_space-dwi_sigma.nii.gz"
        Info "Would compute denoising residual"
        Info "Would inspect PartialFourier using mrinfo"
        Info "Would choose standard mrdegibbs if PartialFourier == 1"
        Info "Would choose RPG degibbs if PartialFourier != 1"
        Info "Dry-run returns 0 so built-in micapipe behavior will still run"

	if [[ -n "${dwi_cat:-}" && -f "${dwi_cat}" ]]; then
  	  PartialFourier="$(mrinfo "${dwi_cat}" -property PartialFourier 2>/dev/null || true)"
  	  Info "Would use PartialFourier value: ${PartialFourier:-unset}"
	fi

        return 0
      fi

      # Custom degibbs code here (may still need to be debugged!)

       dwi_dns="${tmp}/MP-PCA_degibbs.mif"
       dwi_dns_tmp="${tmp}/MP-PCA_dwi.mif"

       Do_cmd dwidenoise "$dwi_cat" "$dwi_dns_tmp" \
         -nthreads "$threads" \
         -noise "${proc_dwi}/${idBIDS}_space-dwi_sigma.nii.gz"

       mrcalc "$dwi_cat" "$dwi_dns_tmp" -subtract - -nthreads "$threads" | \
         mrmath - mean "$dwi_resPCA" -axis 3

       PartialFourier="$(mrinfo "$dwi_cat" -property PartialFourier)"

       if [[ "$PartialFourier" == "1" ]]; then            				# -> full Fourier acquisition; use standard mrdegibbs
         Do_cmd mrdegibbs "$dwi_dns_tmp" "$dwi_dns" -nthreads "$threads"
       else 										# -> partial Fourier acquisition; use custom RPG degibbs branch
         Do_cmd mrconvert "$dwi_dns_tmp" \
           -export_grad_fsl "${tmp}/dwi.bvec" "${tmp}/dwi.bval" \
           -json_export "${tmp}/dwi.json" \
           "${tmp}/dwi_dns.nii.gz"

        # Do_cmd matlab -nodisplay -r "cd('${proc_dwi}'); addpath(genpath('${MICAPIPE_DWI_RPG_DEGIBBS_DIR}')); degibbs = rpg_degibbs(niftiread('${tmp}/dwi_dns.nii.gz'), 2, ${MICAPIPE_DWI_PARTIAL_FOURIER_FACTOR}); info = niftiinfo('${tmp}/dwi_dns.nii.gz'); niftiwrite(degibbs, '${tmp}/dwi_dns_dgs.nii', info); exit"
	# A safer call to your Matlab script
 	  Do_cmd matlab -nodisplay -nosplash -r "try; cd('${proc_dwi}'); addpath(genpath('${MICAPIPE_DWI_RPG_DEGIBBS_DIR}')); degibbs = rpg_degibbs(niftiread('${tmp}/dwi_dns.nii.gz'), 2, ${MICAPIPE_DWI_PARTIAL_FOURIER_FACTOR}); info = niftiinfo('${tmp}/dwi_dns.nii.gz'); niftiwrite(degibbs, '${tmp}/dwi_dns_dgs.nii', info); catch ME; disp(getReport(ME)); exit(1); end; exit(0);"

         Do_cmd mrconvert "${tmp}/dwi_dns_dgs.nii" \
           -fslgrad "${tmp}/dwi.bvec" "${tmp}/dwi.bval" \
           -json_import "${tmp}/dwi.json" \
           "$dwi_dns"
       fi

       mrcalc "$dwi_dns_tmp" "$dwi_dns" -subtract - -nthreads "$threads" | \
         mrmath - mean "$dwi_resGibss" -axis 3

       return 11
      ;;

    *)
      Error "Unknown MICAPIPE_DWI_DENOISE_MODE: ${mode}"
      return 1
      ;;
  esac
}
