# 1.1 Org settings that matter, and their defaults

`check-org.sh` reads the org settings with security impact and prints PASS / FAIL / UNKNOWN
against `policy.json`. Scalars must match; lists (`outside_collaborators`, `apps_installed`, ...)
are allowlists. Exit code 1 if anything is not PASS, so it can run in a scheduled job later.
Needs `gh` (org owner, `admin:org` scope) and `jq`.

```bash
ORG=<your-test-org>
cd lessons/1.1-org-settings
ORG=$ORG ./check-org.sh
```

Apply the settings that have an API (run against your TEST org):

```bash
gh api "orgs/$ORG/members?filter=2fa_disabled" --jq 'map(.login)'          # must be [] before requiring 2FA
gh api -X PATCH "orgs/$ORG" -f default_repository_permission=none -F members_can_create_repositories=false
gh api -X PUT "orgs/$ORG/actions/permissions/fork-pr-contributor-approval" -f approval_policy=all_external_contributors
ORG=$ORG ./check-org.sh
```

UI only (no REST field; `PATCH /orgs` returns 200 and ignores them): 2FA requirement,
members changing visibility, deleting repos, inviting outside collaborators, OAuth app
restrictions, personal access token policy.

Left failing on purpose: `allowed_actions` and `sha_pinning_required` (lesson 4.4).
