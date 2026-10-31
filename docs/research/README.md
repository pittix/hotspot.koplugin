---
topic: index
last_reviewed: 2026-10-31
---

# Research: porting hotspot.koplugin to other e-readers

This folder holds the **machine-checkable** research behind
[`../other-ereaders-report.md`](../other-ereaders-report.md), the human-readable report.
Future agents should use it to **re-verify** claims, mark them stale, and **extend** them.

## Files

| File | Content |
|---|---|
| [`sources.md`](sources.md) | Registry of every source (ID → URL, type, what it supports, verification status) |
| [`plugin-baseline.md`](plugin-baseline.md) | What the plugin needs from a device, facts about the bundled binaries (with reproduce commands) |
| [`kindle.md`](kindle.md) | Kindle claims (MediaTek, Broadcom, Atheros families) + porting sketch + on-device checks |
| [`pocketbook.md`](pocketbook.md) | PocketBook claims (B288, B300, A13, i.MX6) + porting sketch + on-device checks |
| [`remarkable.md`](remarkable.md) | reMarkable claims |
| [`other-platforms.md`](other-platforms.md) | Cervantes, Bookeen, Sony PRS-T, Tolino; Android (out of scope) |
| [`wifi-chips.md`](wifi-chips.md) | Chip families → driver → AP support → hostapd backend; Atheros AR6003 and Broadcom BCM4343W prior art outside e-readers |
| [`open-questions.md`](open-questions.md) | Things only a device can answer, with IDs and the exact commands |

## Conventions (keep these when extending)

**Claim block.** Every claim has a stable ID `<AREA>-C<nn>`, where AREA is `BASE`, `KIN`, `PB`, `RM`, `OTH`, `ATH`, `BRCM` or `CHIP`. Each claim uses this shape:

```
### KIN-C01: short title
- claim: one or two sentences, factual
- confidence: high | medium | low
- status: verified | agent | inference | snippet | contradicted | stale
- sources: S-XXX-nn, S-YYY-nn          (IDs from sources.md)
- recheck: how to re-verify (URL + what string to look for, or device command)
- notes: optional (implications, caveats)
```

**Status vocabulary:**
- `verified`: the main research agent fetched the primary source itself on `last_reviewed` and saw the content.
- `agent`: reported by a research subagent with a citation, not re-fetched by the main agent.
- `inference`: reasoned from other claims; no direct source.
- `snippet`: only seen in search-engine snippets, or the page was blocked (403/timeout).
- `contradicted`: another source disagrees (see notes).
- `stale`: re-checked later and no longer true (keep the block, add a dated note).

**Never delete a claim.** Mark it `stale` or `contradicted` with a dated note, so history stays scrapeable.
**Open questions** use IDs `Q-<AREA>-<nn>` in `open-questions.md`.

## Project decisions that constrain the research

| ID | Decision | Date | Origin |
|---|---|---|---|
| D1 | The bundled `hostapd`/`udhcpd` are **not** a constraint. They can be rebuilt (musl, older-kernel glibc, other driver backends like `rtl871xdrv`, other archs). Binary mismatches count as rebuild work, not blockers | 2026-10-31 | user |
| D2 | **Android readers are out of scope.** System tethering already does it. Project motto: *avoid reinventing the wheel*. Check for a native OS feature before proposing a target or feature | 2026-10-31 | user |
| D3 | **1–2 clients** at a time is the target. The hotspot is meant to pair with the user's `filesync` tool (`../../../filesync-eink`, sibling folder of this plugin). Many-client support is out of scope; issues with more clients get documented in `README.md` | 2026-10-31 | user |
| D4 | Research focuses on Wi-Fi hardware/driver/firmware/hostapd engineering. **Jailbreak/root methods are recorded only as "exists / doesn't exist"**, not as procedures | 2026-10-31 | research practice (see history) |

## Research history and caveats

- **2026-10-31, round 1**: three parallel research subagents (Kindle, PocketBook, other platforms) used WebSearch/WebFetch only. The main agent inspected the plugin's binaries locally and spot-checked key primary sources.
  - The **PocketBook subagent was cut off by an API safeguard** partway through its report, probably triggered by content about rooting. Its per-model table survived; the rest was filled in by the main agent from PocketBook's published kernels and KOReader's code. Unchecked PocketBook claims are marked `agent` with medium/low confidence.
  - Correction applied: the Kindle subagent wrote "static glibc 2.10". **2.10 is the hostapd version.** The binary links glibc 2.36-era (Debian bookworm toolchain), so it needs kernel ≥ 3.2.
- **2026-10-31, round 2**: one subagent researched Atheros AR6003 / Broadcom BCM4343W AP prior art outside e-readers (OpenWrt, Raspberry Pi, Android, i.MX boards). The user clarified D3 mid-run.
  - Correction applied: the subagent said the PW3 mainline-ath6kl thread showed "working Wi-Fi". Verified text: Wi-Fi associated and got an IP but "didn't seem to work well". The board-data fix was expected to work but was never reported as tested.
- Nothing in this folder has been tested on a device yet.

## Status and next steps (as of 2026-10-31)

- The report and this research are committed on branch `other-models`. **Awaiting the user's review comments** on the report before researching other models further.
- Suggested order (from the report):
  1. Kindle MTK (PW5 class)
  2. PocketBook B288 (rooted)
  3. reMarkable 1/2
  4. Broadcom Kindles (Basic 8th gen first: driver verified)
  5. Atheros Kindles (needs ath6kl module build + musl hostapd)
- Re-verification priority for future agents:
  - fast-moving facts: Kindle jailbreak coverage, KOReader device lists
  - anything with status `agent` or `snippet` that a verdict depends on: KIN-C09, KIN-C10, KIN-C13, PB-C02, PB-C05, BRCM-C06
