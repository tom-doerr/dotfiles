# Tailscale Services — movable service names

Service names (MagicDNS `<svc>.tail620cfa.ts.net`, each with its own virtual IP):

| service           | port | today's host | config file            |
|-------------------|------|--------------|------------------------|
| `svc:vllm`        | 8000 | spark-2      | services-spark-2.json  |
| `svc:infinity`    | 7997 | spark-3      | services-spark-3.json  |
| `svc:qwen-metric` | 8420 | spark-3      | services-spark-3.json  |

Clients use `http://vllm.tail620cfa.ts.net:8000/v1` etc. Moving a service =
`tailscale serve clear svc:NAME` on the old host + `tailscale serve set-config
<file>` on the new one. Nothing else changes.

## One-time admin-console setup (only the tailnet owner can do this)

1. Policy file (Access controls), add — hosts of a Service MUST be tagged:
   ```jsonc
   "tagOwners": { "tag:spark": ["autogroup:admin"] },
   "autoApprovers": { "services": { "svc:vllm": ["tag:spark"],
                                   "svc:infinity": ["tag:spark"],
                                   "svc:qwen-metric": ["tag:spark"] } },
   "grants": [ { "src": ["autogroup:member"],
                 "dst": ["svc:vllm", "svc:infinity", "svc:qwen-metric"],
                 "ip": ["tcp:8000", "tcp:7997", "tcp:8420"] } ]
   ```
   (keep the existing allow-all `acls`/`grants` so SSH etc. keep working.)
2. Machines → spark-2 and spark-3 → "Edit ACL tags" → add `tag:spark`.
   (A tagged node has no key expiry, which is a bonus here.)
3. Apply on the hosts (re-runnable):
   ```
   ssh spark-2 'tailscale serve set-config ~/git/dotfiles/tailscale/services-spark-2.json --all'
   ssh spark-3 'tailscale serve set-config ~/git/dotfiles/tailscale/services-spark-3.json --all'
   ```
   With autoApprovers in place the advertisement is approved automatically;
   otherwise Services page → Approve. Verify: `getent hosts vllm.tail620cfa.ts.net`
   and `curl http://vllm.tail620cfa.ts.net:8000/v1/models`.
4. Flip every client to the service names (idempotent, prints a diff first):
   `~/git/dotfiles/scripts/service-endpoints --phase tailscale` then `--apply`,
   commit per repo, restart the consumers listed in ~/CLAUDE.md.

Gotcha found Aug 22 2026: `tailscale serve --service=...` on an untagged node
prints `service hosts must be tagged nodes` (rc 0!) and configures nothing.
