# Project Context — ansible-role-gitlab-runner

This file is the authoritative project brief for Claude. Load it as project
knowledge when starting a new conversation (claude.ai → Projects → New
Project → Add Knowledge).

---

## What This Project Is

An Ansible role that installs, registers, and configures
[GitLab Runner](https://docs.gitlab.com/runner/) across Linux (Debian,
Ubuntu, RedHat, Arch), macOS, Windows, and Docker containers.

This is a fork of [riemers/ansible-gitlab-runner][upstream] maintained by
**Bob Tanner** <tanner@real-time.com> at Real Time Enterprises, Inc. The
upstream project is no longer actively maintained. This fork will not send
PRs upstream.

The primary near-term goal is to make the role work correctly on
**Ubuntu Resolute (26.04 LTS)**, which currently fails at install time
because `install-debian.yml` fetches a setup script from
`packages.gitlab.com` that does not yet handle Resolute's release codename.

---

## Source of Truth

This `CLAUDE.md` is the authoritative spec for the role. Read it before
making any non-trivial change. Variable names, task file layout, config
update modes, handler names, and commit conventions all live here.

If something in the code disagrees with this file, this file is right
unless explicitly told otherwise — flag the discrepancy and ask before
"fixing" the design to match the code.

---

## Scope Constraints

These boundaries are hard. Flag any request that crosses them before
proceeding.

* **Multi-platform by design.** This role supports Debian/Ubuntu, RedHat,
  Arch, macOS, Windows, and Docker containers. Do not narrow it to a single
  platform without an explicit decision from the human.

* **Ubuntu Resolute is a first-class target.** The role must install and
  configure GitLab Runner on Ubuntu 26.04 LTS. If a change breaks Resolute
  support, it must be blocked or explicitly accepted.

* **Supported Ubuntu releases:** jammy (22.04 LTS), noble (24.04 LTS),
  questing (25.10 interim), resolute (26.04 LTS). See `meta/main.yml`.

* **Supported Debian releases:** bullseye (11 LTS), bookworm (12
  oldstable), trixie (13 current stable). See `meta/main.yml`.

* **Collections in use.** `ansible.builtin` for all core tasks.
  `community.docker` for the container install path. `ansible.windows` for
  the Windows path. `community.crypto` for TLS certificate handling.
  Do not add new collection dependencies without discussion.

* **`defaults/main.yml` is the public interface.** Every variable lives
  there so consumers can override it. There is no `vars/main.yml`. Do not
  introduce one.

* **No `no_log` removal.** Registration tasks handle tokens and secrets.
  `no_log: "{{ gitlab_runner_no_log_secrets | default(true) }}"` must stay
  on every task that passes secrets to the `gitlab-runner register` command.

---

## Behavioral Guidelines

Adapted from the [Karpathy CLAUDE.md][karpathy-claude] guidelines and the
"4 Lines Every CLAUDE.md Needs" framework. These bias toward caution over
speed. Use judgment on trivial tasks.

### 1. Think Before Changing

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing any task:

* State assumptions about target system state explicitly. If uncertain, ask.
* If multiple interpretations exist, present them — don't pick silently.
  Example: "This could fix Resolute support by patching the script URL, or
  by adding a fallback apt repo task — which approach do you want?"
* If a simpler approach exists, say so. Push back when warranted.
* If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum change that solves the problem. Nothing speculative.**

* No new variables in `defaults/main.yml` beyond what the task requires.
  Every new variable is a public interface change for consumers.
* No new Jinja2 abstractions for single-use template blocks.
* No "flexibility" or "future-proofing" that wasn't requested.
* No error handling for scenarios the role cannot realistically encounter.
* If you write 50 lines of tasks and it could be 20, rewrite it.

Ask yourself: "Would a senior Ansible engineer say this is overcomplicated?"
If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing tasks, templates, handlers, or defaults:

* Don't "improve" adjacent tasks, comments, or formatting.
* Don't refactor things that aren't broken.
* Match existing YAML style, even if you'd do it differently.
* If you notice an unrelated issue (unused variable, stale comment, wrong
  mode), mention it — don't silently fix it.

