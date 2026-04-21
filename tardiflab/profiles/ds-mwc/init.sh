#/bin/bash
#
# initializes dependencies & paths necessary to run micapipe & related functions
#
#
# 2021 Mark C Nelson MNI
# 2023 Mark adapted to public version of micapipe & the BIDS organized MWC data
# 2026 Mark adapted to micapipe-lab
#------------------------------------------------------------------------------------------------------------------------------------

echo "[ds-mwc init.sh] loaded" >&2

# Permissions
  umask 002

# Save OLD PATH
  export OLD_PATH=$PATH

# Declare path vars for all necessary binaries
  export root_dir=/data_/tardiflab
  export softwareDir=${root_dir}/01_programs
  export mrtrixDir=${softwareDir}/MRtrix_v3.0.4
  export AFNIDIR=${softwareDir}/afni
  export ANTSPATH=${softwareDir}/ANTs/bin
  export workbench_path=${softwareDir}/workbench
  export FIXPATH=${softwareDir}/fix								# make sure fix knows where to find mcr (see fix/settings.sh, set FSL_FIX_MCRROOT variable)
# export PYTHONPATH=${softwareDir}/anaconda3/bin
  export MATLABPATH=${softwareDir}/matlabLIBS                                                   # Originally was ${softwareDir}/matlab
  export RPATH=${softwareDir}/R 								# v3.6 is necessary for micapipe
  export R_HOME=${RPATH}
  export ICU60_DIR=${softwareDir}/icu60               						# this lib was missing from the R v3.6 package
#  export RPATH=${softwareDir}/R-3.6.3/bin 							# this no longer exists
#  export RPATH=/usr/bin/R 									# This is v4, which is not compatible with the packages necessary for micapipe
  export customBin=${softwareDir}/bin
  export ANACONDA=${softwareDir}/anaconda3
  export MCRPATH=${softwareDir}/mcr 								# Matlab runtime compiler
  export C3DPATH=${softwareDir}/c3d-1.0.0/bin

# Freesurfer & Fastsurfer
#  export FREESURFER_HOME=${softwareDir}/freesurfer_v7
#  export FASTSURFER_HOME=${softwareDir}/fastsurfer                  		# DONT HAVE THIS YET
#  export fs_licence=${softwareDir}/freesurfer_v7/license.txt
  export FREESURFER_HOME=${softwareDir}/freesurfer_v7.3.2
  export fs_licence=${FREESURFER_HOME}/license.txt
# FSL
  export FSLDIR=${softwareDir}/fsl
  export FSL_DIR=${softwareDir}/fsl
  export FSL_BIN="${FSLDIR}/bin"
# Fastsurfer singularity container
##export fastsurfer_img=${softwareDir}/fastsurfer/fastsurfer-cpu-v2.0.4.sif  	# DONT HAVE THIS YET

unset TMPDIR

#------------------------------------------------------------------------------#
# Remove any other instance from the PATH
# AFNI
PATH=$(IFS=':';p=($PATH);unset IFS;p=(${p[@]%%*afni*});IFS=':';echo "${p[*]}";unset IFS)
# ANTS
PATH=$(IFS=':';p=($PATH);unset IFS;p=(${p[@]%%*ants*});IFS=':';echo "${p[*]}";unset IFS)
# Workbench binaries
PATH=$(IFS=':';p=($PATH);unset IFS;p=(${p[@]%%*workbench*});IFS=':';echo "${p[*]}";unset IFS)
# FSL
PATH=$(IFS=':';p=($PATH);unset IFS;p=(${p[@]%%*fsl*});IFS=':';echo "${p[*]}";unset IFS)
# revome any other MRtrix3 version from path
PATH=$(IFS=':';p=($PATH);unset IFS;p=(${p[@]%%*mrtrix*});IFS=':';echo "${p[*]}";unset IFS)
# REMOVES any other python configuration from the PATH the conda from the PATH and LD_LIBRARY_PATH variable
PATH=$(IFS=':';p=($PATH);unset IFS;p=(${p[@]%%*conda*});IFS=':';echo "${p[*]}";unset IFS)
LD_LIBRARY_PATH=$(IFS=':';p=($LD_LIBRARY_PATH);unset IFS;p=(${p[@]%%*conda*});IFS=':';echo "${p[*]}";unset IFS)

