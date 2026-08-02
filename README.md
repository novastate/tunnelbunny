# Tunnel Bunny

A small diagnostics container for VPN'd networks. Drop it onto a network and it
answers three questions: **is my traffic in the tunnel, is DNS leaking, and how fast
is it?**

Alpine, ~41 MB. One page with buttons, and a CLI that does the same thing.

## Run it

```sh
docker run -d -p 8080:8080 -e VPN_PROVIDER='Mullvad|31173 Services' deepcrash/tunnelbunny
```

Or build it yourself:

```sh
docker build -t tunnelbunny:1.3 .

# web UI on :8080
docker run -d -p 8080:8080 -e VPN_PROVIDER='Mullvad|31173 Services' tunnelbunny:1.3

# or one-shot in the terminal
docker run --rm -e VPN_PROVIDER='Mullvad|31173 Services' tunnelbunny:1.3 vpn
```

`check [vpn|dns|speed|all]` — with no argument the container starts the web UI.

Also inside: `curl`, `dig`, `mtr`, `ping` and Ookla's `speedtest`, so it doubles as a
shell to poke around from:

```sh
docker run --rm -it --entrypoint sh tunnelbunny:1.3
```

### Measure from a different network than the host's

This is the point of it.

```sh
# put it directly on a VLAN
docker run --rm --network br0.9 tunnelbunny:1.3

# or borrow an existing container's network namespace - measures exactly its view
docker run --rm --network container:qbittorrent tunnelbunny:1.3
```

The second one is what you want when debugging: you measure from *precisely* the
position a suspect container has, without touching it.

## Setting your VPN provider

`VPN_PROVIDER` is a **regex** matched against the ASN/org field of the exit IP.
Set it from the web UI (there is a list) or via the environment variable.

**Why a pattern and not a name:** several providers have more than one registered
company, and the registered name is rarely the brand.

| Provider | Name in the registry | Pattern |
|---|---|---|
| Mullvad | `31173 Services AB`, `Mullvad VPN AB` | `31173 Services\|Mullvad` |
| NordVPN | `Tefincom S.A.`, `PacketHub S.A.` | `Tefincom\|PacketHub\|NordVPN` |
| Proton VPN | `Proton AG`, `Proton Technologies AG` | `Proton` |
| OVPN | `Obehosting AB` | `Obehosting\|OVPN` |
| Surfshark | `Surfshark Ltd.` | `Surfshark` |

> A free-text field where you type "Mullvad" would report a **leak while everything
> was fine** — Mullvad's network is registered as `31173 Services AB`. Nobody guesses
> that, which is why the list exists.

**The safest route is the measurement itself.** Run the VPN check with nothing set
and a button appears: *Use "AS39351 31173 Services AB" as VPN provider*. That takes the
string from the registry rather than from our list, so it can never go stale.

### Split routing is detected, not guessed at

The VPN check asks **two** echo services on different domains. If they disagree, only
some destinations are tunnelled and no single verdict describes the network — so it
reports both paths instead of a verdict.

> 🐛 **This was found by testing on a second network, and it mattered.** The first
> version asked `ipinfo.io` alone and reported a clean **OK** for a host that was not
> in the tunnel at all. Cause: `ipinfo.io` was in that network's VPN domain list —
> and leak-test sites are exactly the domains people route through their VPN.
> Measured from one host, one moment: `ipinfo.io` answered from the VPN exit while
> `icanhazip.com`, `ifconfig.co` and `api.ipify.org` all answered from the ISP.
>
> A false OK is the worst thing a leak test can produce. One endpoint cannot tell you
> a network is protected — it can only tell you about the path to that endpoint.

**The DNS check has the same ceiling, and says so.** It can only ever measure the
domain it uses (`bash.ws`), and that domain is VPN-routed on plenty of setups — the
same host that produced the false VPN OK also reported *"all resolvers belong to your
VPN provider — no leak"* while its general DNS went elsewhere. When split routing is
detected the DNS verdict is withheld too, and the result is labelled as covering
`bash.ws` only. A tool that cannot see something should say so rather than round it
to good news.

**With no provider set, no verdict is given.** The measurement is shown and nothing
is claimed. You cannot tell right from wrong without knowing where the traffic is
*supposed* to exit — and comparing against your own ISP instead only ever answers for
one network.

### Persisting the setting

A value saved from the web UI lands in `/config/provider` and takes precedence over
`VPN_PROVIDER`. Mount `/config` or it disappears when the container is re-created.

## Unraid

```sh
cp unraid/my-tunnelbunny.xml /boot/config/plugins/dockerMan/templates-user/
```

