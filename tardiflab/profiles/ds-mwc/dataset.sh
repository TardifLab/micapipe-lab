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
