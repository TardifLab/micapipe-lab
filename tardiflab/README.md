# micapipe-lab

`micapipe-lab` is a lab-maintained version of `micapipe` intended to support multiple Tardiflab datasets through one shared codebase and dataset-specific profiles.

The broad aims are to:

- reduce duplication across project-specific pipeline copies
- keep lab development in one maintainable place
- support dataset-specific processing choices through profiles
- stay reasonably aligned with the upstream `MICA-MNI/micapipe` repository
- make it easier to identify lab-developed functionality that could eventually be generalized or contributed upstream

This README is intended as a practical guide for people who maintain, extend, or run this lab implementation.

---

## Guiding idea

The main design idea is:

> Keep the shared pipeline as generic as possible, and place dataset-specific behavior in profiles.

In practice, this means:

- the shared pipeline should contain common logic and small, reusable extension points
- each dataset profile should define paths, environment setup, module defaults, and dataset-specific choices
- experimental or dataset-specific methods can be developed in profile hook files first
- code can move into the shared core later if it proves broadly useful

The goal is to make future development easier to understand, test, and merge.

---

## Repository layout

A typical layout is:

```text
micapipe-lab/
├── micapipe
├── functions/
├── MNI152Volumes/
├── parcellations/
├── surfaces/
├── tardiflab/
│   ├── core/
│   │   └── profile_loader.sh
│   ├── docs/
│   ├── lab_ext/
│   ├── profiles/
│   │   ├── ds-mwc/
│   │   │   ├── dataset.sh
│   │   │   ├── init.sh
│   │   │   ├── utilities.sh
│   │   │   ├── params.sh
│   │   │   ├── module_args.sh
│   │   │   ├── func_hooks.sh
│   │   │   └── dwi_hooks.sh
│   │   └── ds-other/
│   ├── scripts/
│   │   ├── run_micapipe_module.sh
│   │   └── run_micapipe_batch.sh
│   └── templates/
```

### Main areas

- `functions/`, `micapipe`, and related top-level files  
  Shared micapipe pipeline code, including small lab extension points where needed.

- `tardiflab/core/`  
  Shared lab infrastructure, such as the profile loader.

- `tardiflab/profiles/`  
  Dataset profiles. These are the preferred place for dataset-specific paths, environment setup, module defaults, and profile hooks.

- `tardiflab/scripts/`  
  Convenience launchers for running one module or submitting a module across many subjects/sessions.

- `tardiflab/lab_ext/`  
  Optional location for shared lab methods that are not part of upstream micapipe but may be useful across more than one dataset.

- `tardiflab/docs/`  
  Internal notes, migration records, examples, and troubleshooting documentation.

---

## Profiles

A profile is a dataset-specific configuration layer. It lets the same shared pipeline behave differently for different datasets without maintaining separate copies of micapipe.

Profiles usually live in:

```text
tardiflab/profiles/<profile-name>/
```

For example:

```text
tardiflab/profiles/ds-mwc/
```

### Common profile files

A profile may contain some or all of the following:

| File | Typical role |
|---|---|
| `dataset.sh` | Dataset paths, default subject/session lists, log paths, queue defaults, resource defaults |
| `init.sh` | Runtime environment setup, software paths, Python/conda/venv setup, hook registration |
| `utilities.sh` | Dataset-specific overrides for file naming, paths, or helper functions used by micapipe |
| `params.sh` | Dataset-specific parameter choices |
| `module_args.sh` | Profile-specific command-line flags for built-in modules |
| `func_hooks.sh` | Profile-specific functional-processing hooks |
| `dwi_hooks.sh` | Profile-specific diffusion-processing hooks |

Not every profile needs every file.

---

## Running one module

The single-subject launcher is:

```bash
tardiflab/scripts/run_micapipe_module.sh
```

Example:

