# micapipe-lab

This repository is the **central micapipe codebase for the Tardiflab**. It is intended to support multiple datasets through a shared core pipeline and dataset-specific profiles.

Long-term goals:

- maintain a single shared codebase for lab development
- reduce duplication across project-specific pipeline copies
- support dataset-specific processing needs through profiles
- stay as aligned as practical with the upstream `micapipe` repository
- facilitate eventual integration of lab-developed functionality into the public pipeline where appropriate

---

## Repository Core Method 

To acheive these goals:

- all core modifications should be **minimal and generic**,
- and most dataset-specific behavior should be **isolated outside the core**

In this model:

- the **core pipeline** contains shared logic and generic extension points
- each **profile** defines dataset-specific paths, utilities, parameters, and processing choices
- new methods that are generally useful should be added in a reusable way
- one-off dataset-specific logic should live in the relevant profile rather than in the shared core

---

## Development vs. Execution

This seection clarifies the distinction between **development and pipeline execution**.

### Development

Development includes:

- modifying code
- creating commits
- pushing changes to GitHub
- merging upstream updates
- creating or updating profiles

Development should be done by individual users using:

- their **own GitHub accounts**
- their **own SSH keys**
- personal development clones where practical

### Execution

Execution includes:

- running pipeline jobs on datasets
- pulling updates from the lab repository
- selecting a dataset profile
- generating derivatives

Execution is typically performed using a shared or local clone of `micapipe-lab`, and is generally **pull-only**.

Dataset-specific behavior should be controlled by **profiles**, not by maintaining separate copies of the pipeline per dataset.

---

## Authentication & Repository Usage

All GitHub interactions for this repository use **SSH-based authentication**.

### Authentication

- No shared lab GitHub account is used
- No shared password or shared personal access token is used
- Pushes are attributable to individual users
- Access is managed through GitHub repository permissions

### Developer requirements

Each developer who needs push access should:

1. Have a GitHub account with appropriate access to `TardifLab/micapipe-lab`
2. Have an SSH key configured on the server or development machine they use
3. Add the corresponding public key to their GitHub account
4. Confirm that SSH authentication works before pushing

### Testing SSH authentication

To test GitHub SSH authentication:

```bash
ssh -T git@github.com
```

Expected response:

