# sing-box egress bridge

This directory contains a secret-free template for the telemt egress bridge.

The live relay uses sing-box only on loopback:

```text
telemt -> 127.0.0.1:10809 -> sing-box -> residential HTTP CONNECT proxy -> Telegram
```

The public ingress path stays unchanged:

```text
internet TCP/443 -> HAProxy -> telemt 127.0.0.1:3128
```

## Live paths

```text
/opt/mtproto/sing-box/config.json
/opt/mtproto/sing-box/docker-compose.yml
```

## Secret handling

Do not commit the live residential proxy host, port, username, password, or full proxy URL.

On the relay host, create `/opt/mtproto/sing-box/config.json` from `config.example.json` and replace these placeholders:

```text
HTTP_PROXY_HOST_PLACEHOLDER
HTTP_PROXY_USER_PLACEHOLDER
HTTP_PROXY_PASS_PLACEHOLDER
```

Also set `server_port` to the provider HTTP proxy port.

## Validation

After deployment, verify that sing-box listens only on loopback:

```sh
ss -ltnp | grep 10809
```

Expected listener:

```text
127.0.0.1:10809
```

Verify the bridge with a harmless HTTPS request:

```sh
curl --socks5-hostname 127.0.0.1:10809 --max-time 15 https://core.telegram.org/getProxyConfig -o /tmp/proxy-config-v4.txt
```

Expected: curl exits `0` and `/tmp/proxy-config-v4.txt` is non-empty.

Check container health:

```sh
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep sing-box-telemt-egress
```

Expected: status includes `healthy`.

## Logs

The container uses the Docker `journald` logging driver. Logs survive container
recreation because they are stored by systemd-journald instead of the Docker
container JSON file.

View logs:

```sh
journalctl CONTAINER_NAME=sing-box-telemt-egress
```

The relay host should install `deploy/journald/mtproto-docker.conf` as:

```text
/etc/systemd/journald.conf.d/mtproto-docker.conf
```

That drop-in keeps persistent journal storage capped at 100 MB, split into at
most 10 files.

## Rollback

1. Switch telemt back to the direct upstream in `/opt/mtproto/telemt/config.toml`.
2. Restart telemt.
3. Stop sing-box with `docker compose -f /opt/mtproto/sing-box/docker-compose.yml down`.
4. Confirm telemt still listens on `127.0.0.1:3128`.
