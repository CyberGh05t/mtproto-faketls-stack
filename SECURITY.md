# Security Policy

This repository contains operational relay configuration. Treat it as private
infrastructure material unless the repository owner explicitly decides
otherwise.

## Sensitive Data

Do not commit:

- MTProto secrets;
- SOCKS5 usernames or passwords;
- private keys, certificates, tokens, cookies, or API keys;
- live public IP addresses;
- credential-bearing proxy URLs;
- deployment-only `.env` files;
- local tool state such as `.claude/`, `.codex`, or editor caches.

Use placeholders in tracked files:

```text
YOUR_32HEX_SECRET_NO_EE_PREFIX
YOUR_USERNAME
YOUR_PASSWORD
<PUBLIC_IP_REDACTED>
<TOKEN_REDACTED>
```

## Reporting Issues

Report security issues privately to the repository owner. Do not open public
issues or publish details that reveal live relay endpoints, credentials, or
traffic-routing behavior.

## Pre-Commit Checks

Before committing release or deployment changes, inspect tracked files for
common secret patterns:

```sh
git grep -nE '(password|passwd|secret|token|private_key|BEGIN (RSA|OPENSSH|EC|PRIVATE)|://[^[:space:]]+:[^[:space:]@]+@)'
git grep -nE '([0-9]{1,3}\.){3}[0-9]{1,3}'
```

The IP-address scan is intentionally noisy. Public IPs should not be documented
in tracked project files; local loopback addresses are expected in configs.
