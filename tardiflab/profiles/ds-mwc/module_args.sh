#!/usr/bin/env bash

micapipe_profile_build_module_args() {
  local module="$1"

  case "${module}" in
    proc_surf)
      : "${SUBJECT_SURF_DIR:?ERROR: SUBJECT_SURF_DIR is not set}"
      printf '%s\n' "-proc_surf" "-freesurfer" "-surf_dir" "${SUBJECT_SURF_DIR}"
      ;;
    *)
      return 127
      ;;
  esac
}
