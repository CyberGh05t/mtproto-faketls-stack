# Contributing

This repository describes an operational MTProto FakeTLS relay stack. Changes
must be small, explicit, and verified before they are deployed.

## Ground Rules

- Do not commit live secrets, proxy credentials, private keys, real user lists,
  local tool state, or deployment-only environment files.
- Keep port 443 stable. Do not change public routing behavior without a clear
  rollout and rollback path.
- Treat MTProto, decoy HTTPS, and SOCKS5 behavior as separate validation areas.
- Do not assume a generic TCP or curl check proves Telegram client behavior.
- Prefer source-of-truth files under `deploy/` over manual server-only edits.

## Repository Layout

- `deploy/haproxy/haproxy.cfg` controls TCP routing on port 443.
- `deploy/nginx/nginx.conf` serves the HTTPS decoy site on loopback.
- `deploy/telemt/` contains the telemt container config.
- `deploy/3proxy/` contains the SOCKS5 service config and systemd override.
- `PlitkaKlal/` is intentionally ignored. It can hold the decoy site working
  tree or a server-synced static build.

## Change Workflow

1. Inspect the current repo and live service shape before editing.
2. Make the smallest change that addresses the requirement.
3. Validate syntax locally where possible.
4. Sync the exact changed files to the relay host.
5. Run service-specific checks on the relay host.
6. Verify routing through HAProxy and the affected backend.
7. Commit only source-of-truth project files.

## Validation Checklist

For relay config changes:

- `haproxy -c -f deploy/haproxy/haproxy.cfg`
- `nginx -t` on the relay host after syncing nginx config
- `systemctl status haproxy nginx 3proxy`
- `docker ps` or `docker compose ps` for telemt
- `ss -ltnp` on the relay host to confirm listeners

For telemt changes:

- Confirm `127.0.0.1:3128` is listening.
- Inspect telemt container logs.
- Confirm `beobachten_file` is writable by the container user when enabled.
- Verify HAProxy still routes TLS with the configured SNI to telemt.

For decoy site changes:

- Build or sync the static output.
- Confirm nginx serves it on `127.0.0.1:8443`.
- Confirm HAProxy routes non-proxy TLS traffic to nginx.

## Commit Policy

- Use concise English commit messages.
- Do not bundle unrelated workstation state into commits.
- Do not force-add ignored directories such as `PlitkaKlal/` or
  `docs/superpowers/` unless that policy is intentionally changed.
