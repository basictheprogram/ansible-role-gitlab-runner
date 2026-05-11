#!/usr/bin/env bash
# Run all automatable molecule scenarios.
#
# Scenarios not run here (require external infrastructure):
#   macos   — needs a pre-provisioned macOS host (MOLECULE_MACOS_HOST)
#   windows — needs a pre-provisioned Windows host (MOLECULE_WINDOWS_HOST)
set -euox pipefail

# ── default (Ubuntu + Debian) ─────────────────────────────────────────────
molecule create

TEST_VARS_FILE=vars/initial.yml molecule converge
EXPECTED_TOML=expected/initial.toml molecule verify

TEST_VARS_FILE=vars/updated.yml molecule converge
EXPECTED_TOML=expected/updated.toml molecule verify

molecule destroy

# ── redhat (Enterprise Linux) ─────────────────────────────────────────────
molecule create -s redhat

TEST_VARS_FILE=vars/initial.yml molecule converge -s redhat
EXPECTED_TOML=expected/initial.toml molecule verify -s redhat

TEST_VARS_FILE=vars/updated.yml molecule converge -s redhat
EXPECTED_TOML=expected/updated.toml molecule verify -s redhat

molecule destroy -s redhat