When your changes create orphans:

* Remove variables, handler notify strings, or task references that YOUR
  changes made unused.
* Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals before starting:

* "Fix Resolute install" → "molecule converge passes with
  `geerlingguy/docker-ubuntu2604-ansible`; second run reports zero changes"
* "Fix handler wiring" → "handler name matches every `notify:` string
  that references it; ansible-lint passes"
* "Update defaults" → "ansible-lint passes; no consumer variable renamed
  or removed without a BREAKING CHANGE footer in the commit"

For multi-step tasks, state a brief plan before touching any file:

```
1. [step] → verify: [check]
2. [step] → verify: [check]
3. [step] → verify: [check]
```

Strong success criteria allow independent looping. Weak criteria
("make it work") require constant clarification.

---

## Technology Stack

| Layer            | Choice                     | Notes                                      |
|------------------|----------------------------|--------------------------------------------|
| Package source   | packages.gitlab.com        | Script-based apt/yum repo setup            |
| Service manager  | systemd (Linux)            | `ansible.builtin.service` / `systemd`      |
| Config format    | TOML via `config.toml`     | Assembled from section fragments           |
| Config update    | Three modes                | See "Config Update Modes" below            |
| Collections      | builtin + docker + windows | See requirements.yml                       |
| Ansible minimum  | 2.20                       | Matches `meta/main.yml`                    |
| Galaxy namespace | `realtime`                 | Real Time Enterprises, Inc.                |

---

## Config Update Modes

The variable `gitlab_runner_config_update_mode` controls how the role
applies config changes. This is load-bearing — don't change the default
(`by_config_toml`) without understanding the downstream effect.

* **`by_config_toml`** (default) — slurps the existing `config.toml`,
  splits on `[[runners]]` boundaries, rewrites each section via
  `config-runner.yml`, and reassembles with `ansible.builtin.assemble`.
  Preserves fields the role does not manage.

* **`by_registering`** — compares a hashed representation of the
  registration command to detect config drift; unregisters and re-registers
  the runner when drift is detected. Expensive — touches the GitLab API.

* **`by_template`** — writes the entire `config.toml` from
  `templates/config.toml.j2`. Fast and complete, but reads only `id`,
  `token_obtained_at`, and `token_expires_at` from the existing file.
  All other content is replaced.

---

## Role File Structure

```
ansible-role-gitlab-runner/
  tasks/
    main.yml                          # Load vars, validate, branch to platform
    main-unix.yml                     # Unix: install → verify → register → config
    main-windows.yml                  # Windows equivalent
    main-container.yml                # Container equivalent
    install-debian.yml                # Debian/Ubuntu install via packages.gitlab.com
    install-redhat.yml                # RedHat/CentOS install
    install-macos.yml                 # macOS install
    install-arch.yml                  # Arch Linux install
    install-windows.yml               # Windows install
    install-container.yml             # Container setup
    register-runner.yml               # Runner registration via CLI
    register-runner-windows.yml
    register-runner-container.yml
    config-runners.yml                # by_config_toml: orchestrate per-runner config
    config-runner.yml                 # by_config_toml: write one runner's section
    config-runners-windows.yml
    config-runners-container.yml
    config-runner-windows.yml
    config-runner-container.yml
    global-setup.yml                  # Write global config.toml header (concurrent, etc.)
    global-setup-windows.yml
    list-configured-runners-unix.yml  # Populate registered_gitlab_runner_names
    list-configured-runners-windows.yml
    list-configured-runners-container.yml
    unregister-runner.yml
    unregister-runner-if-not-longer-configured.yml
    update-config-runner.yml
    update-config-runner-windows.yml
    section-config-runner.yml
    section-config-runner-windows.yml
    line-config-runner.yml
    line-config-runner-windows.yml
    validate-runner-config.yml
    systemd-reload.yml
    update-ca-bundle.yml
    template_config/
      main.yml                        # by_template mode entry point
      load_existing_fields.yml        # Reads id/token fields from existing file
  defaults/main.yml                   # All role variables — public interface
  vars/
    Archlinux.yml                     # Platform-specific variable overrides
    Darwin.yml
    (other platform files)
  handlers/main.yml                   # Restart handlers — see handler names below
  templates/
    config.toml.j2                    # Main config template (by_template mode)
    config.runners.docker.services.j2
    config.runners.docker.services_devices.j2
    config.runners.feature_flags.j2
    config.runners.machine.autoscaling.j2
    config.runners.autoscaler/        # Cloud autoscaler templates (AWS, Azure, GCP)
  filter_plugins/
    regex_utils.py                    # TOML manipulation Jinja2 filters
  meta/main.yml                       # Galaxy metadata, platform list
  molecule/
    default/
      molecule.yml                    # Docker driver: mock + runner containers
      converge.yml                    # Applies the role
      vars/                           # Test variable sets (common, initial, updated)
      expected/                       # Expected TOML output fixtures
      tests/                          # testinfra test suite
      mock/                           # Mock GitLab API server (Python/Flask)
  .github/
    workflows/
      ansible.yml                     # ansible-lint CI on PR to master
      stale.yml                       # Stale issue/PR management
  .ansible-lint
  requirements.yml                    # Collection dependencies
  README.md
  LICENSE                             # MIT
  CLAUDE.md                           # This file
```