```sh
docker run -d --name tunnelbunny --network my-vpn-net --ip 10.9.0.12 --restart unless-stopped \
  -e VPN_PROVIDER='Mullvad|31173 Services' \
  -v /mnt/user/appdata/tunnelbunny:/config \
  --label net.unraid.docker.webui='http://[IP]:[PORT:8080]/' \
  --label net.unraid.docker.icon='https://raw.githubusercontent.com/selfhst/icons/main/png/speedtest-tracker.png' \
  tunnelbunny:1.3
```

Two things Unraid does that are not obvious:

- **A stopped container without a template is not listed at all.** Found by comparing
  with a container that did show: it had neither a template nor Unraid labels — the
  only difference was `status=running`. The web server solves this properly, since it
  keeps the container up *and* gives you an interface.
- **The WebUI link comes from the container's `net.unraid.docker.webui` label, not
  from the template.** Without the label there is no WebUI entry in the menu.

`net.unraid.docker.managed=dockerman` is deliberately **not** set: it enables the
Update button, which would try to pull an image that only exists locally.

> ⚠️ If you use a macvlan network, check `docker network inspect` for free addresses
> first. **macvlan does not warn about address collisions — it just stops working.**

## The interface

Three cards — VPN, DNS leak, Speed — each with its own state: *empty · measuring ·
OK · failed*. **Run all** runs them one at a time so the cards fill in sequence
instead of everything landing at once after 30 seconds.

The rabbit is the logo and **runs while anything is being measured**. The measuring
card gets a sweeping highlight and a pulsing LED. Speed **counts up** to its final
value. DNS resolvers fade in one by one; any that falls outside your provider turns
red. Raw `check` output stays available in a collapsible section — nothing is hidden,
and if parsing fails the card shows the raw text instead.

The page **parses `check`'s text output** rather than having the script emit JSON.
That keeps `check` useful as a standalone CLI tool.

## Traps that cost time building this

| Trap | What happened |
|---|---|
| `\|` inside a `case` bracket expression | taken as the case **alternation separator** before the bracket is parsed. The input whitelist was silently disabled the moment `\|` was allowed for provider patterns. Use `grep` for whitelists |
| Verdict against your own ISP | worked on exactly one network. The right question is *"does traffic exit at my VPN provider?"* — which also catches traffic leaving via a **third** party |
| `ARG TARGETARCH` | did not take effect with `docker build --platform linux/arm64`; the arm64 image got an **x86_64 binary** without complaint. Use `uname -m` |
| `busybox httpd` | Alpine's busybox has no `httpd` applet. Needs the `busybox-extras` package |
| Ookla 1.2.1 | does not exist — 403. Only **1.2.0** |
| `speed.cloudflare.com` | **403** above 50 MB, **429** when run repeatedly |
| `curl -w '%{speed_download}'` without `\n` | values are glued into one number; `awk` summed nonsense and reported astronomical speeds |
| Single-stream measurement | 666 Mbps with one stream vs 991 with eight, same link, same moment |
| Measuring down against one host and up against another | looked like a directional asymmetry in the tunnel. It was two different **paths** |
| Asking a single echo service | reported a clean OK for a network that was not tunnelled, because the test domain itself was VPN-routed. Two services on different domains now, and disagreement is reported as split routing |
| `tr -d ' '` in the DNS loop | stripped the spaces out of the ASN name: `AS42675 OBEHosting AB` became `AS42675OBEHostingAB` |

## Security notes

The provider value is the only input that reaches a shell command. It is:

- sent **base64-encoded** from the page, so it never has to be URL-decoded in shell
- whitelisted against `^[A-Za-z0-9 ._|-]*$` **with grep**, not `case` (see above)
- truncated to 64 characters
- passed to `grep -iE --`, so it cannot be read as a flag — never `eval`, never a shell

Verified rejected: `a;id`, `a$(id)`, `` a`id` ``, `a&b`, `a>b`, `a/b`, `../etc/passwd`.

## Releasing

`.github/workflows/docker.yml` builds `linux/amd64` + `linux/arm64` and pushes on a
version tag. One repository secret is needed: `DOCKERHUB_TOKEN` (an access token, not your
password). The username is written out in the workflow - it is not a secret.

```sh
git tag v1.1.0 && git push origin v1.1.0
```

By hand, without CI:

```sh
docker buildx build --platform linux/amd64,linux/arm64 \
  -t deepcrash/tunnelbunny:1.3 -t deepcrash/tunnelbunny:latest --push .
```

`--push` is required — buildx cannot put a multi-arch image in the local image store.

> QEMU is what makes `uname -m` report the **target** architecture during the build.
> That is how the right speedtest binary gets fetched. `ARG TARGETARCH` did not work
> and silently produced an x86_64 binary inside the arm64 image.

## License

MIT — see [LICENSE](LICENSE).