```text
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

### SSH configuration notes

Some users may have multiple SSH keys on the lab server. In that case, the appropriate key should be selected via `~/.ssh/config`.

---

## Repository Remotes

This repository should be configured with two Git remotes:

- `origin` → the Tardiflab repository
- `upstream` → the official micapipe repository

Example:

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

This allows the lab to maintain its own canonical fork while continuing to synchronize with the official micapipe codebase.

---

## Running micapipe with Profiles

This lab version of micapipe is intended to support multiple datasets through **profiles**.

Each profile defines dataset-specific configuration while using a shared core pipeline.

### Basic usage

To run micapipe, specify the dataset profile using the `MICAPIPE_PROFILE` environment variable:

```bash
MICAPIPE_PROFILE=dsA ./micapipe.sh <arguments>
```

Example:

```bash
MICAPIPE_PROFILE=dsA ./micapipe.sh sub-001
```

### Profile location

Profiles are intended to live in:

```text
config/profiles/
```

Each dataset should have its own profile directory, for example:

```text
config/profiles/dsA/
config/profiles/dsB/
config/profiles/dsC/
```

### Typical profile contents

A profile may contain some or all of the following files:

- `init.sh` — environment setup, modules, conda environments, shared paths
- `utilities.sh` — dataset-specific file layout and naming logic
- `registration.sh` — dataset-specific registration functions or method definitions
- `params.sh` — dataset-specific parameters or method selections
- additional helper scripts if needed for that dataset

### Key idea

- The **core pipeline remains shared**
- Dataset-specific behavior is controlled by the **selected profile**
- New datasets should generally be added by creating a new profile, not by copying the pipeline

---

## Example Repository Structure

An example layout for `micapipe-lab` is:

```text
micapipe-lab/
├── core/
├── config/
│   └── profiles/
│       ├── dsA/
│       │   ├── init.sh
│       │   ├── utilities.sh
│       │   ├── registration.sh
│       │   └── params.sh
│       ├── dsB/
│       └── dsC/
├── lab_ext/
├── docs/
├── README.md
└── micapipe.sh
```

### Role of each area

- `core/`  
  Shared pipeline logic and generic extension points

- `config/profiles/`  
  Dataset-specific configuration and overrides

- `lab_ext/`  
  Lab-specific shared methods or experimental functionality that may not belong in the upstream core

- `docs/`  
  Internal lab documentation, migration notes, and usage examples

---

## Core vs. Profile Responsibilities

A useful rule of thumb:

### Put logic in the **core** when:

- it is shared across multiple datasets
- it represents a general pipeline feature
- it provides a reusable extension point
- it is likely to remain useful as the lab evolves
- it could plausibly be upstreamed later

Examples:

- wrapper functions for major processing steps
- generic method dispatch
- common QC utilities
- stable interfaces used by multiple profiles

### Put logic in a **profile** when:

- it is only relevant to one dataset
- it reflects acquisition-specific processing choices
- it handles dataset-specific paths or naming quirks
- it selects among existing methods
- it provides dataset-specific parameters

Examples:

- BIDS root paths
- dataset-specific module/environment loading
- registration parameter choices
- file naming overrides
- method selections for one project

### Put logic in **lab_ext/** when:

- it is useful across multiple datasets in the lab
- it is not part of upstream micapipe
- it may still be too experimental or specialized to place directly in the shared core

---

## Syncing with Upstream micapipe

This repository is a **lab-maintained fork** of the official micapipe repository.

### Check remotes

```bash
git remote -v
```

### Fetch latest upstream changes

```bash
git fetch upstream
```

### Merge upstream into the lab branch

```bash
git checkout main
git merge upstream/main
```

Alternatively, advanced users may prefer:

```bash
git rebase upstream/main
```

### Handling conflicts

If upstream changes overlap with lab modifications, Git may report merge conflicts.

In that case:

1. Open the affected files
2. Review the conflicting changes
3. Resolve the conflict manually
4. Stage the resolved files:

```bash
git add <file>
```

5. Complete the merge:

```bash
git commit
```

### Important notes when syncing

- Core pipeline modifications should be kept **minimal and generic**
- Most lab-specific behavior should live in `config/profiles/`
- When resolving conflicts:
  - preserve **lab extension points** such as wrapper functions and hooks
  - incorporate **useful upstream improvements** into the lab defaults where appropriate

### Recommended workflow

- sync with upstream **regularly**
- avoid letting the lab fork drift too far
- test on a small example dataset after syncing
- push the updated lab branch to GitHub:

```bash
git push origin main
```

---

## Creating a New Dataset Profile

When onboarding a new dataset, the default approach should be:

- **do not copy the entire pipeline**
- create a **new profile** instead

### Suggested steps

1. Create a new profile directory:

```bash
mkdir -p config/profiles/dsNew
```

2. Add the initial files you need, such as:

- `init.sh`
- `utilities.sh`
- `registration.sh`
- `params.sh`

3. Define the dataset-specific settings:

- root paths
- environment/module setup
- naming conventions
- processing choices
- method selections
- registration behavior

4. Test the dataset using the shared core and the new profile

5. Keep dataset-specific logic inside the profile unless there is a strong reason to generalize it

### Recommendation

When adding a new dataset, start by keeping things local to the profile. Move logic into the shared core only if it proves reusable across datasets.

---

## Migration Strategy

This repository is being established while several project-specific micapipe variants still exist.

The recommended migration path is:

1. preserve the existing project-specific version 
2. ensure `micapipe-lab` is stable
3. For this migration target, identify:
   - shared logic that belongs in the core
   - dataset-specific logic that belongs in a profile
   - one-off hacks that should be retired
4. create the working profile
5. compare outputs against the legacy pipeline

---

## Recommended Git Workflow for Lab Development

A practical workflow for developers is:

1. Clone `micapipe-lab`
2. Create a feature branch
3. Make changes
4. Test on a small representative case
5. Commit and push
6. Open a pull request or merge into the lab main branch according to lab practice

Example:

```bash
git checkout -b feature/profile-dsA
```

After development:

```bash
git add .
git commit -m "Add initial dsA profile structure"
git push origin feature/profile-dsA
```

Recommended practice:

- use short-lived feature branches
- keep commits focused
- avoid long-lived project-specific branches
- merge back into the shared lab branch regularly

---

## Shared Installation vs. Personal Clones

It is useful to distinguish between:

### The central lab repository

The GitHub repository `TardifLab/micapipe-lab` is the lab’s source of truth.

### Shared installation on the server

A shared checkout on the lab server may be used for running jobs, for example:

```text
/data_/tardiflab/01_programs/micapipe-lab
```

This location should generally be treated as a **stable execution copy**, not the primary place for experimental development.

### Personal development clones

Developers may also keep personal clones in their own workspace for making changes, testing, and pushing updates.

This model helps separate:

- stable execution
- active development
- repository governance

---

## Possible Future Additions

- exact profile-loading syntax
- profile templates
- coding conventions for lab extensions
- testing/checklist for syncing with upstream
- instructions for submitting generic improvements back upstream