#------------------------------------------------------------------------------#
# Software configuration
unset PYTHONPATH
unset PYTHONHOME

# FreeSurfer 6.0 configuration
source "${FREESURFER_HOME}/FreeSurferEnv.sh"
# FSL 6.0 configuration
source "${FSLDIR}/etc/fslconf/fsl.sh"
#------------------------------------------------------------------------------#

# Export new PATH with all the necessary binaries
  export PATH="${C3DPATH}:${MCRPATH}:${ANACONDA}:${customBin}:${MATLABPATH}:${RPATH}/bin:${AFNIDIR}:${ANTSPATH}:${workbench_path}/bin_linux64:${FREESURFER_HOME}/bin:${mrtrixDir}/bin:${mrtrixDir}/lib:${FSLDIR}/bin:${FIXPATH}:${PATH}"

# Set the libraries paths for mrtrx and fsl (This use of LD_LIBRARY_PATH may be frowned upon :/)
#  export LD_LIBRARY_PATH="${FSLDIR}/lib:${FSLDIR}/bin:${mrtrixDir}/lib:${RPATH}/lib"
  export LD_LIBRARY_PATH="${ICU60_DIR}/lib:${FSLDIR}/lib:${FSLDIR}/bin:${mrtrixDir}/lib:${RPATH}/lib:${workbench_path}/bin_linux64:${workbench_path}/libs_linux64_software_opengl"

#------------------------------------------------------------------------------#
# --- ENVIRONMENT VARIABLES ALLOWING PROFILE-OVERRIDE OF MICAPIPE BEHAVIOR ---#

# Profile control of ICA-FIX
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MICAPIPE_PROFILE_FUNC_HOOKS="${PROFILE_DIR}/func_hooks.sh"
export MICAPIPE_FUNC_FIX_MODE="${MICAPIPE_FUNC_FIX_MODE:-default}"
export MICAPIPE_FUNC_FIX_WORKDIR="${MICAPIPE_TMP_ROOT}/micapipe_proc-func"
export MICAPIPE_FUNC_IC_LABEL_FILE="${MICAPIPE_FUNC_IC_LABEL_FILE:-${MICAPIPE_FUNC_FIX_WORKDIR}/ic_lblFinalOutput.txt}"

# Profile control of func tmp dir
export MICAPIPE_FUNC_STABLE_TMP="${MICAPIPE_FUNC_STABLE_TMP:-1}" 			# switches to stable tmp directory
export MICAPIPE_FUNC_RESET_TMP="${MICAPIPE_FUNC_RESET_TMP:-0}"				# preserves existing stable dir
#------------------------------------------------------------------------------#

# Append my R library  			*** (NOT TESTED) ***
  myRLibs=${softwareDir}/Rlibs
  #[[ ! -e $myRLibs ]] && mkdir $myRLibs
  if [ -n "$R_LIBS" ]; then
      export R_LIBS=$myRLibs:$R_LIBS
  else
      export R_LIBS=$myRLibs
  fi

# Language utilities
  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8

# Use micapipe Python venv
MICAPIPE_PYENV="${softwareDir}/venvs/micapipe_py"

if [[ -d "${MICAPIPE_PYENV}" ]]; then
  export PATH="${MICAPIPE_PYENV}/bin:${PATH}"
fi

# Additional Paths
# Virtual environments
#  export pyvenv_commit=${softwareDir}/COMMIT_MTR_env 					# Location of virtual environment with dependencies for COMMIT & AMICO
#  export pyvenv_micapipe=micapipe_mwc_env                                		# micapipe python venv (conda activate $pyvenv_micapipe)

# To run on cluster
  export SGE_ROOT=/opt/sge

# To run mrview in X2go
#  export LD_PRELOAD=/opt/nvidia/nsight-systems/2021.3.2/host-linux-x64/Mesa/libGL.so && /opt/mrtrix3/bin/mrview $image
