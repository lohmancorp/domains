# domains

A fast, zero-dependency shell script that checks domain availability via **RDAP** and shows **registration & renewal pricing**.

Output is **compact by default** — one line per domain. Pass `-e` for full verbose details.

```
❌ - TAKEN: taylorgiddens.com
✅ - taylorgiddens.io - 56.57
💰 - Spend: 56.57
```

With `-e` (extended):
```
✅ AVAILABLE: taylorgiddens.io
   1st Year: 56.57
   Renewal:  59.10

❌ TAKEN: taylorgiddens.com
   Registrar: GoDaddy.com, LLC
   Last Update: 2026-03-03T09:26:49Z
   Expiration Date: 2027-01-18T01:33:08Z
   taylorgiddens.com - A - 45.141.116.118

💰 Your potential spend is: 56.57
```

---

## Features

- ✅ Availability check via **RDAP** (modern replacement for WHOIS)
- 💰 Registration & renewal pricing for 654+ TLDs (built-in, no API needed)
- 📂 Load pricing from your own **CSV or TSV file** (supports simple and operation-row formats)
- 🔎 Registrar, expiry & last-update info for taken domains (`-e`)
- 🌐 DNS A & CNAME record lookup for taken domains (`-e`)
- 🛡️ TLD validation before sending any requests
- ⚙️ Per-user config file — each user has their own defaults
- ⏱️ Built-in rate limiting (never exceeds 10 requests per 11 seconds)
- 🛑 Hard cap of 20 domains per run
- 🔧 `--install` — OS-aware installer with tab-completion setup
- 🔄 `--update` — self-update from GitHub
- 🏷️ `--version` — show current version

---

## Requirements

| Tool | Required for | Notes |
|------|-------------|-------|
| `bash` | Everything | 3.2+ (macOS default). No upgrade needed. |
| `curl` | RDAP lookups | Pre-installed on macOS; `apt install curl` on Linux |
| `bc` | Price summing | Usually pre-installed |
| `dig` | DNS records on taken domains | Optional; pre-installed on most systems |
| `awk` | CSV/TSV loading | Pre-installed everywhere |
| `python3` | Registrar/expiry detail (`-e`) | Pre-installed on macOS; needed only for extended RDAP parse |

> No external packages or pip modules required.

---

## Get the Script

**Option A — git clone:**
```bash
git clone https://github.com/lohmancorp/domains.git
cd domains
```

**Option B — direct download:**
```bash
curl -O https://raw.githubusercontent.com/lohmancorp/domains/main/domains.sh
chmod +x domains.sh
```

---

## Installation

Run the built-in installer — it detects your OS, copies the script to the right `bin` directory, installs shell completions, and walks you through first-time setup:

```bash
./domains.sh --install
```

The installer will:
1. Detect your OS (macOS, Linux, WSL, Windows Git Bash)
2. Copy the script to `/usr/local/bin/domains` or `~/.local/bin/domains`
3. Warn if the target directory is not in your `$PATH`
4. Install tab-completion for **zsh** and **bash**
5. Run the interactive setup wizard

After install, restart your terminal and run from anywhere:
```bash
domains example.com
```

### Manual install (if you prefer)

```bash
# macOS / Linux / WSL
sudo cp domains.sh /usr/local/bin/domains
sudo chmod +x /usr/local/bin/domains

# Then run setup
domains --setup
```

---

## Usage

```
domains <domain> [-o] [-e]
domains --install | --setup | --update | --version
```

| Flag | Description |
|------|-------------|
| *(none)* | Check a single domain — compact output |
| `-o` | Prompt for additional TLDs to check (pre-filled with your defaults) |
| `-e` | Extended output — registrar, expiry dates, DNS records |
| `-o -e` | Combine both |
| `--install` | Install to system bin, set up completions, run setup wizard |
| `--setup` | Re-run the setup wizard (change TLD defaults or pricing file) |
| `--update` | Pull the latest version from GitHub |
| `--version` | Show version number and exit |

