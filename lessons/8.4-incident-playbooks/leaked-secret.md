# Playbook: a secret was pushed to a repo

Use this when secret scanning, the gate's gitleaks step, a person or a provider tells you that a
credential is in a commit, a PR, an issue, a log or a workflow artifact. Copy it into your
incident ticket and tick the steps. `ORG`, `REPO` and the alert number are shell variables.

Rule zero: **the secret is burned the moment it reached GitHub.** Deleting the file, the branch,
the PR or even the commit doesn't take it back. A closed PR's `refs/pull/<n>/head` and the commit
are still served after the branch is deleted, forks and clones keep their copy, and public repos
are scraped within minutes. So revoke first, clean up later.

## 1. Contain (first 15 minutes)
1. Open a ticket, name one incident lead, start a timeline (UTC times, who did what).
2. Identify the credential: provider, account, scope, environment. Read the alert:
   `gh api repos/$ORG/$REPO/secret-scanning/alerts/$N --jq '{secret_type_display_name, created_at, validity, html_url}'`
   and where it appears: `gh api repos/$ORG/$REPO/secret-scanning/alerts/$N/locations`.
3. **Revoke or rotate it at the provider now.** Issue a new credential, store it where the
   app reads it (Actions or environment secret, vault), deploy, then revoke the old one. If
   rotating would break production, revoke anyway when the key has write access to anything
   that matters; an outage is cheaper than an intruder.
4. If it was a GitHub token (PAT, App key, deploy key): revoke it in the owner's settings or the
   App's settings. A leaked `GITHUB_TOKEN` expires when its job ends; check whether the job was
   still running.

## 2. Find the scope of use
1. When was it first exposed? The commit date in the alert location, or the first CI log that
   printed it. Exposure window = first push until revocation.
2. Was it public? Public repo, public fork, a log of a public repo's workflow, an issue comment.
3. What did the key do during the window? Look in the provider's access logs (cloud audit trail,
   API key usage page) for calls from unknown IPs or user agents. For a GitHub credential the
   org audit log shows its use; on Free and Team that is the web UI only (180 days, owners only),
   the audit log API needs Enterprise Cloud.
4. What else could the same person or job see? If it came from a CI job, list the secrets that
   job had: `gh secret list -R $ORG/$REPO`, `gh secret list --env <env> -R $ORG/$REPO`, and
   org secrets shared with the repo. Treat those as exposed too if the job printed its env.
5. Write down: what leaked, where, how long, used or not, what was rotated.

## 3. Clean up (optional, after rotation)
1. Remove the value from the current code and move it to a secret store in a normal PR.
2. Rewriting history is optional and only removes your copy. If you do it: `git filter-repo`
   (`--replace-text` with the value), force-push every branch and tag, ask everyone to re-clone.
   Rulesets block force pushes (`non_fast_forward`) for good reasons; lift that rule only for
   the cleanup and put it back (`check-drift.sh` tells you if you forgot).
3. Cached views and PR refs stay on GitHub after a rewrite. GitHub Support can remove them, and
   says it only does so when rotating the credential can't mitigate the risk.

## 4. Close the alert with the true reason
- `revoked` when you rotated it:
  `gh api -X PATCH repos/$ORG/$REPO/secret-scanning/alerts/$N -f state=resolved -f resolution=revoked -f resolution_comment="Rotated <date>, ticket <id>"`
- `false_positive`, `used_in_tests` or `wont_fix` only with a reason a reviewer can check.
  A test value that matches a real provider format gets sent to that provider; use values
  that match no format.

## 5. Stop the next one
- Was push protection on for this repo? If it was bypassed, who chose which reason?
- Did the gate's gitleaks step run on the PR? If the secret came in through a direct push, why
  could someone push directly?
- If an agent wrote it: was the value in the agent's environment or a file it could read
  (`.env`)? Tighten its read rules and environment (module 6).
- Add the miss to the weekly review (8.1) and to the metrics (8.3).
