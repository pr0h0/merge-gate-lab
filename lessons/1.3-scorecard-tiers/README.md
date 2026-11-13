# 1.3 Scorecard, repo tiers and a risk-ranked backlog

1. `scorecard.sh` runs OpenSSF Scorecard v5.6.0 (docker) on every repo. The token comes from
   `gh auth token` and is passed to the container by name, never printed.
2. Two org custom properties: `tier` (critical / standard / sandbox, required, default standard)
   and `owner-team`. Both editable by org actors only.
3. `backlog.sh` joins tiers, the lesson 1.2 scan and Scorecard into a markdown table ranked by
   severity x tier weight.

```bash
ORG=<your-test-org>
cd lessons/1.3-scorecard-tiers
ORG=$ORG ./scorecard.sh

gh api -X PUT "orgs/$ORG/properties/schema/tier" --input tier.json
gh api -X PUT "orgs/$ORG/properties/schema/owner-team" --input owner-team.json
./set-tier.sh payments-api critical payments
./set-tier.sh orders-api critical orders
./set-tier.sh internal-admin standard platform
./set-tier.sh marketing-site standard web
./set-tier.sh legacy-cron sandbox platform

ORG=$ORG ./backlog.sh > backlog.md   # needs ../1.2-fleet-scan/scan from lesson 1.2
```
