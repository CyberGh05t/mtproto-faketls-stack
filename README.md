# mtproto-faketls-stack

Operational configuration for a single-host MTProto FakeTLS relay stack.

The stack keeps one public TCP entry point on port 443 and routes different
traffic types to local backends:

- MTProto FakeTLS traffic goes to `telemt`.
- Ordinary HTTPS traffic goes to a decoy nginx site.
- SOCKS5 traffic goes to `3proxy`.
- Docker container logs go to persistent systemd-journald storage.

The primary goal is stable MTProto proxy service on port 443. The secondary
goal is keeping the decoy HTTPS site believable and available.

## Architecture

```text
internet
  |
  | TCP/443
  v
HAProxy
  |
  +-- TLS ClientHello with SNI yandex.ru -> telemt 127.0.0.1:3128
  |
  +-- SOCKS5 first byte 0x05 ------------> 3proxy 127.0.0.1:1080
  |
  +-- other TLS / fallback --------------> nginx decoy 127.0.0.1:8443
```

The public listener is owned by HAProxy. nginx does not bind public `:443` in
the current design.

Outbound connectivity can optionally use a local sing-box egress bridge when
the relay host cannot reach Telegram DCs directly:

```text
telemt 127.0.0.1:3128
  |
  | SOCKS5 upstream 127.0.0.1:10809
  v
sing-box mixed inbound
  |
  | HTTP CONNECT outbound
  v
residential proxy
  |
  v
Telegram DCs
```

The bridge is local-only and does not change the public HAProxy listener.

## Components

### HAProxy

File:

- `deploy/haproxy/haproxy.cfg`

Role:

- binds public `*:443`;
- inspects early TCP bytes;
- routes FakeTLS traffic by SNI;
- routes SOCKS5 traffic by protocol prefix;
- sends all other TLS/fallback traffic to the decoy site.

Current backend mapping:

```text
bk_telemt      -> 127.0.0.1:3128
bk_3proxy      -> 127.0.0.1:1080
bk_nginx_decoy -> 127.0.0.1:8443
```

### telemt

Files:

- `deploy/telemt/config.toml`
- `deploy/telemt/docker-compose.yml`

Role:

- provides MTProto FakeTLS service;
- listens on `127.0.0.1:3128`;
- uses `yandex.ru` as the FakeTLS mask domain;
- runs as a Docker container with host networking;
- persists beobachten snapshots under `/var/lib/telemt` inside the container.

The real MTProto secret must not be committed. Use the placeholder in
`deploy/telemt/config.toml` as the tracked example value and keep the live
secret only on the relay host.

### sing-box Egress Bridge

Files:

- `deploy/sing-box/config.example.json`
- `deploy/sing-box/docker-compose.yml`

Role:

- exposes a loopback-only proxy listener for telemt;
- sends outbound traffic through a residential HTTP CONNECT proxy;
- keeps provider credentials on the relay host only.

Use this when direct relay-host egress to Telegram DCs is blocked. Do not expose
the sing-box listener publicly.

### nginx Decoy

File:

- `deploy/nginx/nginx.conf`

Role:

- redirects HTTP port 80 to HTTPS;
- serves the decoy site on `127.0.0.1:8443`;
- uses the certificate configured on the relay host;
- serves static files from `/var/www/decoy`.

The repository may contain a local ignored copy of the decoy static build under
`PlitkaKlal/site/dist`. That directory is intentionally not source of truth for
the relay config and is ignored by git.

### 3proxy

Files:

- `deploy/3proxy/3proxy.cfg`
- `deploy/3proxy/3proxy.service.override.conf`

Role:

- provides an internal SOCKS5 listener on `127.0.0.1:1080`;
- uses strong auth;
- logs to `/var/log/3proxy/3proxy.log`.

Do not commit real SOCKS5 users or passwords. The tracked config contains
placeholders only.

## Repository Layout

```text
deploy/
  3proxy/
    3proxy.cfg
    3proxy.service.override.conf
  haproxy/
    haproxy.cfg
  journald/
    mtproto-docker.conf
  nginx/
    nginx.conf
  sing-box/
    config.example.json
    docker-compose.yml
  telemt/
    config.toml
    docker-compose.yml
```

## Decoy Site State

The live relay currently serves a static decoy build from `/var/www/decoy`.
If local `PlitkaKlal/site/dist` is present, it may be a server-synced copy of
that deployed build.

Useful commands:

```sh
make list-decoy
make preview-decoy
make diff-decoy
make pull-decoy
```

`make diff-decoy` performs an rsync dry run from the relay host to local
`PlitkaKlal/site/dist`. `make pull-decoy` updates local `dist` from the relay
host and deletes local files that do not exist in the deployed build.

## Validation

Local checks:

```sh
make validate
```

This runs the checks that are available on the local workstation. Missing tools
are skipped instead of faking success.

Relay-host checks after deployment:

```sh
systemctl status haproxy nginx 3proxy
docker ps
journalctl CONTAINER_NAME=telemt
journalctl CONTAINER_NAME=sing-box-telemt-egress
ss -ltnp
haproxy -c -f /etc/haproxy/haproxy.cfg
nginx -t
```

Behavior checks should be separated:

1. Service health: units and container are running.
2. Port routing: HAProxy owns public `:443`; local backends listen on loopback.
3. Generic proxy behavior: simple TCP or curl-style checks where applicable.
4. Telegram client behavior: connection, messages, bots.
5. Call behavior: validate separately from normal Telegram chat.

## Deployment Notes

This repository stores source-of-truth config templates, not live secrets.
When syncing to the relay host:

- back up remote files before editing;
- sync only the intended files;
- run syntax checks before reloads;
- reload or restart the affected service only;
- verify the HAProxy listener and backend listeners after the change;
- inspect service logs when behavior changes.

Common live paths:

```text
/etc/haproxy/haproxy.cfg
/etc/nginx/nginx.conf
/opt/mtproto/telemt/config.toml
/opt/mtproto/telemt/docker-compose.yml
/opt/mtproto/telemt/data/beobachten.txt
/opt/mtproto/sing-box/config.json
/opt/mtproto/sing-box/docker-compose.yml
/etc/systemd/journald.conf.d/mtproto-docker.conf
/etc/3proxy/3proxy.cfg
/var/www/decoy
```

## Security

Never commit:

- real MTProto secrets;
- real SOCKS5 users or passwords;
- private keys or TLS account material;
- deployment-only environment files;
- local tool state;
- public IP addresses or credential-bearing proxy URLs.

Before commits or public release work, run a targeted secret scan over tracked
files. See `SECURITY.md` for the project security policy.

## Operational Assumptions

- Port 443 is the only public relay entry point for proxy traffic.
- HAProxy owns public TCP routing.
- telemt, nginx decoy, and 3proxy listen only on loopback.
- The relay host may not have usable global IPv6 routing.
- Telegram chat behavior and Telegram call behavior are not equivalent tests.