---

## Handler Names

Handler names are part of the role's public interface. Consumers' playbooks
may `listen:` or `notify:` on these names. Do not rename them without a
BREAKING CHANGE commit footer.

| Handler name                       | Fires when                              |
|------------------------------------|-----------------------------------------|
| `restart_gitlab_runner`            | Linux non-macOS, non-Windows, non-container |
| `restart_gitlab_runner_macos`      | macOS                                   |
| `restart_gitlab_runner_windows`    | Windows                                 |
| `restart_gitlab_runner_container`  | Docker container install                |

---

## Conventions

* **Commits** — follow the "Git Commit Message Constraints" section exactly.
  Conventional Commits, imperative mood, body wrapped at 72 characters,
  asterisk bullets.
* **Lint** — run `ansible-lint` before every commit. The CI workflow at
  `.github/workflows/ansible.yml` runs it on every PR to master.
* **Molecule** — run `molecule test` locally before pushing. The scenario
  uses a mock GitLab API server (`molecule/default/mock/`) and
  `geerlingguy/docker-ubuntu2204-ansible` as the runner platform. When
  Resolute images become available, the molecule platform must be updated.
* **FQCNs** — use `ansible.builtin.*` throughout. Non-builtin modules must
  use their full collection-qualified name (`community.docker.*`, etc.).
* **Idempotency** — every task must be safe to re-run. The second
  `molecule converge` must report zero changes.
* **Secrets** — registration tokens, cache keys, and SSH passwords must
  never appear in Ansible output. Keep
  `no_log: "{{ gitlab_runner_no_log_secrets | default(true) }}"` on every
  task that passes secrets to `gitlab-runner register`.
* **Site-specific values** — GitLab URLs, tokens, executor details, and
  cache credentials must never be hard-coded in the role. They belong in
  `host_vars`, `group_vars`, or inventory.

---

## Settled Decisions — Don't Re-Litigate

These are locked. Don't propose alternatives unless the human raises them.

* **`defaults/main.yml` only — no `vars/main.yml`.** All variables live in
  `defaults/` so every consumer can override them. Do not introduce a
  `vars/main.yml`.

* **Three config update modes are retained as-is.** `by_config_toml`,
  `by_registering`, and `by_template` each serve different consumer needs.
  Don't collapse them.

* **Registration uses the `gitlab-runner register` CLI.** The role shells
  out to the runner binary for registration. Do not replace this with API
  calls or template-only approaches.

* **Authentication-token workflow is preferred for GitLab 16+.** The
  deprecated `registration-token` path is retained for backward
  compatibility but should not be extended. New features should target
  `authentication-token` mode.

* **Handlers, not immediate restarts.** Config changes must notify handlers,
  not use `state: restarted` directly in tasks. Tasks use `state: started`;
  handlers use `state: "{{ gitlab_runner_restart_state }}"`.

* **Upstream will not receive PRs from this fork.** Changes stay here.

---

## Known Issues / Active Work