```bash
/data_/tardiflab/01_programs/micapipe-lab/tardiflab/scripts/run_micapipe_module.sh \
  --config /data_/tardiflab/01_programs/micapipe-lab/tardiflab/scripts/micapipe_lab_config.sh \
  --profile ds-mwc \
  --sub 01 \
  --ses 1 \
  --module volumetric
```

Useful options:

```bash
--dry-run
```

prints the command without running it.

Additional arguments after `--` are passed through to micapipe:

```bash
run_micapipe_module.sh ... --module FC -- -someMicapipeFlag value
```

---

## Running a module across subjects

The batch launcher is:

```bash
tardiflab/scripts/run_micapipe_batch.sh
```

Example local run:

```bash
run_micapipe_batch.sh \
  --config micapipe_lab_config.sh \
  --profile ds-mwc \
  --module volumetric \
  --mode local \
  --subjects 01,02 \
  --sessions 1
```

Example cluster run:

```bash
run_micapipe_batch.sh \
  --config micapipe_lab_config.sh \
  --profile ds-mwc \
  --module volumetric \
  --mode cluster \
  --subjects 01,02,03 \
  --sessions 1
```

If `--subjects` or `--sessions` are omitted, the batch runner can use profile defaults from `dataset.sh`.

The user can override memory for a run:

```bash
--vmem 20
```

Profiles can also define per-module default memory values using a helper such as:

```bash
profile_default_vmem_for_module() {
  case "$1" in
    volumetric)      echo 12 ;;
    proc_surf)       echo 6 ;;
    post_structural) echo 6 ;;
    dwi)             echo 25 ;;
    FC)              echo 20 ;;
    SC)              echo 50 ;;
    *)               echo 8 ;;
  esac
}
```

A command-line `--vmem` value should take precedence over the profile default.

---

## Profile-specific module arguments

`module_args.sh` lets a profile customize the flags used for a built-in logical module.

For example, one dataset may have precomputed FreeSurfer outputs and want `proc_surf` to import them:

```bash
#!/usr/bin/env bash

micapipe_profile_build_module_args() {
  local module="$1"

  case "${module}" in
    proc_surf)
      : "${SUBJECT_SURF_DIR:?ERROR: SUBJECT_SURF_DIR is not set}"
      printf '%s\n' "-proc_surf" "-freesurfer" "-surf_dir" "${SUBJECT_SURF_DIR}"
      ;;

    FC)
      printf '%s\n' "-proc_func" "-nocleanup" "-NSR" "-dropTR" "-tmpDir" "${MICAPIPE_TMP_ROOT}"
      ;;

    dwi)
      printf '%s\n' "-dwi_upscale" "-proc_dwi"
      ;;

    *)
      return 127
      ;;
  esac
}
```

Return code `127` means: this profile does not override that module, so the runner should use the default module arguments.

This keeps profile-specific flags out of the shared launcher logic.

---

## Overriding part of a built-in module with hooks

Some dataset-specific changes are too specific to become default micapipe behavior, but still need to occur inside a built-in module. For those cases, the preferred pattern is a small **profile hook**.

A hook is a profile-defined function that the shared module calls at a specific extension point.

The shared module remains mostly unchanged. The profile decides whether to:

- do nothing and let the built-in code run
- print/debug what it would do
- handle the step itself and tell the built-in module to skip the original block

This pattern has already been implemented for functional ICA-FIX control and for DWI denoise/degibbs behavior (see code)

### Return-code convention

A useful convention is:

| Return code | Meaning |
|---|---|
| `0` | Hook did not handle the step; continue with built-in behavior |
| `11` | Hook handled the step; skip the built-in block |
| other | Error |

Other module-specific return codes can be added if needed, but keeping this small convention makes hooks easier to follow.

---

## Recipe: adding a profile hook to a built-in module

This is the general pattern.

### 1. Add environment variables in `init.sh`

Register the hook file and define profile defaults:

```bash
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export MICAPIPE_PROFILE_DWI_HOOKS="${PROFILE_DIR}/dwi_hooks.sh"

# Modes:
#   default     -> built-in behavior
#   debug       -> print diagnostics, then use built-in behavior
#   lab_degibbs -> profile-specific DWI denoise/degibbs behavior
export MICAPIPE_DWI_DENOISE_MODE="${MICAPIPE_DWI_DENOISE_MODE:-default}"

# Dry-run is opt-in
export MICAPIPE_DWI_HOOK_DRY_RUN="${MICAPIPE_DWI_HOOK_DRY_RUN:-0}"
```

### 2. Source the hook file in the built-in module

Add this near the top of the module, after the profile/environment has been initialized:

```bash
if [[ -n "${MICAPIPE_PROFILE_DWI_HOOKS:-}" && -f "${MICAPIPE_PROFILE_DWI_HOOKS}" ]]; then
  # shellcheck disable=SC1090
  source "${MICAPIPE_PROFILE_DWI_HOOKS}"
fi
```

### 3. Replace the target block with a hook call and fallback

For a DWI denoise/degibbs block:

```bash
Info "DWI MP-PCA denoising and Gibbs ringing correction"

profile_dwi_hook_rc=0

if declare -f micapipe_profile_dwi_denoise_hook >/dev/null 2>&1; then
  micapipe_profile_dwi_denoise_hook
  profile_dwi_hook_rc=$?
fi

case "${profile_dwi_hook_rc}" in
  0)
    # Built-in micapipe behavior
    dwi_dns_tmp="${tmp}/MP-PCA_dwi.mif"
    Do_cmd dwidenoise "$dwi_cat" "$dwi_dns_tmp" -nthreads "$threads"
    mrcalc "$dwi_cat" "$dwi_dns_tmp" -subtract - -nthreads "$threads" | mrmath - mean "$dwi_resPCA" -axis 3
    Do_cmd mrdegibbs "$dwi_dns_tmp" "$dwi_dns" -nthreads "$threads"
    mrcalc "$dwi_dns_tmp" "$dwi_dns" -subtract - -nthreads "$threads" | mrmath - mean "$dwi_resGibss" -axis 3
    ;;
  11)
    Info "Profile handled DWI denoise/degibbs block"
    ;;
  *)
    Error "Profile DWI denoise hook failed with code ${profile_dwi_hook_rc}"
    exit 1
    ;;
esac
```

### 4. Put profile-specific logic in the hook file

Example `dwi_hooks.sh` skeleton:

```bash
#!/usr/bin/env bash

micapipe_profile_dwi_denoise_hook() {
  local mode="${MICAPIPE_DWI_DENOISE_MODE:-default}"

  case "${mode}" in
    default)
      return 0
      ;;

    debug)
      Info "Profile DWI denoise hook active in DEBUG mode"
      Info "dwi_cat  : ${dwi_cat:-unset}"
      Info "dwi_dns  : ${dwi_dns:-unset}"
      Info "tmp      : ${tmp:-unset}"
      Info "threads  : ${threads:-unset}"
      return 0
      ;;

    lab_degibbs)
      Info "Profile DWI denoise hook active in LAB_DEGIBBS mode"

      if [[ "${MICAPIPE_DWI_HOOK_DRY_RUN:-0}" -eq 1 ]]; then
        Info "Dry-run enabled; printing intended commands only"
        Info "Would run profile-specific DWI denoise/degibbs branch"
        return 0
      fi

      # Profile-specific commands go here.
      # If this branch produces the outputs expected by the rest of the module,
      # return 11 so the built-in block is skipped.

      return 11
      ;;

    *)
      Error "Unknown MICAPIPE_DWI_DENOISE_MODE: ${mode}"
      return 1
      ;;
  esac
}
```

### 5. Test in stages

A staged test sequence is usually safest:

1. `default` mode  
   Confirm the built-in module still runs normally.

2. `debug` mode  
   Confirm the hook is sourced and can see required module variables.

3. `dry-run` mode for the custom branch  
   Confirm paths and intended commands without skipping built-in behavior.

4. real custom mode  
   Run the profile-specific commands and return `11`.

