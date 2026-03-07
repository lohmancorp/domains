# domains.sh

You no longer have to deal with walls of text when checking domains. This script will check the domains you provide and give you a clean, concise output of the results.

A fast, zero-dependency shell script that checks domain availability via WHOIS and shows **registration & renewal pricing** (based on Moniker.com prices as of 2026-03-07).

Output is **compact by default** — one line per domain. Pass `-e` for full verbose details.

```
❌ - TAKEN: taylorgiddens.com
✅ - taylorgiddens.io - 56.57 €
💰 - Spend: 56.57 €
```

With `-e` (extended):
```
✅ AVAILABLE: taylorgiddens.io
   1st Year: 56.57 €
   Renewal:  59.10 €

❌ TAKEN: taylorgiddens.com
   Registrar: GoDaddy.com, LLC
   Last Update: 2026-03-03T09:26:49Z
   Expiration Date: 2027-01-18T01:33:08Z
   taylorgiddens.com - A - 45.141.116.118

💰 Your potential spend is: 56.57 €
```

---

## Features

- ✅ Instant availability check via `whois`
- 💰 Registration & renewal pricing for 654 TLDs
- 🔎 Registrar, expiry & last-update info for taken domains (extended mode)
- 🌐 DNS A & CNAME record lookup for taken domains (extended mode)
- 📋 `-f` full raw WHOIS output
- 🛡️ TLD validation before sending any requests
- ⚙️ Configurable default TLD list for the `-o` prompt
- ⏱️ Built-in rate limiting to avoid WHOIS server blocks
- 🛑 Hard cap of 20 domains per run

---

## Requirements

| Tool | Install |
|------|---------|
| `whois` | See platform instructions below |
| `bc` | Usually pre-installed (needed for price summing) |
| `dig` | Usually pre-installed (optional, for DNS lookup on taken domains) |
| `bash` 4+ | Pre-installed on Linux; see macOS & Windows notes |

---

## Get the Script

**Option A — git clone (recommended if you have git):**
```bash
git clone https://github.com/lohmancorp/domains.git
cd domains
```

**Option B — direct download:**
```bash
curl -O https://raw.githubusercontent.com/lohmancorp/domains/main/domains.sh
```

Or download manually from: [github.com/lohmancorp/domains](https://github.com/lohmancorp/domains)

---

## Installation

### macOS

```bash
# 1. Get the script — see 'Get the Script' section above

# 2. Install dependencies
brew install whois bash

# 3. Copy to your PATH
sudo cp domains.sh /usr/local/bin/domain
sudo chmod +x /usr/local/bin/domain

# 4. Run from anywhere
domain example.com
```

> **Note:** macOS ships with an older Bash 3. The `brew install bash` step above upgrades it. If you skip this, run with `bash domains.sh` instead of `./domains.sh`.

---

### Linux (Ubuntu / Debian)

```bash
# 1. Get the script — see 'Get the Script' section above

# 2. Install dependencies
sudo apt update && sudo apt install -y whois bc

# 3. Copy to your PATH
sudo cp domains.sh /usr/local/bin/domain
sudo chmod +x /usr/local/bin/domain

# 4. Run from anywhere
domain example.com
```

---

### Linux (Fedora / RHEL / CentOS)

```bash
# 1. Get the script — see 'Get the Script' section above

# 2. Install dependencies
sudo dnf install -y whois bc

# 3. Copy to your PATH
sudo cp domains.sh /usr/local/bin/domain
sudo chmod +x /usr/local/bin/domain

# 4. Run from anywhere
domain example.com
```

---

### Windows (WSL — recommended)

1. [Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install) and open an Ubuntu terminal.
2. Follow the **Linux (Ubuntu / Debian)** steps above inside WSL.

```bash
# Inside WSL
sudo apt update && sudo apt install -y whois bc
sudo cp /path/to/domains.sh /usr/local/bin/domain
sudo chmod +x /usr/local/bin/domain
domain example.com
```

---

### Windows (Git Bash)

Git Bash ships with a minimal Unix environment. `whois` and `bc` are not included by default and must be provided manually — **WSL is recommended instead.**

If you prefer Git Bash:

1. Download a Windows `whois` binary from [Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/whois) and place it somewhere on your `PATH`.
2. `bc` can be installed via [MSYS2](https://www.msys2.org/).
3. Run the script directly (no install step needed):
   ```bash
   bash domains.sh example.com
   ```

---

## Usage

```
domain <domain> [-o] [-e] [-f]
```

| Flag | Description |
|------|-------------|
| *(none)* | Check a single domain — **compact output by default** |
| `-o` | Prompt for TLD options to check (pre-filled with your configured defaults) |
| `-e` | Extended output — full details including registrar, dates & DNS records |
| `-f` | Show full raw WHOIS output (cannot be combined with `-o` or `-e`) |

### Examples

```bash
# Single domain — compact output
domain taylorgiddens.com

# Check multiple TLDs interactively using your default list
domain taylorgiddens.com -o

# Extended output — shows registrar, expiry dates, DNS A/CNAME records
domain taylorgiddens.com -e

# Combine: TLD prompt + extended output
domain taylorgiddens.com -o -e

# Full WHOIS dump for a single domain
domain taylorgiddens.com -f
```

---

## Configuration

Near the top of `domains.sh` there is a clearly marked configuration section:

```bash
# ==============================================================================
# CONFIGURATION
# ==============================================================================
DEFAULT_TLDS=(
    .com
    .ai
    .io
    .co
    .app
    .dev
)
```

These TLDs are **pre-filled** when you use the `-o` flag. Press **Enter** to accept them, or type your own to override. Edit this list to suit your preferred TLDs.

---

## Output Formats

### Compact (default)

One line per domain, no spacing:

```
❌ - TAKEN: taylorgiddens.com
✅ - taylorgiddens.io - 56.57 €
💰 - Spend: 56.57 €
```

### Extended (`-e`)

Full details with spacing between domains, registrar/expiry info, and DNS records for taken domains:

```
✅ AVAILABLE: taylorgiddens.io
   1st Year: 56.57 €
   Renewal:  59.10 €

❌ TAKEN: taylorgiddens.com
   Registrar: GoDaddy.com, LLC
   Last Update: 2026-03-03T09:26:49Z
   Expiration Date: 2027-01-18T01:33:08Z
   taylorgiddens.com - A - 45.141.116.118

💰 Your potential spend is: 56.57 €
```

---

## Rate Limiting

To avoid getting blocked by WHOIS servers, requests are automatically spaced out:

| Domains | Delay between requests |
|---------|----------------------|
| 1 – 5   | 500 ms |
| 6 – 10  | 1,500 ms |
| 11 – 20 | 2,500 ms |
| > 20    | 🛑 Refused — max is 20 |

---

## Pricing Data

Prices are embedded directly in the script (no external API calls) and are sourced from **Moniker.com** pricing as of **2026-03-07**. 654 TLDs are supported. To update prices, edit the `PRICING_DATA` block near the top of `domains.sh`.
