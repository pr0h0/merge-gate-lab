# 0.3 You can't harden what you can't list

`inventory.sh` lists every repo in `$ORG` with the settings this course changes, plus an org snapshot.
Needs `gh` (logged in as an org owner, `admin:org` scope) and `jq`.

```bash
ORG=<your-test-org>
cd lessons/0.3-inventory
ORG=$ORG OUT=before.json ./inventory.sh
```

Keep `before.json`. The capstone runs the script again and compares.

Columns: `true`/`false` came from the API; `?` means the script could not tell (usually not an admin
on that repo, or a rate limit). It makes about 6 API calls per repo; a 1,000-repo org uses about
6,000 of your 5,000-per-hour REST quota, so split big orgs or run it twice.
