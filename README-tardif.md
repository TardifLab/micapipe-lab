# Central MICAPIPE codebase for Tardiflab

This repository (`micapipe-lab`) is the **canonical micapipe codebase for the Tardif Lab**. It is used across multiple datasets via dataset-specific profiles.

It remains linked to the official repo (upstream).


## 🔐 Authentication & Repository Usage (Lab Policy)


### Development vs. Execution

We follow a **clear separation between development and pipeline execution**:

- **Development (code changes, commits, pushes):**
  - Performed by individual users using their **own GitHub accounts**
  - Authenticated via **personal SSH keys**
  - Changes are made in personal clones and pushed to the lab repository

- **Execution (running pipelines on datasets):**
  - Performed using a shared or local clone of `micapipe-lab`
  - Typically **pull-only** (no pushing required)
  - Dataset-specific behavior is controlled via **profiles**, not separate codebases

---

### SSH Authentication

All GitHub interactions use **SSH-based authentication**.

- Each developer must:
  - Generate an SSH key on the server (if not already present)
  - Add the public key to their **GitHub account**
  - Have write access to the `TardifLab/micapipe-lab` repository

- The server may contain multiple SSH keys (e.g., for different services).  
  The appropriate key is selected via `~/.ssh/config`.

- To test authentication:

```bash
ssh -T git@github.com

Expected response: `Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.`
