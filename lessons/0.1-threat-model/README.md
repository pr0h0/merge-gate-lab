# 0.1 What AI changed for the people who own the repos

No scripts in this lesson. It has one file to fill in:

- `threat-model.md`: a one-page threat model for your own org. Copy it, fill it in, and keep it next to
  your inventory from lesson 0.3. You will revisit it in the capstone.

Quick check you can run now (no account needed). It asks the npm registry whether a package name exists:

```bash
for p in express express-session-guard-pro; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code}' "https://registry.npmjs.org/$p")" "$p"
done
```

`200` means the name is registered. `404` means nobody owns it yet, so anyone could register it.
On 2026-11-13 the second name returned 404.