Example:

```bash
MICAPIPE_DWI_DENOISE_MODE=debug run_micapipe_module.sh ... --module dwi
```

```bash
MICAPIPE_DWI_DENOISE_MODE=lab_degibbs \
MICAPIPE_DWI_HOOK_DRY_RUN=1 \
run_micapipe_module.sh ... --module dwi
```

```bash
MICAPIPE_DWI_DENOISE_MODE=lab_degibbs \
MICAPIPE_DWI_HOOK_DRY_RUN=0 \
run_micapipe_module.sh ... --module dwi
```

---

## Environment-variable overrides

Profiles can use environment variables to control hook behavior. This is useful when the same module needs to run in different modes across different passes.

For example:

```bash
MICAPIPE_FUNC_FIX_MODE=stop_at_fix run_micapipe_module.sh ... --module FC
```

or:

```bash
MICAPIPE_DWI_DENOISE_MODE=lab_degibbs run_micapipe_module.sh ... --module dwi
```

When running through a batch/cluster launcher, environment-variable forwarding needs to be handled deliberately. One useful pattern is a repeatable batch option such as:

```bash
--env MICAPIPE_DWI_DENOISE_MODE=lab_degibbs
--env MICAPIPE_DWI_HOOK_DRY_RUN=0
```

This allows profile behavior to be controlled per run without hard-coding one mode into `init.sh`.

---

## Functional-processing hook example

The functional module can use hooks to support custom ICA-FIX workflows.

Example modes:

| Mode | Purpose |
|---|---|
| `default` | Use built-in micapipe behavior |
| `stop_at_fix` | Run preprocessing through MELODIC, then stop for manual IC labeling/classifier training |
| `manual_ic_remove` | Reuse an existing ICA workspace and apply manually selected IC removal |

A profile can register:

```bash
export MICAPIPE_PROFILE_FUNC_HOOKS="${PROFILE_DIR}/func_hooks.sh"
export MICAPIPE_FUNC_FIX_MODE="${MICAPIPE_FUNC_FIX_MODE:-default}"
export MICAPIPE_FUNC_STABLE_TMP="${MICAPIPE_FUNC_STABLE_TMP:-1}"
export MICAPIPE_FUNC_RESET_TMP="${MICAPIPE_FUNC_RESET_TMP:-0}"
```

The functional hook can then decide whether to:

- continue with built-in FIX behavior
- stop before FIX
- complete manual IC removal and skip the built-in FIX block

For workflows that stop and resume around ICA-FIX, a stable functional temporary directory can help preserve MELODIC outputs across runs.

---

## DWI hook example

The DWI module can use a hook around MP-PCA denoising and Gibbs correction.

Example modes:

| Mode | Purpose |
|---|---|
| `default` | Use built-in micapipe behavior |
| `debug` | Print relevant variables, then run built-in behavior |
| `lab_degibbs` | Use a profile-specific denoise/degibbs branch |

Example profile variables:

```bash
export MICAPIPE_PROFILE_DWI_HOOKS="${PROFILE_DIR}/dwi_hooks.sh"
export MICAPIPE_DWI_DENOISE_MODE="${MICAPIPE_DWI_DENOISE_MODE:-default}"
export MICAPIPE_DWI_HOOK_DRY_RUN="${MICAPIPE_DWI_HOOK_DRY_RUN:-0}"
export MICAPIPE_DWI_RPG_DEGIBBS_DIR="${MICAPIPE}/tardiflab/scripts/01_processing/rpg_degibbs"
export MICAPIPE_DWI_PARTIAL_FOURIER_FACTOR="${MICAPIPE_DWI_PARTIAL_FOURIER_FACTOR:-6/8}"
```

The DWI hook can inspect:

```bash
mrinfo "$dwi_cat" -property PartialFourier
```

and choose between a standard `mrdegibbs` branch and a profile-specific branch.

---

## Creating a new dataset profile

A useful starting point is:

