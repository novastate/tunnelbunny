# Submitting to Unraid Community Applications

CA does not take a pull request for new repositories. The template lives in **this**
repo; you ask Squid to add the repo to the feed by **private message on the Unraid
forums**, and CA then scrapes it every couple of hours.

Source: <https://forums.unraid.net/topic/101424-how-to-publish-docker-templates-to-community-applications-on-unraid/>
— *"On a new repository being added, I'll reply to the PM either with questions /
suggestions / fixes required or let you know that it's in there."*

## Before sending

- [ ] Image is public on Docker Hub and pulls anonymously
- [ ] `unraid/tunnelbunny.xml` is on `main` and reachable at its raw URL
- [ ] `icon/tunnelbunny.png` is reachable at its raw URL (256×256, readable at 48px)
- [ ] `WebUI` uses the **container** port (`[PORT:8080]`), not a host port
- [ ] `Support` and `Project` point at real pages
- [ ] Docker Hub description is filled in

## The message

Send to **Squid** at <https://forums.unraid.net/messenger/compose/> — subject
*"New template repository: tunnelbunny"*.

---

Hi Squid,

I'd like to add a new template repository to Community Applications.

**Repository:** https://github.com/novastate/tunnelbunny
**Template:** https://raw.githubusercontent.com/novastate/tunnelbunny/main/unraid/tunnelbunny.xml
**Docker Hub:** https://hub.docker.com/r/deepcrash/tunnelbunny (amd64 + arm64)

Tunnel Bunny is a ~11 MB diagnostics container for VPN'd networks. It answers three
questions from the network it sits on: is traffic actually in the tunnel, is DNS
leaking, and how fast is the link. It has a small web UI and an identical CLI, and
also ships curl, dig, mtr, ping and Ookla's speedtest so it doubles as a shell to
debug from.

The part I think is genuinely useful for Unraid users: you can run it with
`--net=container:<name>` and measure from exactly the position of a suspect
container — say a torrent client behind a VPN sidecar — without touching it.

Verdicts are matched against the user's own VPN provider rather than their ISP, and
with nothing configured it reports the measurement without claiming anything.

Happy to make any changes you'd like to the template.

Thanks,
Henrik

---

## If they ask for changes

The template is the only file that needs editing. CA re-scrapes automatically, so a
push to `main` is enough — no new message needed.
