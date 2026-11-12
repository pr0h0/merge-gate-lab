# merge-gate-lab

Lab and configs for hardening a GitHub organization's repos and merge gates when much of the code is written by AI agents.

**Work in progress.**

- `lab-template/`: a small, deliberately insecure Node service with weak workflows.
- `bootstrap/bootstrap.sh <test-org>`: creates a fleet of five weak repos in a throwaway org you own.
- `lessons/`: one directory per lesson, holding the workflows, configs and scripts that lesson uses.

Only run any of this against a test organization you own.