* **Ubuntu Resolute (26.04) install fails.** `install-debian.yml` runs the
  `packages.gitlab.com` setup script, which does not yet recognize the
  `resolute` codename. Fix options: patch the script invocation to override
  the detected codename, add a manual apt repo task for Resolute, or set
  `gitlab_runner_skip_package_repo_install: true` with a pre-configured
  repo. This is the primary open work item.

* **Molecule platform is Ubuntu 22.04.** `molecule/default/molecule.yml`
  uses `geerlingguy/docker-ubuntu2204-ansible`. Once a Resolute-compatible
  image exists (e.g., `geerlingguy/docker-ubuntu2604-ansible`), update the
  platform to validate the Resolute install path.

* **`.travis.yml` is dead.** The file exists but Travis CI is no longer
  used. Can be removed at any time.

* **`ansible.yml` CI triggers on PR to `master`, not `main`.** The default
  branch is `main`. The workflow filter should be updated.

---

## Working With the Consumer Side

This role is consumed from the playbooks repo. Inventory layout,
`group_vars`, and `host_vars` live there, not here. When the human asks
about consumer-side changes, ask which inventory repo to operate on — it
is not in this directory tree.

---

## Git Commit Message Constraints

Your task is to generate a high-quality git commit message based on the
currently staged changes in the `ansible-role-gitlab-runner` repository.

### Step 1 — Retrieve Changes

Run:

```
git diff --cached
```

Analyze the full staged diff. This is the **single source of truth** for
what will be committed.

### Step 2 — Understand the Change

Determine:

* The **primary purpose** of the change
* The **type of change** (feature, bug fix, refactor, etc.)
* The **most relevant scope** within the role
* Whether the change introduces a **breaking change** for role consumers
* Whether multiple changes should be summarized together

Pay special attention to:

* Changes to `defaults/main.yml` — these define the role's public interface;
  any renamed or removed variable is a breaking change for consumers
* Changes to handler names — consumers' playbooks may reference them; a
  rename breaks the notify chain silently
* Changes to `register-runner.yml` or `config-runner.yml` — these touch
  secrets and registration logic; note `no_log` impact
* Changes to `install-debian.yml` — these affect the Resolute install path
  and GPG keyring handling
* Changes to `meta/main.yml` — Galaxy namespace, min Ansible version, or
  supported platform list
* Changes to `molecule/` — test coverage and the mock server
* Changes to `config_update_mode` logic — affects all three config paths

If multiple files are modified, identify the **dominant intent** rather
than listing every file.

### Step 3 — Select Commit Type

Use Conventional Commits:

* feat — new task, variable, template feature, or capability
* fix — bug fix, idempotency correction, or handler wiring fix
* docs — README, CLAUDE.md, or inline YAML comments
* style — YAML formatting, whitespace, ansible-lint cleanup
* refactor — restructure tasks or templates without behavior change
* perf — performance improvement (e.g., fewer shell invocations, apt calls)
* test — molecule scenarios, testinfra tests, mock server, lint config
* chore — Galaxy metadata, tooling, pre-commit hook, requirements.yml
* ci — GitHub Actions workflows

### Step 4 — Determine Scope

Infer a scope from the role layout or the GitLab Runner subsystem changed.

Common role-layout scopes:

* tasks
* defaults
* handlers
* templates
* meta
* molecule
* filter

Common feature scopes:

* install
* register
* config
* docker
* windows
* container
* cache
* autoscaler
* tls
* resolute

Only include a scope when it adds clarity. Prefer the feature scope for
feature-driven changes (e.g., `fix(resolute): ...`, `feat(autoscaler): ...`)
and the layout scope for structural changes
(e.g., `refactor(tasks): ...`, `chore(meta): ...`).

### Step 5 — Write the Commit Message

Format exactly as:

```
<type>[optional scope]: <short summary (<=50 chars)>

<body wrapped at 72 characters>

[optional footer(s)]
```

#### Subject Line Rules

* Use **imperative mood** ("Add", "Fix", "Update", "Remove")
* Maximum **50 characters**
* Describe the **result**, not the implementation
* Prefer GitLab Runner or Ansible terminology over generic phrasing
  (e.g., "Fix Resolute apt repo detection", not "Fix install bug")

