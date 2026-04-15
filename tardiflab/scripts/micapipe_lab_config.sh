#!/usr/bin/env bash
# Global launcher config for micapipe-lab.
# This file contains lab-installation / launcher-wide settings only.
# 2026 Mark C Nelson MNI
# -------------------------------------------------------------------

# Root of the shared lab micapipe checkout
  export MICAPIPE_ROOT="/data_/tardiflab/01_programs/micapipe-lab"
  export MICAPIPE="/data_/tardiflab/01_programs/micapipe-lab"

# Main micapipe router binary/script
  export MICAPIPE_BIN="${MICAPIPE_ROOT}/micapipe"

# Cluster defaults
  export QBATCH_BIN="qbatch"
  export DEFAULT_QUEUE="all.q"

# Optional hook for custom lab modules.
# If set, this file will be sourced by run_micapipe_module.sh, and it should
# define a function:
#
#   micapipe_custom_module_dispatch <module> <sub> <ses> <extra args...>
#
# That function should return:
#   0   if it handled the module successfully
#   127 if the module was not recognized there
#
# export MICAPIPE_CUSTOM_MODULE_DISPATCH="${MICAPIPE_ROOT}/tardiflab/scripts/custom_modules.sh"
