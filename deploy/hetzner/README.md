# Hetzner migration

Prepared on 2026-10-21. **Root-free setup is complete; origin deployment and DNS
cutover are pending.** The founder explicitly approved this revised path/account.
GitHub Pages and its workflow remain active until the new origin and public HTTPS
have passed verification. The existing Netlify configuration is retained.

Preparation checks passed: exact-version Hugo build locally and in GitHub
Actions, actionlint, shell/Python syntax, and validation in the existing Caddy
container. Comparing the proposed config against the active config preserved
all 17 existing host routes (normalizing generated group IDs and config-file
hide-list ordering). The candidate configuration has not been loaded.

## Deployment

The authoritative workflow is [../../.github/workflows/deploy-hetzner.yml](../../.github/workflows/deploy-hetzner.yml).
Pull requests build without deployment credentials. Pushes to `main` and manual
runs on `main` build with Hugo extended **0.145.0**, verify the official binary's
SHA-256, then rsync the static output over SSH. There is no build on the server.

The dedicated website key in the existing `deploy` account accepts a single
forced `rrsync -wo -munge` command, restricted to
`/srv/static-sites/danielwessendorf.com/public`. This key cannot open a shell,
download files, forward connections, request a PTY or reach other paths. The
operator's existing keys are preserved, with a private backup of authorized_keys.
The SSH configuration lives outside the published directory. The existing
account keeps its operator permissions; only the dedicated key is constrained.
`--delay-updates --delete-after` defers file replacement and deletion until the
transfer's final stage; this is not an atomic swap of the whole site.

On this host Caddy already has a read-only mount of `/srv/static-sites`. The
founder approved using this path directly instead of the original `/srv/www`
target after root access failed. No alias or new OS user is created. No container,
process, mount change or service restart is needed. Only the new site's imported
block is added.

## One-time server setup

Generate a dedicated Ed25519 key locally and transfer **only the public key** to
the server. Run [setup-server.sh](setup-server.sh) as `deploy` on
`dwessendorf-cx33-1`, passing the public key's filename. It preserves existing
authorized_keys bytes and appends only this site's forced command. Conflicting
keys, symlinks or wrong ownership cause a refusal. Neither the proxy nor any
existing app is changed. The approved setup and restricted-key tests passed.

Set these repository Actions secrets without printing their contents:

| Secret | Value |
| --- | --- |
| `HETZNER_HOST` | `5.75.171.94` |
| `HETZNER_SSH_KEY` | Dedicated private key; never the operator's personal key |
| `HETZNER_KNOWN_HOSTS` | Previously verified Ed25519 host-key entry |

Verify that the deploy key refuses `ssh ... id`, downloads and paths escaping
the site root. Test an rsync upload and deletion inside the new site only.

## Cutover sequence

1. Finish restricted-key setup. Keep `.github/workflows/pages.yaml` enabled.
2. Install `Caddyfile` followed by `Caddyfile.preflight` as the single new file
   `/srv/platform/sites/danielwessendorf-com/site.caddy`. The existing top-level
   Caddyfile already imports it. Save the current adapted configuration and
   existing site responses before changing the live configuration.
3. Validate with `docker exec caddy caddy validate --config /etc/caddy/Caddyfile`.
   Reload with `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`.
   No `compose up`, container restart or platform checkout is necessary.
4. Merge the website PR and wait for the GitHub Actions rsync deployment. With
   `HETZNER_VERIFY_HTTPS` unset, its check goes directly to the origin over HTTP.
   The verifier requires the exact revision, homepage hash, section pages,
   referenced CSS/JS/fonts, CV PDF and a real 404. A 200 from Pages cannot pass.
5. In the infrastructure repository change only the apex A records in
   `dns/zones/danielwessendorf.com.js` to `5.75.171.94`; keep Cloudflare proxying
   and the `www` CNAME. Review the DNS preview before applying this one zone via
   the existing `DNS live` workflow. Public Cloudflare AAAA addresses are edge
   addresses, not stale GitHub origin records. The zone currently declares no
   origin AAAA. Do not change other zones, mail, delegation or DNSSEC.
6. Wait for Caddy's automatic certificate issuance. Verify both origin TLS
   (`--resolve`, without `-k`) and public HTTPS. Cloudflare must use Full (strict)
   once the origin certificate is ready. Verify its actual setting separately;
   the DNS token may not have zone-settings permission.
7. Replace the new site's config with `Caddyfile` alone, validate and reload.
   Set repository variable `HETZNER_VERIFY_HTTPS=true`, rerun the workflow and
   verify www redirects including paths/query strings and HTTP-to-HTTPS.
8. Only after these checks succeed, disable the Pages workflow and record the
   cutover evidence. Keep the prior Pages deployment available for rollback.

Origin verification example (run from the repository root):

```sh
python3 deploy/hetzner/verify.py --revision FULL_COMMIT --origin 5.75.171.94 --http
# After certificates and cutover:
python3 deploy/hetzner/verify.py --revision FULL_COMMIT --origin 5.75.171.94
python3 deploy/hetzner/verify.py --revision FULL_COMMIT
```

## Rollback

Before DNS cutover, remove only the new site snippet and reload Caddy. Public
traffic still uses Pages. After cutover, restore the original four proxied apex
A records (`185.199.108.153` through `185.199.111.153`) via a reviewed DNS preview
and apply; retain `www` as a CNAME. Re-enable the Pages workflow if it was disabled.
Do not remove the GitHub Pages custom-domain configuration during migration.

## Host findings, 2026-10-21

- Server and cron are running. `/` is 85% full; the initial load average was
  about 5.7 on four vCPUs. No cleanup or workload changes were performed.
- `host-monitor.sh` runs every five minutes and logs locally, but the decrypted
  infra environment has **no `HEALTHCHECK_URL_HOST`**. It therefore sends no host
  heartbeat. This is separate from the reported existing backup check.
  The currently deployed script still reads the older infra environment; follow
  the current infrastructure repository's per-consumer delivery procedure when
  activating this receiver rather than editing a server `.env` directly.
- The Healthchecks check named `futurelearninglab`, description
  “futurelearninglab on hetzner health check”, is the **daily backup monitor**.
  Its event log records the up-to-down transition on **2026-08-03 at 04:07
  Europe/Berlin**: NAS restic check reported problems. From August 4 onward it
  reports the NAS repository unreachable / init failed. It still receives daily
  failure pings; on October 21 these also report primary Object Storage failure.
  Adding a host heartbeat cannot resolve this existing backup alarm.
- The latest platform backup log reports unreadable Caddy/Gitea paths, failed
  Object Storage writes and an unreachable/uninitialised NAS backup repository.
  This requires separate repair; the site migration does not change backups.
- Root SSH is refused and `deploy` has no sudo permission. The founder's first
  root run returned exit code 1 with no new account or site paths. No automatic
  retry was attempted. The founder subsequently approved the existing static
  path and restricted key in `deploy`. Setup succeeded, and actual upload/delete
  tests passed. Shell, downloads and a dry-run path escape were refused by rrsync.

References: [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https),
[Caddy error handling](https://caddyserver.com/docs/caddyfile/directives/handle_errors),
[restricted rsync](https://download.samba.org/pub/rsync/rrsync.1).