### Examples

```bash
# Single domain — compact
domains taylorgiddens.com

# Check multiple TLDs interactively
domains taylorgiddens.com -o

# Extended output — registrar, dates, DNS
domains taylorgiddens.com -e

# Combine
domains taylorgiddens.com -o -e

# Update to latest version
domains --update
```

---

## First-Run Setup & Per-User Config

The first time any user runs `domains`, they are offered a two-step setup wizard. This saves a **personal config file** at:

```
~/.config/domains/config
```

This means multiple users on the same machine each have their own defaults. The admin runs `--install` once; every other user gets the wizard on their first run.

Re-run setup any time:
```bash
domains --setup
```

The wizard configures:
1. **Default TLDs** — pre-filled when you use `-o`
2. **Pricing file** — optional path to your own CSV/TSV

---

## Configuration (in-script)

The built-in defaults at the top of `domains.sh` apply when no personal config exists:

```bash
DEFAULT_TLDS=(
    .com
    .ai
    .io
    .co
    .app
    .dev
)
```

---

## External Pricing File

You can load pricing from your own CSV or TSV file instead of (or in addition to) the built-in data. Set it during `--setup` or manually in `~/.config/domains/config`:

```bash
PRICING_FILE="$HOME/Documents/pricing.csv"
```

To revert to built-in pricing, run `--setup` and type `none` at the pricing file prompt.

### Supported file formats

| Format | Extension |
|--------|-----------|
| Comma-separated | `.csv` |
| Tab-delimited | `.tsv` or `.csv` containing tabs |

### Supported column layouts

**Layout A — simple (one row per TLD):**

| TLD | Registration | Renewal |
|-----|-------------|---------|
| com | $12.58 | $13.76 |
| .ai | 101.39 € | 104.47 € |

**Layout B — operation rows (multiple rows per TLD):**

| TLD | Years | Operation | Price | … |
|-----|-------|-----------|-------|---|
| 5g.in | 1 | create | $8.01 | … |
| 5g.in | 1 | renew | $11.45 | … |

The loader auto-detects the layout. `create`/`register` rows become the registration price; `renew`/`renewal` rows become the renewal price. Extra columns and tiers are ignored.

**Column rules:**
- Column 1 — TLD: leading dot optional (`.com` or `com`)
- Column 2/3 — Price: currency symbol optional, any position (`$12.00`, `12.00 €`, `12.00`)
- Header row is always skipped automatically
- **UTF-8 BOM** is stripped automatically — Excel-exported CSV files work as-is

---

## Tab Completion

Installed automatically by `--install`. After restarting your terminal:

```
domains --<TAB>
  --extended   --help   --install   --options   --setup   --update

domains -<TAB>
  -e   -h   -o
```

**zsh** — completion file: `~/.zsh/completions/_domains`  
**bash** — completion file: `~/.bash_completion.d/domains`

---

## Rate Limiting

RDAP requests are automatically spaced to avoid server blocks:

| Domains | Delay between requests |
|---------|----------------------|
| 1 – 6   | 500 ms |
| 7 – 20  | 1,100 ms |
| > 20    | 🛑 Refused — max is 20 |

**Auto-retry on rate limit:** If an RDAP server responds with HTTP `429`, `503`, or a non-JSON body (a common indicator of throttling), the script pauses 5 seconds, informs you, and retries automatically:

```
⏳ Rate limited by RDAP server for example.com. Waiting 5 seconds...
```

---

## Pricing Data

Built-in prices are sourced from **Moniker.com** pricing as of **2026-03-07** and cover 654+ TLDs. They are embedded directly in the script — no external API calls, no internet needed for pricing.

To use your own prices, see [External Pricing File](#external-pricing-file) above.

---

## Self-Update

```bash
domains --update
```

Downloads the latest `domains.sh` from GitHub, validates syntax, backs up your current script, and optionally updates the installed copy in your `$PATH`.