```bash
mkdir -p tardiflab/profiles/ds-new
touch tardiflab/profiles/ds-new/dataset.sh
touch tardiflab/profiles/ds-new/init.sh
touch tardiflab/profiles/ds-new/module_args.sh
touch tardiflab/profiles/ds-new/params.sh
touch tardiflab/profiles/ds-new/utilities.sh
```

Start with the minimum needed files. Additional hook files can be added later.

A minimal `dataset.sh` might define:

```bash
export BIDS_DIR="/path/to/bids"
export OUT_DIR="/path/to/bids/derivatives/micapipe-lab"
export LOG_DIR="${OUT_DIR}/logs"

DEFAULT_SUBJECTS=(01 02 03)
DEFAULT_SESSIONS=(1)
```

A minimal `init.sh` might define software paths, virtual environments, and hook registrations.

A minimal `module_args.sh` can return `127` for modules it does not override.

---

## Development and execution

It is useful to distinguish between development and execution.

### Development

Development may include:

- modifying code
- creating or updating profiles
- adding hook points
- testing new profile behavior
- committing changes
- syncing with upstream micapipe

Development is usually clearer when done in personal or feature-specific clones/branches where possible.

### Execution

Execution includes:

- running pipeline modules
- submitting jobs
- generating derivatives
- pulling tested updates from the lab repository

A shared checkout on the server can be useful as a stable execution copy.

---

## GitHub authentication

GitHub interactions for this repository use SSH-based authentication.

Each person who pushes changes should use their own GitHub account and SSH key, so commits remain attributable.

Test SSH authentication with:

```bash
ssh -T git@github.com
```

Expected response:

```text
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

If multiple SSH keys are present on the same server, `~/.ssh/config` can be used to select the appropriate key.

---

## Repository remotes

A useful remote setup is:

- `origin` → the Tardiflab repository
- `upstream` → the official micapipe repository

Check with:

```bash
git remote -v
```

Expected pattern:

```text
origin   git@github.com:TardifLab/micapipe-lab.git (fetch)
origin   git@github.com:TardifLab/micapipe-lab.git (push)
upstream git@github.com:MICA-MNI/micapipe.git (fetch)
upstream git@github.com:MICA-MNI/micapipe.git (push)
```

This lets the lab maintain its own fork while still syncing useful upstream changes.

---

## Syncing with upstream micapipe

To fetch upstream changes:

```bash
git fetch upstream
```

To merge upstream into the lab branch:

```bash
git checkout main
git merge upstream/main
```

Some users may prefer a rebase workflow:

```bash
git rebase upstream/main
```

If conflicts occur:

1. open the affected files
2. compare the upstream and lab changes
3. preserve any needed lab extension points or profile hooks
4. stage resolved files

```bash
git add <file>
```

5. complete the merge or rebase

```bash
git commit
```

or, during a rebase:

```bash
git rebase --continue
```

After syncing, test a small representative case before running a full dataset.

---

## Git workflow

A practical development workflow is:

```bash
git checkout -b feature/short-description
```

Make and test changes, then:

```bash
git status
git diff
git add <files>
git commit -m "Short description of change"
git push origin feature/short-description
```

Focused commits are easier to review and easier to undo later.

Useful review commands:

```bash
git status
git diff --stat
git diff path/to/file
git diff --cached
```

Interactive staging can help separate unrelated edits:

```bash
git add -p
```

---

## Migration notes

This repository was established while some project-specific micapipe variants already existed.

A practical migration strategy is:

1. preserve the previous project-specific version for reference
2. create a profile in `micapipe-lab`
3. move dataset-specific paths and choices into the profile
4. add small generic hook points only where needed
5. compare outputs against the legacy pipeline
6. document known differences

This keeps the legacy workflow available while making the new shared version easier to maintain.

---

## Possible future additions

Helpful future documentation could include:

- profile templates
- module-specific hook examples
- cluster submission examples
- expected software environments
- testing checklists for each module
- notes on when a profile hook should become a shared core feature
