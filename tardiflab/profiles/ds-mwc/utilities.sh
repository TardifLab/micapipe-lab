#!/bin/bash
#
# MICA BIDS structural processing
#
# Utilities

echo "[ds-mwc utilities.sh] loaded" >&2

bids_variables() {
  # This functions assignes variables names acording to:
  #     BIDS directory = $1
  #     participant ID = $2
  #     Out directory  = $3
  #     session        = $4
  BIDS=$1
  id=$2
  out=$3
  SES=$4
  umask 001

  #   Define UTILITIES directories
  export scriptDir=${MICAPIPE}/functions
  # Directory with the templates for the processing
  export util_MNIvolumes=${MICAPIPE}/MNI152Volumes
  # Directory with all the parcellations
  export util_parcelations=${MICAPIPE}/parcellations
  export util_lut=${MICAPIPE}/parcellations/lut
  # Directory with the resampled freesurfer surfaces
  export util_surface=${MICAPIPE}/surfaces 					# utilities/resample_fsaverage
  export util_mics=${MICAPIPE}/MICs60_T1-atlas

  export subject=sub-${id}

#  export bids_derivs="$(dirname ${BIDS})/derivatives"                      	# Input Derivatives directory
  export bids_derivs="${BIDS}/derivatives"                           		# Input Derivatives directory
  export derivs_siemens=${bids_derivs}/siemens

  # Handle Single Session
  if [ "$SES" == "SINGLE" ]; then
      export subject_dir=$out/${subject}     					# Output directory
      export subject_bids=${BIDS}/${subject} 					# Input BIDS directory
      export subject_siemens=${derivs_siemens}/${subject}
      ses=""
  else
      export subject_dir=$out/${subject}/${SES}     				# Output directory
      export subject_bids=${BIDS}/${subject}/${SES} 				# Input BIDS directory
      export subject_siemens=${derivs_siemens}/${subject}/${SES}
      ses="_${SES}"
  fi
export idBIDS="${subject}${ses}"

  # Structural directories derivatives/
#  export dir_surf=${out/\/micapipe/}/freesurfer    				# surfaces
  export dir_surf=${bids_derivs}/freesurfer                                     # surfaces
  export dir_freesurfer=${dir_surf}/${idBIDS}  					# freesurfer dir
  export proc_struct=$subject_dir/anat 						# structural processing directory
  export dir_first=$proc_struct/first      					# FSL first
  export dir_volum=$proc_struct/volumetric 					# Cortical segmentations
  export dir_conte69=${proc_struct}/surfaces/conte69   				# conte69

  export proc_dwi=$subject_dir/dwi               				# DWI processing directory
  export dwi_cnntm=$proc_dwi/connectomes
  export autoTract_dir=$proc_dwi/auto_tract

  export proc_func=$subject_dir/func
  export func_ICA=$proc_func/ICA_MELODIC
  export func_volum=$proc_func/volumetric
  export func_surf=$proc_func/surfaces

  export dir_warp=$subject_dir/xfm              				# Transformation matrices
  export dir_logs=$subject_dir/logs              				# directory with log files
  export dir_QC=$subject_dir/QC                  				# directory with QC files
  export dir_QC_png=$subject_dir/QC/png                 			# directory with QC files

  # post structural Files (the resolution might vary depending on the dataset)
  if [ -f ${proc_struct}/${idBIDS}_space-nativepro_t1w.nii.gz ]; then
      export res=$(mrinfo "${proc_struct}"/"${idBIDS}"_space-nativepro_t1w.nii.gz -spacing | awk '{printf "%.1f\n", $2}')
      export T1nativepro=${proc_struct}/${idBIDS}_space-nativepro_t1w.nii.gz
      export T1nativepro_brain=${proc_struct}/${idBIDS}_space-nativepro_t1w_brain.nii.gz
      export T1nativepro_mask=${proc_struct}/${idBIDS}_space-nativepro_t1w_brain_mask.nii.gz
      export T1freesurfr=${dir_freesurfer}/mri/brain.mgz
      export T15ttgen=${proc_struct}/${idBIDS}_space-nativepro_t1w_5TT.nii.gz
      export T1fast_seg=$proc_struct/first/${idBIDS}_space-nativepro_t1w_all_fast_firstseg.nii.gz

  fi

  # Native midsurface in gifti format
  export lh_midsurf=${dir_freesurfer}/surf/lh.midthickness.surf.gii
  export rh_midsurf=${dir_freesurfer}/surf/rh.midthickness.surf.gii

  # Registration from MNI152 to Native pro
  export T1str_nat=${idBIDS}_space-nativepro_t1w
  export mat_MNI152_SyN=${dir_warp}/${idBIDS}_from-nativepro_brain_to-MNI152_1mm_mode-image_desc-SyN_    	# transformation strings nativepro to MNI152_1mm
  export T1_MNI152_InvWarp=${mat_MNI152_SyN}1InverseWarp.nii.gz                      				# Inversewarp - nativepro to MNI152_1mm
  export T1_MNI152_affine=${mat_MNI152_SyN}0GenericAffine.mat
  export MNI152_mask=${util_MNIvolumes}/MNI152_T1_1mm_brain_mask.nii.gz

  # BIDS Files: resting state
  bids_mainScan=($(ls "${subject_bids}/func/${subject}${ses}"_task-rest_dir-AP_*bold.nii* 2>/dev/null))       	# main func scan
  bids_mainScanJson=($(ls "${subject_bids}/func/${subject}${ses}"_task-rest_dir-AP_*bold.json 2>/dev/null))   	# main func scan json
  bids_mainPhase=($(ls "${subject_bids}/fmap/${subject}${ses}"_task-rest_dir-AP_*epi.nii* 2>/dev/null))     	# main phase scan
  bids_reversePhase=($(ls "${subject_bids}/fmap/${subject}${ses}"_task-rest_dir-PA_*epi.nii* 2>/dev/null))  	# reverse phase scan

  # Resting state proc files
  export topupConfigFile=${FSLDIR}/etc/flirtsch/b02b0_1.cnf                                   	 		# TOPUP config file default
  export icafixTraining=${MICAPIPE}/functions/MICAMTL_training_15HC_15PX.RData                 			# ICA-FIX training file default

  # BIDS Files
  bids_T1ws=($(ls "$subject_bids"/anat/*T1w.nii* 2>/dev/null))
  bids_T2ws=($(ls "$subject_bids"/anat/*T2w.nii* 2>/dev/null))
  bids_dwis=($(ls "${subject_bids}/dwi/${subject}${ses}"*dwi.nii* 2>/dev/null))
#  bids_T1map=$(ls "$subject_bids"/anat/*MP2RAGE*.nii* 2>/dev/null)
  bids_T1map=$(ls "$subject_siemens"/anat/*T1map.nii* 2>/dev/null)
  bids_inv1=$(ls "$subject_bids"/anat/*inv-1*MP2RAGE.nii* 2>/dev/null)
  bids_inv2=$(ls "$subject_bids"/anat/*inv-2*MP2RAGE.nii* 2>/dev/null)
  bids_unit1=$(ls "$subject_bids"/anat/*acq-original_UNIT1.nii* 2>/dev/null)
  bids_unit1ds=$(ls "$subject_siemens"/anat/*acq-denoised_UNIT1.nii* 2>/dev/null)

  bids_flair=$(ls "$subject_bids"/anat/*FLAIR*.nii* 2>/dev/null)
  dwi_reverse=($(ls "${subject_bids}/fmap/${subject}${ses}"_{dir-PA_*,acq-dwi}*epi.nii* 2>/dev/null))
#  dwi_reverse=($(ls "${subject_bids}/fmap/${subject}${ses}"_dir-PA_*epi.nii* 2>/dev/null))
}

bids_print.variables() {
  # This functions prints BIDS variables names
  # IF they exist
  Info "mica-pipe inputs:"
  Note "id   =" "$id"
  Note "BIDS =" "$BIDS"
  Note "out  =" "$out"
  Note "ses  =" "$SES"

  Info "BIDS naming:"
  Note "subject_bids =" "$subject_bids"
  Note "bids_T1ws    =" "N-${#bids_T1ws[@]}, e.g. ${bids_T1ws[0]}"
  Note "bids_dwis    =" "N-${#bids_dwis[@]}, e.g. ${bids_dwis[0]}"
  Note "subject      =" "$subject"
  Note "subject_dir  =" "$subject_dir"
  Note "proc_struct  =" "$proc_struct"
  Note "dir_warp     =" "$dir_warp"
  Note "logs         =" "$dir_logs"

  Info "Processing directories:"
  Note "subject_dir     =" "$subject_dir"
  Note "proc_struct     =" "$proc_struct"
  Note "dir_conte69     =" "$dir_conte69"
  Note "dir_volum       =" "$dir_volum"
  Note "dir_warp        =" "$dir_warp"
  Note "dir_logs        =" "$dir_logs"
  Note "dir_QC          =" "$dir_QC"
  Note "dir_freesurfer  =" "$dir_freesurfer"

  Info "Utilities directories:"
  Note "scriptDir         =" "$scriptDir"
  Note "util_MNIvolumes   =" "$util_MNIvolumes"
  Note "util_lut          =" "$util_lut"
  Note "util_parcelations =" "$util_parcelations"
  Note "util_surface      =" "$util_surface"
  Note "util_mics         =" "$util_mics"
}

file.exist(){
  if [[ ! -z "${2}" ]] && [[ -f "${2}" ]]; then
    Note "$1" $(find "${2}" 2>/dev/null)
  else
    Note "$1" "file not found"
  fi
}

bids_print.variables-post() {
  # This functions prints BIDS variables names and files if found
  Info "Structural processing output variables"
  Note "T1 nativepro    :" "$(find "$T1nativepro" 2>/dev/null)"
  Note "T1 5tt          :" "$(find "$T15ttgen" 2>/dev/null)"
  Note "T1 fast_all     :" "$(find "$T1fast_seg" 2>/dev/null)"
  Note "T1 resolution   :" "$res"
}

bids_print.variables-dwi() {
  # This functions prints BIDS variables names and files if found
  Info "Variables for DWI processing"
  Note "proc_dwi dir    :" "$proc_dwi"
  Note "bids_dwis       :" "N-${#bids_dwis[@]}, $bids_dwis"
  Note "dwi_reverse     :" "N-${#dwi_reverse[@]}, $dwi_reverse"

  Note "T1 nativepro    :" "$(find "$T1nativepro" 2>/dev/null)"
  Note "T1 5tt          :" "$(find "$T15ttgen" 2>/dev/null)"
  Note "MNI152_mask     :" "$MNI152_mask"
}

bids_print.variables-func() {
  # This functions prints BIDS variables names and files if found
  Info "Variables for functional processing"
  Note "T1 nativepro       :" "$(find "$T1nativepro" 2>/dev/null)"
  Note "T1 freesurfer      :" "$(find "$T1freesurfr" 2>/dev/null)"
  for i in "${!mainScan[@]}"; do
  file.exist "mainScan${i/0/}         :" "${mainScan[i]}"
  file.exist "mainScan${i/0/} json    :" "${mainScanJson[i]}"
  done
  file.exist "Main phase scan    :" "$mainPhaseScan"
  file.exist "Main reverse phase :" "$reversePhaseScan"
  Note "TOPUP config file  :" $(find "$topupConfigFile" 2>/dev/null)
  Note "ICA-FIX training   :" $(find "$icafixTraining" 2>/dev/null)
}

bids_variables_unset() {
  # This function unsets all the enviromentalk variables defined by
  # bids_variables
  unset scriptDir
  unset util_MNIvolumes
  unset util_parcelations
  unset util_lut
  unset util_surface
  unset util_mics
  unset subject
  unset subject_dir
  unset subject_bids
  unset proc_struct
  unset dir_first
  unset dir_volum
  unset dir_surf
  unset dir_freesurfer
  unset dir_conte69
  unset proc_dwi
  unset dwi_cnntm
  unset proc_func
  unset func_ICA
  unset func_volum
  unset func_surf
  unset dir_warp
  unset dir_logs
  unset dir_QC
  unset dir_QC_png
  unset T1nativepro
  unset T1nativepro_brain
  unset T1freesurfr
  unset T15ttgen
  unset T1fast_seg
  unset res
  unset lh_midsurf
  unset rh_midsurf
  unset T1str_nat
  unset mat_MNI152_SyN
  unset T1_MNI152_InvWarp
  unset T1_MNI152_affine
  unset MNI152_mask
  unset bids_mainScan
  unset bids_mainScanJson
  unset bids_mainPhase
  unset bids_reversePhase
  unset topupConfigFile
  unset icafixTraining
  unset bids_T1ws
  unset bids_dwis
  unset bids_T1map
  unset bids_inv1
  unset dwi_reverse
}

micapipe_software() {
  Info "MICA pipe - Software versions"
  Note "MRtrix3....." "$(mrinfo -version | awk 'NR==1 {print $3}')"
  Note "            " "$(which mrinfo)"
  Note "FSL........." "$(flirt -version | awk '{print $3}')"
  Note "            " "$FSLDIR"
  Note "ANFI........" "$(afni -version | awk -F ':' '{print $2}')"
  Note "            " "$(which 3dresample)"
  Note "ANTS........" "$(antsRegistration --version | awk -F ':' 'NR==1{print $2}')"
  Note "            " "$ANTSPATH"
  Note "WorkBench..." "$(wb_command -version | awk 'NR==3{print $2}')"
  Note "            " "$(which wb_command)"
  Note "FreeSurfer.." "$(recon-all -version)"
  Note "            " "$FREESURFER_HOME"
  Note "fix........." "$(which fix)"
  Note "            " "$FIXPATH"
  Note "python......" "$(python --version)"
  Note "            " "$(which python)"
  Note "R..........." "$(R --version | awk 'NR==1{print $3}')"
  Note "            " "$(which R)"
}

