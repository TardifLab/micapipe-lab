#!/usr/bin/env bash
#
# Dataset-level runtime settings for profile: ds-mwc (MWC dataset)
# This file is intended to be sourced after the profile has been resolved.
#
# 2026 Mark C Nelson MNI
#------------------------------------------------------------------------------------------------------------------------------------

echo "[ds-mwc dataset.sh] loaded" >&2

# Required dataset paths
export BIDS_DIR="/data_/tardiflab/mwc/bids"
export OUT_DIR="/data_/tardiflab/mwc/bids/derivatives/micapipe-lab"
export LOG_DIR="/data_/tardiflab/mwc/bids/derivatives/micapipe-lab/logs"

# Root containing externally generated FreeSurfer subject folders
export EXTERNAL_SURF_ROOT="${BIDS_DIR}/derivatives/freesurfer"

# How subject/session folders are named inside EXTERNAL_SURF_ROOT
# Allowed values in the runner below:
#   sub_ses   -> sub-01_ses-1
#   bare_ses  -> 01_ses-1
#   sub_only  -> sub-01
#   bare_only -> 01
export EXTERNAL_SURF_NAMING="sub_ses"


# Point to the optional module override file for this profile
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export MICAPIPE_PROFILE_MODULE_ARGS="${PROFILE_DIR}/module_args.sh"


# Default subjects/sessions for launcher scripts
DEFAULT_SUBJECTS=(01 02 03)
DEFAULT_SESSIONS=(1)

# Optional dataset-specific cluster defaults
# export PROFILE_DEFAULT_QUEUE="all.q"

# Optional dataset-specific memory overrides by logical module
# These are examples; uncomment and adapt if useful.
# profile_default_vmem_for_module() {
#   case "$1" in
#     volumetric)      echo 6 ;;
#     post_structural) echo 3 ;;
#     dwi)             echo 25 ;;
#     SC)              echo 50 ;;
#     FC)              echo 20 ;;
#     *)               echo 8 ;;
#   esac
# }