#### Body Rules

The body is **required**.

Explain **why the change was made**, focusing on:

* What GitLab Runner behavior or deployment scenario motivated it
* What downstream role consumers need to know to upgrade safely
* Any GitLab Runner version, Ubuntu release, or Ansible version constraints

When helpful, summarize key changes using bullet points.

#### Bullet Rules

* Use `*` (asterisk) for all bullets
* Do NOT use `-` or `•`
* Nested bullets must be indented with two spaces
* Do not use Markdown formatting of any kind

Example:

```
* Add resolute codename override to install-debian.yml
* Preserves existing behavior on jammy, noble, and questing
  * Controlled by new gitlab_runner_debian_codename_override var
```

#### Ansible-Specific Expectations

* Call out new, renamed, or removed default variables — these are part
  of the role's public interface
* Note when handler names change — consumers' playbooks may reference them
* Mention idempotency impact when relevant
* Flag changes to `meta/main.yml` (namespace, min version, platforms)
* Note when molecule test coverage changes

#### GitLab Runner–Specific Expectations

* Distinguish between install, register, and config changes — they affect
  different stages of the runner lifecycle
* Note when a change affects only one config update mode
  (`by_config_toml`, `by_registering`, or `by_template`)
* Call out changes that affect secret handling or `no_log` usage
* Flag changes to the GPG keyring path or apt repo setup — these break
  installs silently if wrong
* Note changes to the authentication-token vs registration-token paths
* Highlight platform-specific changes (Resolute, Windows, macOS, container)

---

### Breaking Changes

A change is breaking when it:

* Renames or removes a variable in `defaults/main.yml`
* Changes a default value in a way that alters runtime behavior
  (e.g., changing `gitlab_runner_config_update_mode` default)
* Renames a handler (breaks `notify:` chains in consumer playbooks)
* Changes the `config.toml` structure in `by_template` mode in a way that
  requires consumers to migrate existing runner state
* Drops a supported platform from `meta/main.yml`
* Bumps `min_ansible_version` in `meta/main.yml`
* Changes the Galaxy namespace or role name in `meta/main.yml`
* Removes or renames a key in the `gitlab_runner_runners` list schema

If the diff introduces a breaking change:

* Add `!` after the type/scope in the subject
* Include a footer: `BREAKING CHANGE: <description>`

### Examples

```
fix(resolute): override apt codename for Ubuntu 26.04

feat(defaults): add gitlab_runner_debian_codename_override variable

refactor(tasks): extract per-platform install into include files

test(molecule): update runner platform to ubuntu2604-ansible image

ci: fix workflow branch filter from master to main

chore(meta): pin supported Ubuntu versions in Galaxy metadata

docs(readme): add fork notice and maintainer contact

fix(handlers)!: rename restart handler to restart_gitlab_runner

BREAKING CHANGE: handler was previously named Restart_gitlab_runner
(capital R); update any notify: references in consumer playbooks.
```

---

### Output Rules

When asked to generate a commit message, return **ONLY the commit
message**.

Do NOT include:

* explanations
* analysis
* the diff
* markdown formatting
* code fences

The output must be a **clean commit message ready for `git commit`**.
The output will be pasted directly into a git commit editor; optimize
for copy/paste fidelity over styling.

---

## How to Continue This Work in Claude

When starting a new conversation in this project, Claude will have this
file as project knowledge. Example prompts to continue:

* "Fix the Ubuntu Resolute install failure in install-debian.yml"
* "Update the Molecule platform to use a Ubuntu 26.04 image"
* "Add a verify task that checks gitlab-runner service is running"
* "Fix the CI workflow to trigger on PRs to main instead of master"
* "Generate a commit message for the current staged changes"
* "Add support for the new GitLab Runner autoscaler on AWS"

---

## When in Doubt

Read this file end-to-end, then ask. The settled decisions above are
load-bearing — they reflect deliberate choices, not defaults.

---

*Last updated by Claude on 2026-05-10*

[upstream]: https://github.com/riemers/ansible-gitlab-runner
[karpathy-claude]: https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md
