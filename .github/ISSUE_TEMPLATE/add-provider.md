---
name: Add a VPN provider
about: Get your provider into the built-in list
title: 'Add provider: '
labels: provider
---

Only providers verified against the ASN registry are listed, because a wrong pattern
reports a leak that is not there. To add yours I need one line of real measurement.

**Run this while connected through your VPN:**

```sh
docker run --rm deepcrash/tunnelbunny vpn
```

**Paste the `belongs to` line:**

```
belongs to   
```

If you have exits in several countries, a line from two or three of them helps —
some providers register more than one company. Mullvad's network is `31173 Services
AB`, NordVPN appears as both `Tefincom` and `PacketHub`, so one sample is not always
the whole picture.

**Provider name:** 

That is all. No account details, no config.
