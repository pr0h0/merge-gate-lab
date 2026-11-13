# Bypass and exception policy (template)

Replace the `<...>` parts. Keep this file in the security team's repo, next to the scripts that check it.

## Who can bypass
- Ruleset bypass list: only `OrganizationAdmin` in `pull_request` mode (no `always`, no Apps, no deploy keys).
- People who may use it: `<names of the break-glass owners, two at most>`.
- Nobody bypasses their own PR unless the incident runbook says so.

## When a bypass is allowed
1. A production incident fix that can't wait for the gate or a code owner (link the incident).
2. The gate itself is broken (scanner outage, registry down) and the change is urgent (link the gate issue).
3. A security team change that its only reviewer wrote (small teams; say so in the comment).

Anything else waits for the review, or gets an exception.

## How a bypass is recorded
- Before merging with `--admin`, comment on the PR: `Bypass: <why>, <incident or ticket link>`.
- `bypasses.sh` marks every bypass without such a comment as `NONE`.

## Exceptions instead of bypasses
- A finding that is accepted for a while goes into `.github/security-exceptions.yml`, with all fields, an owner team and an expiry at most 90 days away.
- Renewing means a new PR with a new date and a new reason. Two renewals in a row go to `<security lead>`.

## Weekly review (every `<Monday>`, 20 minutes, `<owner>`)
1. `PERIOD=week ./bypasses.sh` and save the output in `<archive location>` (the API keeps one month).
2. For each bypass: was it allowed above? Is the reason real? Did the skipped check or review happen afterwards?
3. `./exceptions-register.sh`: renew or remove everything marked `SOON`; open a ticket for every `EXPIRED`.
4. Write down the counts (bypasses, without reason, exceptions, expiring) in `<metrics sheet>` for lesson 8.3.
