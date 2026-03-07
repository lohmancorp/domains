# domains.sh

A fast, zero-dependency shell script that checks domain availability via WHOIS and shows **registration & renewal pricing** (based on Moniker.com prices as of 2026-03-07).

```
✅ AVAILABLE: taylorgiddens.io
   1st Year: 56.57 €
   Renewal:  59.10 €

❌ TAKEN: taylorgiddens.com
   Registrar: GoDaddy.com, LLC
   Last Update: 2026-03-03T09:26:49Z
   Expiration Date: 2027-01-18T01:33:08Z

💰 Your potential spend is: 56.57 €
```

---

## Features

- ✅ Instant availability check via `whois`
- 💰 Registration & renewal pricing for 654 TLDs
- 🔎 Registrar, expiry & last-update info for taken domains
- 🔁 `-e` extend mode — check multiple TLDs interactively
- 📋 `-f` full raw WHOIS output
- 🛡️ TLD validation before sending any requests
- ⏱️ Built-in rate limiting to avoid WHOIS server blocks
- 🛑 Hard cap of 20 domains per run

---

## Requirements

| Tool | Install |
|------|---------|
| `whois` | See platform instructions below |
| `bc` | Usually pre-installed (needed for price summing) |
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
#    (git clone or curl download, then cd into the directory)

# 2. Install dependencies
brew install whois bash

# 3. Copy to your PATH
sudo cp domains.sh /usr/local/bin/domains
sudo chmod +x /usr/local/bin/domains

# 4. Run from anywhere
domains example.com
```

> **Note:** macOS ships with an older Bash 3. The `brew install bash` step above upgrades it. If you skip this, run with `bash domains.sh` instead of `./domains.sh`.

---

### Linux (Ubuntu / Debian)

```bash
# 1. Get the script — see 'Get the Script' section above

# 2. Install dependencies
sudo apt update && sudo apt install -y whois bc

# 3. Copy to your PATH
sudo cp domains.sh /usr/local/bin/domains
sudo chmod +x /usr/local/bin/domains

# 4. Run from anywhere
domains example.com
```

---

### Linux (Fedora / RHEL / CentOS)

```bash
# 1. Get the script — see 'Get the Script' section above

# 2. Install dependencies
sudo dnf install -y whois bc

# 3. Copy to your PATH
sudo cp domains.sh /usr/local/bin/domains
sudo chmod +x /usr/local/bin/domains

# 4. Run from anywhere
domains example.com
```

---

### Windows (WSL — recommended)

1. [Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install) and open an Ubuntu terminal.
2. Follow the **Linux (Ubuntu / Debian)** steps above inside WSL.

```bash
# Inside WSL
sudo apt update && sudo apt install -y whois bc
sudo cp /path/to/domains.sh /usr/local/bin/domains
sudo chmod +x /usr/local/bin/domains
domains example.com
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
domains <domain> [-e] [-f]
```

| Flag | Description |
|------|-------------|
| *(none)* | Check a single domain |
| `-e` | Prompt for extra TLDs to check against the same base name |
| `-f` | Show full raw WHOIS output (cannot be combined with `-e`) |

### Examples

```bash
# Single domain
domains taylorgiddens.com

# Check multiple TLDs interactively
domains taylorgiddens.com -e
# → Enter additional TLDs: net org io app

# Full WHOIS dump
domains taylorgiddens.com -f
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
