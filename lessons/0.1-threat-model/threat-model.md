# Threat model: <org name>

Owner: <name> · Date: <yyyy-mm-dd> · Review again: <date + 6 months>

## 1. What we have
| Item | Count / answer |
|---|---|
| Repos (public / private / internal / archived) | |
| Repos that deploy to production | |
| GitHub plan (Free / Team / Enterprise Cloud) | |
| Coding agents in use (IDE, CLI, cloud agents, bots) | |
| Agents or bots that open PRs | |
| CI systems holding production credentials | |
| MCP servers / agent plugins developers install | |

## 2. Threats
Score likelihood and impact 1–3. "Control today" is what stops it now, and who can switch that off.

| # | Threat | Where it enters | Likelihood | Impact | Control today | Who can switch it off | Module |
|---|---|---|---|---|---|---|---|
| T1 | More PRs than reviewers can read; risky change merged on a skim | PR / merge | | | | | 2, 3 |
| T2 | Invented or too-new package added by an agent | dependency manifest | | | | | 4 |
| T3 | Agent copies an insecure workflow pattern (dangerous trigger, script injection, broad token) | `.github/workflows` | | | | | 5 |
| T4 | Agent or CI job holds a token with more power than its task | dev machine / CI | | | | | 5, 6, 7 |
| T5 | Prompt injection through issue, PR, comment or doc text read by an agent | issues / PRs / repo files | | | | | 7 |
| T6 | Untrusted MCP server or plugin runs on a developer machine | dev machine | | | | | 6 |
| T7 | Secret committed (by a person or an agent) | push | | | | | 2 |
| T8 | A protection is switched off and nobody notices | org / repo settings | | | | | 8 |
| T9 | <your own> | | | | | | |

## 3. Layers
For each layer, write the one control you would add first and who owns it.

| Layer | First control | Owner | Can a developer or agent turn it off? |
|---|---|---|---|
| Developer machine (agent settings, hooks) | | | |
| PR gate (required checks) | | | |
| Merge rules (rulesets, CODEOWNERS) | | | |
| Org policy (Actions, secret scanning, Dependabot) | | | |
| Monitoring (drift, bypasses, alerts) | | | |

## 4. Top three to fix this quarter
1.
2.
3.
