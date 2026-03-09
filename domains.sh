#!/usr/bin/env bash
# domains — Check domain availability with pricing info and provides registration info if a domain is taken.
# Usage: ./domains.sh <domain> [-o] [-e]

# ══════════════════════════════════════════════════════════════════════════════
# ── CONFIGURATION ────────────────────────────────────────────────────────────
# Default TLDs pre-filled when using the -e (extend) option.
# Edit here to change your default domains to search for.
# Add or remove entries to suit your needs — one TLD per line.
# Ensure you keep the same formating, tabs, etc.
# ══════════════════════════════════════════════════════════════════════════════
DEFAULT_TLDS=(
    .com
    .ai
    .io
    .co
    .app
    .dev
)

# ── Personal config file ──────────────────────────────────────────────────────
# Stores per-user settings: DEFAULT_TLDS, PRICING_FILE, SETUP_DONE.
# Created automatically by --install or on first run.
CONFIG_FILE="${DOMAINS_CONFIG_FILE:-$HOME/.config/domains/config}"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# ── External pricing file (optional) ─────────────────────────────────────────
# Uncomment PRICING_FILE and set the path to load pricing from an external file
# instead of the built-in data below. The file must have 3 columns in this order:
#
#   Column 1 — TLD / domain extension
#     The name does not matter, only the column order.
#     May include or omit the leading dot:  .com  or  com
#
#   Column 2 — Registration price
#     Currency symbol is optional and can appear anywhere:
#     $12.00  |  $ 12.00  |  12.00 $  |  12.00$  |  12.00
#     Any non-numeric character (except . and ,) is stripped automatically.
#
#   Column 3 — Renewal price  (same format rules as column 2)
#
# The first row is always treated as a header and is skipped automatically.
# The file can use two layouts:
#
#   Layout A — Simple (one row per TLD):
#     TLD, Registration price, Renewal price
#
#   Layout B — Operation rows (multiple rows per TLD):
#     TLD, [optional: Years], Operation, Price, ...
#     Where Operation values include:  create / register  → registration price
#                                      renew / renewal    → renewal price
#     Extra columns (tiers, promo prices, etc.) are ignored.
#
# Supported file formats:
#   • Comma-separated CSV  (.csv)
#   • Tab-delimited        (.tsv or .csv containing tabs)
#
# Default paths per OS (uncomment ONE line and adjust as needed):
#   macOS:   # PRICING_FILE="$HOME/Documents/pricing.csv"
#   Linux:   # PRICING_FILE="$HOME/pricing.csv"
#   Windows: # PRICING_FILE="/mnt/c/Users/$USER/Documents/pricing.csv"
#
# To enable: uncomment and set the path:
# PRICING_FILE=""

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ══════════════════════════════════════════════════════════════════════════════
# ── SETUP HELPERS ────────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

# ── Detect operating system ───────────────────────────────────────────────────
detect_os() {
    case "$(uname -s 2>/dev/null)" in
        Darwin)  echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}


# ── Interactive setup wizard ──────────────────────────────────────────────────
run_setup() {
    mkdir -p "$(dirname "$CONFIG_FILE")"

    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   domains.sh — Setup Wizard${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo ""

    # ── Step 1: Default TLDs ──────────────────────────────────────────────
    echo -e "${YELLOW}Step 1/2 — Default TLDs${NC}"
    echo -e "These TLDs are pre-filled when you use the ${GREEN}-o${NC} option."
    echo ""
    local cur_tlds; cur_tlds=$(printf "%s " "${DEFAULT_TLDS[@]}")
    echo -e "Current defaults: ${GREEN}${cur_tlds% }${NC}"
    echo -e "Enter TLDs (space/comma separated), or press Enter to keep current:"
    echo -en "${YELLOW}TLDs: ${NC}"
    read -r _tld_input

    local new_tlds=()
    if [[ -z "${_tld_input// /}" ]]; then
        new_tlds=("${DEFAULT_TLDS[@]}")
    else
        _tld_input="${_tld_input//,/ }"
        for _t in $_tld_input; do
            _t="${_t#.}"
            [[ -n "$_t" ]] && new_tlds+=(".${_t}")
        done
        [[ ${#new_tlds[@]} -eq 0 ]] && new_tlds=("${DEFAULT_TLDS[@]}")
    fi

    # ── Step 2: Pricing file ──────────────────────────────────────────────
    echo ""
    echo -e "${YELLOW}Step 2/2 — Pricing File (optional)${NC}"
    echo -e "Load pricing from a CSV or TSV file instead of built-in data."
    echo ""

    # Show current state so the user knows what is active
    if [[ -n "${PRICING_FILE:-}" ]]; then
        echo -e "   Currently using: ${GREEN}${PRICING_FILE}${NC}"
        echo -e "   Enter a new path, type ${YELLOW}none${NC} to revert to built-in pricing, or press Enter to keep current."
    else
        echo -e "   Currently using: ${GREEN}built-in pricing data${NC}"
        echo -e "   Enter a file path to use external pricing, or press Enter to keep built-in."
    fi
    echo -en "${YELLOW}Path to pricing file: ${NC}"
    read -r _pricing_input
    _pricing_input="${_pricing_input# }"
    _pricing_input="${_pricing_input% }"
    case "$_pricing_input" in
        "~")   _pricing_input="$HOME" ;;
        "~/"*) _pricing_input="$HOME/${_pricing_input:2}" ;;
    esac

    local pricing_line='# PRICING_FILE=""'

    local _pricmp; _pricmp=$(echo "$_pricing_input" | tr '[:upper:]' '[:lower:]')
    if [[ "$_pricmp" == "none" ]]; then
        # Explicit reset to built-in
        echo -e "   ${GREEN}✅ Pricing file cleared — built-in data will be used.${NC}"
        pricing_line='# PRICING_FILE=""'

    elif [[ -z "$_pricing_input" ]]; then
        # Keep existing setting — validate if there is one
        if [[ -n "${PRICING_FILE:-}" ]]; then
            pricing_line="PRICING_FILE=\"${PRICING_FILE}\""
            if [[ -f "${PRICING_FILE}" ]]; then
                echo -e "   Validating current file structure..."
                local _kpext; _kpext="$(echo "${PRICING_FILE##*.}" | tr '[:upper:]' '[:lower:]')"
                local _kfirst _kdelim=',' _kcount
                case "$_kpext" in
                    csv|tsv)
                        _kfirst=$(tail -n +2 "${PRICING_FILE}" | head -1)
                        [[ "$_kfirst" == *$'\t'* ]] && _kdelim=$'\t'
                        _kcount=$(echo "$_kfirst" | awk -F"$_kdelim" '{print NF}')
                        if (( _kcount < 3 )); then
                            echo -e "   ${RED}❗ Warning: current file may be invalid — only ${_kcount} column(s) found.${NC}"
                            echo -e "   Expected columns: ${YELLOW}TLD | Registration price | Renewal price${NC}"
                        else
                            echo -e "   ${GREEN}✅ File structure looks good.${NC}"
                        fi ;;
                esac
            fi
        fi

    else
        # New file path provided — validate it
        case "$_pricing_input" in
            "~")   _pricing_input="$HOME" ;;
            "~/"*) _pricing_input="$HOME/${_pricing_input:2}" ;;
        esac
        local _pext; _pext="$(echo "${_pricing_input##*.}" | tr '[:upper:]' '[:lower:]')"

        if [[ ! -f "$_pricing_input" ]]; then
            echo -e "${YELLOW}⚠️  File not found — path saved. Correct it later if needed.${NC}"
        else
            # Validate column structure
            echo -e "   Validating file structure..."
            local _valid=true _reason=""
            case "$_pext" in
                csv|tsv)
                    local _first_data _delim=','
                    # Skip leading blank/group-header rows to get first real data row
                    _first_data=$(grep -v '^[[:space:]]*,' "$_pricing_input" | awk 'NR>1{print;exit}')
                    [[ "$_first_data" == *$'\t'* ]] && _delim=$'\t'
                    local _col_count
                    _col_count=$(echo "$_first_data" | awk -F"$_delim" '{print NF}')
                    if (( _col_count < 2 )); then
                        _valid=false
                        _reason="Only ${_col_count} column(s) found — need at least 2."
                    else
                        # Detect Layout B (operation-row format) by scanning cols 2-4
                        local _op_col=0 _ci _oval
                        for _ci in 2 3 4; do
                            _oval=$(echo "$_first_data" | awk -F"$_delim" -v c="$_ci" '{print $c}' | tr '[:upper:]' '[:lower:]' | tr -d ' ')
                            case "$_oval" in
                                create|register|registration|renew|renewal|update|transfer|restore|trade)
                                    _op_col=$_ci; break ;;
                            esac
                        done

                        if [[ $_op_col -gt 0 ]]; then
                            # Layout B — verify a numeric price column exists after op col
                            local _pcol=$(( _op_col + 1 ))
                            local _price_val
                            _price_val=$(echo "$_first_data" | awk -F"$_delim" -v c="$_pcol" '{print $c}')
                            if [[ "$_price_val" =~ [0-9] ]]; then
                                echo -e "   ${GREEN}ℹ️  Detected Layout B (operation-row format):${NC} TLD | ... | Operation | Price"
                                # also check we can find at least one create and one renew row
                                local _has_create _has_renew
                                _has_create=$(awk -F"$_delim" -v c="$_op_col" 'NR>1{v=tolower($c); gsub(/ /,"",v); if(v=="create"||v=="register"||v=="registration") {print "yes"; exit}}' "$_pricing_input")
                                _has_renew=$(awk  -F"$_delim" -v c="$_op_col" 'NR>1{v=tolower($c); gsub(/ /,"",v); if(v=="renew"||v=="renewal") {print "yes"; exit}}' "$_pricing_input")
                                [[ -z "$_has_create" ]] && echo -e "   ${YELLOW}⚠️  No 'create' rows found — registration prices will be empty.${NC}"
                                [[ -z "$_has_renew"  ]] && echo -e "   ${YELLOW}⚠️  No 'renew' rows found — renewal prices will be empty.${NC}"
                            else
                                _valid=false
                                _reason="Layout B detected but price column (col ${_pcol}) doesn't appear numeric."
                            fi
                        else
                            # Layout A — cols 1=TLD, 2=reg price, 3=renew price
                            local _c1 _c2 _c3
                            IFS="$_delim" read -r _c1 _c2 _c3 _ <<< "$_first_data"
                            _c1="${_c1// /}"; _c2="${_c2// /}"; _c3="${_c3// /}"
                            echo -e "   ${GREEN}ℹ️  Detected Layout A (simple 3-column format):${NC} TLD | Registration | Renewal"
                            if [[ -z "$_c1" ]]; then
                                _valid=false; _reason="Column 1 (TLD) appears empty."
                            elif [[ ! "$_c2" =~ [0-9] ]] && [[ -n "$_c2" ]]; then
                                _valid=false; _reason="Column 2 (Registration) doesn't appear to contain a price."
                            elif [[ ! "$_c3" =~ [0-9] ]] && [[ -n "$_c3" ]]; then
                                _valid=false; _reason="Column 3 (Renewal) doesn't appear to contain a price."
                            fi
                        fi
                    fi ;;
                xlsx|xls)
                    echo -e "   ${YELLOW}⚠️  XLS/XLSX is no longer supported. Please convert to CSV or TSV.${NC}"
                    _valid=false; _reason="Unsupported file format. Use .csv or .tsv." ;;
            esac

            if [[ "$_valid" == true ]]; then
                echo -e "   ${GREEN}✅ File structure looks good.${NC}"
            else
                echo -e "   ${RED}❗ Validation failed: ${_reason}${NC}"
                echo -e "   Expected columns: ${YELLOW}TLD | Registration price | Renewal price${NC}"
                echo -en "   Save path anyway? [y/N]: "
                read -r _force_ans
                [[ ! "$_force_ans" =~ ^[Yy]$ ]] && {
                    echo -e "   ${YELLOW}Pricing file not saved. Using previous setting.${NC}"
                    if [[ -n "${PRICING_FILE:-}" ]]; then
                        pricing_line="PRICING_FILE=\"${PRICING_FILE}\""
                    fi
                    _pricing_input=""
                }
            fi
        fi

        if [[ -n "$_pricing_input" ]]; then
                pricing_line="PRICING_FILE=\"${_pricing_input}\""
        fi
    fi

    # ── Write config ──────────────────────────────────────────────────────
    {
        echo "# domains.sh personal configuration"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "SETUP_DONE=true"
        echo ""
        echo "DEFAULT_TLDS=("
        for _t in "${new_tlds[@]}"; do echo "    $_t"; done
        echo ")"
        echo ""
        echo "$pricing_line"
    } > "$CONFIG_FILE"

    source "$CONFIG_FILE"

    echo ""
    echo -e "${GREEN}✅ Setup complete!${NC} Config saved to: ${YELLOW}${CONFIG_FILE}${NC}"
    echo -e "   Re-run anytime: ${GREEN}$(basename "$0") --setup${NC}"
    echo ""
}

# ── Install script to system / user bin ───────────────────────────────────────
do_install() {
    local os; os=$(detect_os)
    local script_src
    script_src="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"
    local install_name="domains"

    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   domains.sh — Installer${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "   OS detected: ${YELLOW}${os}${NC}"
    echo ""

    # Candidate directories, ordered by preference
    local candidates=()
    case "$os" in
        macos|linux|wsl) candidates=("/usr/local/bin" "$HOME/.local/bin" "$HOME/bin") ;;
        windows)         candidates=("$HOME/bin" "/usr/local/bin") ;;
        *)               candidates=("$HOME/.local/bin" "$HOME/bin") ;;
    esac

    # Find first writable or creatable directory
    local target_dir=""
    for _d in "${candidates[@]}"; do
        if [[ -d "$_d" && -w "$_d" ]]; then
            target_dir="$_d"; break
        elif [[ ! -d "$_d" ]] && mkdir -p "$_d" 2>/dev/null; then
            target_dir="$_d"; break
        fi
    done

    # Fall back: offer sudo for /usr/local/bin
    if [[ -z "$target_dir" && -d "/usr/local/bin" ]]; then
        echo -e "   ${YELLOW}/usr/local/bin${NC} requires elevated access."
        echo -en "   Install there using sudo? [Y/n]: "
        read -r _sudo_ans
        if [[ ! "$_sudo_ans" =~ ^[Nn]$ ]]; then
            target_dir="/usr/local/bin"
        else
            target_dir="$HOME/.local/bin"
            mkdir -p "$target_dir"
        fi
    fi

    [[ -z "$target_dir" ]] && { target_dir="$HOME/.local/bin"; mkdir -p "$target_dir"; }

    local target="${target_dir}/${install_name}"
    echo -e "   Installing ${GREEN}${install_name}${NC} → ${YELLOW}${target}${NC}"

    local _copy_ok=0
    if [[ "$target_dir" == "/usr/local/bin" && ! -w "$target_dir" ]]; then
        sudo cp "$script_src" "$target" && sudo chmod +x "$target" && _copy_ok=1
    else
        cp "$script_src" "$target" && chmod +x "$target" && _copy_ok=1
    fi

    if [[ $_copy_ok -eq 1 ]]; then
        echo -e "   ${GREEN}✅ Installed successfully.${NC}"
        if [[ ":$PATH:" != *":${target_dir}:"* ]]; then
            echo ""
            echo -e "   ${YELLOW}⚠️  ${target_dir} is not in your \$PATH.${NC}"
            echo -e "   Add this to your shell profile (~/.zshrc, ~/.bashrc, etc.):"
            echo -e "   ${GREEN}export PATH=\"\$PATH:${target_dir}\"${NC}"
        fi
    else
        echo -e "   ${RED}❗ Installation failed.${NC}"
        exit 1
    fi

    # ── Install shell completions ─────────────────────────────────────────
    install_completions "$install_name"

    run_setup
    exit 0
}

# ── Install tab-completion scripts for zsh and bash ───────────────────────────
install_completions() {
    local cmd="${1:-domains}"
    echo ""
    echo -e "   ${YELLOW}Installing shell completions...${NC}"

    # ── zsh ───────────────────────────────────────────────────────────────
    local zsh_comp_dir="$HOME/.zsh/completions"
    mkdir -p "$zsh_comp_dir"
    cat > "${zsh_comp_dir}/_${cmd}" << 'ZSHCOMP'
#compdef domains

_domains() {
    _arguments -s \
        '(- *)'{-h,--help}'[Show help and exit]' \
        '(-e --extended)'{-e,--extended}'[Extended output with full details]' \
        '(-o --options)'{-o,--options}'[Prompt to choose TLDs to check]' \
        '--install[Install to system bin and run setup wizard]' \
        '--setup[Re-run the setup wizard]' \
        '--update[Pull the latest version from GitHub]' \
        '1:domain name:()'
}

_domains "$@"
ZSHCOMP

    # Add ~/.zsh/completions to fpath if not already there
    local zshrc="$HOME/.zshrc"
    local fpath_line='fpath=(~/.zsh/completions $fpath)'
    local compinit_line='autoload -Uz compinit && compinit'
    if [[ -f "$zshrc" ]]; then
        if ! grep -qF "$fpath_line" "$zshrc" 2>/dev/null; then
            {   echo ""
                echo "# domains shell completion"
                echo "$fpath_line"
                echo "$compinit_line"
            } >> "$zshrc"
            echo -e "   ${GREEN}✅ zsh:${NC} completion installed → ${zsh_comp_dir}/_${cmd}"
            echo -e "      Added fpath entry to ${YELLOW}~/.zshrc${NC}"
        else
            echo -e "   ${GREEN}✅ zsh:${NC} completion updated → ${zsh_comp_dir}/_${cmd}"
        fi
    else
        echo -e "   ${GREEN}✅ zsh:${NC} completion file written → ${zsh_comp_dir}/_${cmd}"
        echo -e "      ${YELLOW}Add to ~/.zshrc:${NC} $fpath_line"
    fi

    # ── bash ──────────────────────────────────────────────────────────────
    local bash_comp_dir="$HOME/.bash_completion.d"
    mkdir -p "$bash_comp_dir"
    cat > "${bash_comp_dir}/${cmd}" << 'BASHCOMP'
_domains_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local opts="-o --options -e --extended -h --help --install --setup --update"
    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}
complete -F _domains_completion domains
BASHCOMP

    local bashrc="$HOME/.bashrc"
    local source_line="source \"\$HOME/.bash_completion.d/${cmd}\""
    if [[ -f "$bashrc" ]] && ! grep -qF "$source_line" "$bashrc" 2>/dev/null; then
        {   echo ""
            echo "# domains shell completion"
            echo "$source_line"
        } >> "$bashrc"
        echo -e "   ${GREEN}✅ bash:${NC} completion installed → ${bash_comp_dir}/${cmd}"
        echo -e "      Added source line to ${YELLOW}~/.bashrc${NC}"
    else
        echo -e "   ${GREEN}✅ bash:${NC} completion file written → ${bash_comp_dir}/${cmd}"
    fi

    echo ""
    echo -e "   ${YELLOW}ℹ️  Restart your terminal (or run: exec \$SHELL) to activate completion.${NC}"
}


# ── Self-update from GitHub ────────────────────────────────────────────────────
do_update() {
    local repo_url="https://raw.githubusercontent.com/lohmancorp/domains/main/domains.sh"
    local script_src
    script_src="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/$(basename "${BASH_SOURCE[0]:-$0}")"

    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   domains — Self-Update${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "   Source: ${YELLOW}${repo_url}${NC}"
    echo ""

    if ! command -v curl &>/dev/null; then
        echo -e "${RED}❗ Error:${NC} 'curl' is required for updates."
        exit 1
    fi

    # Download to a temp file
    local tmpfile; tmpfile=$(mktemp /tmp/domains_update_XXXXXX.sh)
    echo -en "   Downloading latest version... "
    local http_code
    http_code=$(curl -fsSL -w "%{http_code}" -o "$tmpfile" "$repo_url" 2>/dev/null)

    if [[ "$http_code" != "200" ]] || [[ ! -s "$tmpfile" ]]; then
        echo -e "${RED}failed.${NC}"
        echo -e "   ${RED}❗ Could not download update (HTTP ${http_code:-no response}).${NC}"
        rm -f "$tmpfile"
        exit 1
    fi
    echo -e "${GREEN}done.${NC}"

    # Verify it looks like a valid bash script
    if ! bash -n "$tmpfile" 2>/dev/null; then
        echo -e "   ${RED}❗ Downloaded file failed syntax check — aborting update.${NC}"
        rm -f "$tmpfile"
        exit 1
    fi

    # Back up current script
    local backup="${script_src}.backup"
    cp "$script_src" "$backup"
    echo -e "   Backup saved: ${YELLOW}${backup}${NC}"

    # Replace current script
    chmod +x "$tmpfile"
    if cp "$tmpfile" "$script_src" && chmod +x "$script_src"; then
        echo -e "   ${GREEN}✅ Updated successfully:${NC} ${script_src}"
    else
        echo -e "   ${RED}❗ Could not write to ${script_src} — try with sudo.${NC}"
        sudo cp "$tmpfile" "$script_src" && sudo chmod +x "$script_src"             && echo -e "   ${GREEN}✅ Updated via sudo.${NC}"
    fi

    # Also update any installed copy in PATH
    local installed; installed=$(command -v domains 2>/dev/null)
    if [[ -n "$installed" && "$installed" != "$script_src" ]]; then
        echo -en "   Also update installed copy at ${YELLOW}${installed}${NC}? [Y/n]: "
        read -r _updans
        if [[ ! "$_updans" =~ ^[Nn]$ ]]; then
            if [[ -w "$installed" ]]; then
                cp "$tmpfile" "$installed" && chmod +x "$installed"                     && echo -e "   ${GREEN}✅ Installed copy updated.${NC}"
            else
                sudo cp "$tmpfile" "$installed" && sudo chmod +x "$installed"                     && echo -e "   ${GREEN}✅ Installed copy updated via sudo.${NC}"
            fi
        fi
    fi

    rm -f "$tmpfile"
    echo ""
    echo -e "   Run ${GREEN}domains --version${NC} to confirm (if version info is included in the script)."
    echo ""
    exit 0
}

# ── Pricing data (TLD|registration|renewal) ──────────────────────────────────
# Stored as one record per line: TLD|REG|RENEW
# Based on Moniker.com prices as of 2026-03-07.
PRICING_DATA=$(cat <<'EOF'
.com|12.58 €|13.76 €
.co.com|33.79 €|38.32 €
.net|13.93 €|20.02 €
.org|12.67 €|17.40 €
.pm|10.88 €|12.65 €
.tf|10.88 €|12.65 €
.wf|10.88 €|12.65 €
.yt|10.88 €|12.65 €
.info|27.87 €|38.43 €
.tel|14.35 €|16.55 €
.us|9.29 €|11.31 €
.biz|23.65 €|23.65 €
.co.uk|5.56 €|8.59 €
.uk|8.33 €|9.56 €
.org.uk|8.33 €|9.56 €
.me.uk|14.81 €|17.16 €
.firm.in|15.62 €|17.31 €
.gen.in|15.62 €|17.31 €
.ind.in|15.62 €|17.31 €
.org.in|15.62 €|17.31 €
.net.in|15.62 €|17.31 €
.co.in|15.62 €|17.31 €
.in|21.54 €|24.07 €
.mobi|42.24 €|70.08 €
.asia|16.89 €|19.14 €
.tv|33.79 €|40.88 €
.re|10.88 €|12.65 €
.it|7.25 €|8.45 €
.eu|10.49 €|10.99 €
.be|11.99 €|13.39 €
.sk|37.21 €|42.09 €
.fr|9.98 €|11.25 €
.de|6.34 €|7.49 €
.net.co|17.73 €|20.02 €
.com.co|17.73 €|20.02 €
.co|29.56 €|38.86 €
.nom.co|17.73 €|20.02 €
.cc|20.69 €|21.33 €
.nl|10.49 €|11.49 €
.pw|24.49 €|27.45 €
.in.net|10.13 €|11.31 €
.cn.com|25.34 €|50.40 €
.jp.net|11.82 €|13.05 €
.ae.org|25.34 €|28.72 €
.us.org|25.34 €|28.72 €
.gr.com|24.50 €|28.05 €
.la|42.24 €|47.78 €
.br.com|54.49 €|56.14 €
.gb.net|43.55 €|57.16 €
.uk.com|51.80 €|59.12 €
.uk.net|51.80 €|59.12 €
.ru.com|266.14 €|248.05 €
.sa.com|595.65 €|548.25 €
.se.net|51.65 €|58.85 €
.za.com|595.65 €|548.25 €
.jpn.com|51.45 €|58.26 €
.hu.net|51.65 €|58.85 €
.africa.com|31.25 €|35.70 €
.wiki|31.25 €|34.63 €
.press|92.94 €|105.61 €
.rest|38.86 €|43.42 €
.ink|31.25 €|34.63 €
.xyz|17.31 €|21.11 €
.website|22.80 €|26.10 €
.host|118.29 €|130.96 €
.bar|73.08 €|75.27 €
.us.com|25.34 €|28.72 €
.eu.com|28.13 €|31.79 €
.de.com|24.50 €|31.79 €
.tokyo|23.68 €|25.92 €
.london|55.50 €|62.93 €
.me|22.49 €|33.49 €
.vegas|63.28 €|71.30 €
.com.de|7.25 €|8.45 €
.com.se|13.61 €|14.95 €
.mex.com|16.89 €|19.14 €
.nyc|40.12 €|44.74 €
.club|22.80 €|29.99 €
.guru|49.46 €|56.14 €
.gallery|29.63 €|33.90 €
.photography|35.06 €|39.32 €
.technology|31.59 €|35.40 €
.today|35.06 €|39.30 €
.tips|33.70 €|38.71 €
.photos|30.91 €|35.36 €
.company|36.49 €|40.39 €
.domains|47.73 €|53.15 €
.center|32.19 €|33.18 €
.management|30.45 €|34.65 €
.systems|37.75 €|43.33 €
.email|37.07 €|42.57 €
.solutions|34.44 €|38.64 €
.zone|44.56 €|50.07 €
.cool|51.78 €|58.19 €
.watch|78.56 €|88.30 €
.works|44.56 €|50.07 €
.expert|66.37 €|75.31 €
.foundation|34.63 €|39.16 €
.tools|45.37 €|51.00 €
.vision|51.78 €|58.19 €
.services|44.54 €|50.08 €
.discount|37.06 €|41.90 €
.digital|40.77 €|54.17 €
.life|37.44 €|48.72 €
.space|32.06 €|29.14 €
.money|40.14 €|45.11 €
.design|73.46 €|82.62 €
.site|35.44 €|43.05 €
.online|37.17 €|50.65 €
.tech|55.72 €|83.60 €
.global|106.46 €|120.99 €
.land|46.38 €|52.26 €
.media|50.38 €|57.23 €
.care|44.63 €|45.97 €
.house|45.38 €|51.02 €
.bid|29.14 €|30.04 €
.date|30.41 €|36.54 €
.download|30.41 €|36.54 €
.loan|30.41 €|36.54 €
.review|34.63 €|39.16 €
.science|32.94 €|37.42 €
.trade|27.03 €|34.80 €
.webcam|30.41 €|34.80 €
.college|84.49 €|95.72 €
.rent|84.49 €|95.72 €
.pro|29.99 €|38.43 €
.store|53.19 €|71.77 €
.group|32.40 €|37.09 €
.cx|59.90 €|53.02 €
.security|2996.02 €|3380.06 €
.protection|2996.02 €|3380.06 €
.theatre|814.48 €|918.99 €
.shop|46.43 €|52.34 €
.love|38.01 €|43.05 €
.realty|408.09 €|460.38 €
.observer|14.35 €|16.55 €
.art|27.87 €|31.76 €
.tickets|580.45 €|595.27 €
.storage|763.79 €|861.59 €
.io|56.57 €|59.10 €
.app|24.49 €|27.42 €
.ro|59.06 €|60.82 €
.fans|13.78 €|15.03 €
.car|2907.29 €|2994.54 €
.cars|2907.29 €|2994.54 €
.auto|2907.29 €|2994.54 €
.ai|101.39 €|104.47 €
.bz|24.07 €|24.80 €
.co.bz|25.34 €|28.72 €
.com.bz|25.34 €|28.72 €
.net.bz|25.34 €|28.72 €
.org.bz|25.34 €|28.72 €
.ch|20.69 €|21.33 €
.cz|10.13 €|10.98 €
.gr|19.05 €|21.49 €
.li|21.96 €|24.38 €
.lt|19.05 €|21.49 €
.lu|28.58 €|32.75 €
.pl|21.11 €|29.61 €
.biz.pl|43.93 €|45.24 €
.com.pl|13.51 €|15.67 €
.edu.pl|12.67 €|13.93 €
.info.pl|13.51 €|15.67 €
.net.pl|13.51 €|15.67 €
.org.pl|13.51 €|15.67 €
.si|26.18 €|29.61 €
.academy|58.34 €|65.01 €
.army|41.52 €|46.94 €
.auction|45.37 €|51.00 €
.bike|41.55 €|42.81 €
.boutique|38.78 €|39.96 €
.cafe|60.56 €|62.40 €
.cash|46.54 €|47.95 €
.chat|54.65 €|56.30 €
.cheap|39.19 €|40.39 €
.church|62.40 €|64.31 €
.coffee|48.97 €|55.04 €
.computer|44.56 €|50.07 €
.consulting|56.93 €|64.64 €
.contractors|43.49 €|48.89 €
.direct|47.37 €|53.23 €
.engineer|44.56 €|50.07 €
.enterprises|40.14 €|45.11 €
.estate|44.56 €|50.07 €
.events|52.18 €|58.67 €
.exchange|44.56 €|50.07 €
.express|49.62 €|55.19 €
.farm|44.56 €|50.07 €
.fitness|47.46 €|53.35 €
.forsale|45.37 €|51.00 €
.gives|34.63 €|39.16 €
.haus|41.87 €|47.35 €
.market|40.83 €|46.29 €
.marketing|74.07 €|83.26 €
.mba|45.57 €|51.10 €
.moda|51.33 €|58.03 €
.parts|47.46 €|53.35 €
.plus|69.41 €|77.20 €
.productions|46.21 €|51.94 €
.properties|44.56 €|50.07 €
.pub|46.21 €|51.94 €
.rentals|50.69 €|56.96 €
.repair|41.63 €|46.79 €
.sale|49.62 €|55.19 €
.shopping|42.16 €|47.78 €
.show|50.04 €|55.65 €
.social|47.37 €|53.23 €
.software|47.37 €|53.23 €
.style|58.64 €|65.64 €
.team|50.52 €|56.20 €
.town|45.36 €|51.00 €
.training|47.46 €|53.35 €
.vet|47.73 €|53.15 €
.world|40.96 €|53.30 €
.wtf|45.37 €|51.00 €
.capital|67.16 €|69.16 €
.coach|84.30 €|95.54 €
.codes|76.61 €|86.82 €
.coupons|74.26 €|83.23 €
.dating|70.14 €|79.48 €
.delivery|74.62 €|84.57 €
.dog|83.37 €|93.32 €
.engineering|70.17 €|79.52 €
.finance|72.11 €|81.74 €
.financial|69.46 €|78.72 €
.flights|64.49 €|72.57 €
.fund|77.38 €|87.71 €
.golf|79.18 €|89.84 €
.kitchen|83.46 €|93.40 €
.partners|70.11 €|79.48 €
.pizza|71.14 €|80.55 €
.recipes|84.33 €|95.58 €
.restaurant|72.04 €|81.63 €
.taxi|76.32 €|86.60 €
.tours|64.94 €|72.98 €
.toys|83.46 €|93.40 €
.university|70.77 €|80.20 €
.ventures|71.44 €|80.96 €
.vin|74.66 €|84.74 €
.wine|80.64 €|91.49 €
.agency|32.67 €|42.95 €
.city|31.68 €|36.03 €
.directory|28.04 €|32.10 €
.fyi|26.18 €|29.61 €
.institute|30.53 €|34.52 €
.international|34.44 €|38.64 €
.ltd|36.01 €|40.40 €
.report|29.08 €|33.07 €
.run|32.20 €|36.41 €
.support|33.48 €|37.54 €
.network|55.28 €|62.98 €
.band|30.35 €|31.27 €
.dance|30.53 €|34.52 €
.family|46.07 €|52.00 €
.live|36.13 €|47.57 €
.news|42.15 €|47.57 €
.reviews|54.57 €|59.38 €
.studio|45.77 €|51.67 €
.credit|113.01 €|127.61 €
.doctor|140.05 €|157.93 €
.energy|126.61 €|142.91 €
.gold|130.18 €|146.23 €
.investments|141.80 €|159.04 €
.actor|48.72 €|55.26 €
.lawyer|74.82 €|84.40 €
.casino|197.89 €|203.83 €
.games|39.52 €|44.10 €
.irish|52.00 €|58.86 €
.movie|471.75 €|531.68 €
.ninja|32.74 €|36.69 €
.rocks|26.34 €|29.39 €
.fm|93.78 €|106.20 €
.mx|50.65 €|57.41 €
.com.mx|25.34 €|28.72 €
.org.mx|22.80 €|26.10 €
.pk|56.57 €|64.37 €
.com.pk|56.57 €|64.37 €
.net.pk|56.57 €|64.37 €
.org.pk|56.57 €|64.37 €
.sx|32.94 €|37.42 €
.tm|599.88 €|678.78 €
.vg|38.01 €|42.66 €
.ws|35.48 €|39.28 €
.cm|118.91 €|134.65 €
.co.cm|20.27 €|22.63 €
.net.cm|20.27 €|22.63 €
.com.cm|20.27 €|22.63 €
.jp|41.39 €|46.93 €
.ac.nz|19.85 €|22.80 €
.co.nz|25.76 €|28.72 €
.geek.nz|20.69 €|23.23 €
.gen.nz|20.69 €|23.23 €
.maori.nz|20.69 €|23.23 €
.net.nz|25.76 €|28.72 €
.org.nz|25.76 €|28.72 €
.fo|49.90 €|56.55 €
.monster|22.38 €|21.96 €
.dev|21.11 €|23.95 €
.srl|45.54 €|51.28 €
.baby|84.06 €|86.59 €
.best|25.34 €|26.10 €
.ceo|122.51 €|126.74 €
.fun|33.37 €|37.59 €
.luxury|47.23 €|53.02 €
.saarland|32.67 €|37.39 €
.uno|37.17 €|41.81 €
.accountants|126.61 €|142.91 €
.airforce|110.13 €|124.53 €
.apartments|73.33 €|83.23 €
.associates|42.95 €|48.27 €
.bargains|32.10 €|33.08 €
.bingo|63.87 €|65.81 €
.builders|38.43 €|39.58 €
.business|37.78 €|38.92 €
.cab|67.00 €|69.03 €
.camera|76.58 €|78.91 €
.camp|82.23 €|84.71 €
.cards|74.37 €|76.62 €
.careers|67.83 €|69.88 €
.catering|42.65 €|43.93 €
.charity|37.17 €|38.32 €
.claims|64.37 €|72.98 €
.cleaning|93.99 €|105.20 €
.clinic|70.14 €|79.48 €
.clothing|70.82 €|79.58 €
.community|52.04 €|58.50 €
.condos|63.49 €|71.59 €
.construction|41.52 €|46.94 €
.cruises|61.01 €|68.77 €
.deals|44.56 €|50.07 €
.degree|62.24 €|69.58 €
.democrat|37.75 €|42.68 €
.dental|83.17 €|93.78 €
.dentist|78.05 €|88.03 €
.diamonds|64.96 €|73.66 €
.education|36.03 €|40.39 €
.equipment|35.81 €|40.49 €
.exposed|27.57 €|31.59 €
.fail|41.56 €|46.99 €
.fan|94.11 €|106.47 €
.florist|65.29 €|73.92 €
.football|27.82 €|31.74 €
.furniture|94.63 €|103.58 €
.futbol|20.67 €|22.55 €
.gifts|45.37 €|51.00 €
.glass|92.88 €|103.96 €
.gmbh|44.94 €|49.94 €
.graphics|24.17 €|27.67 €
.gratis|29.12 €|33.36 €
.gripe|37.06 €|41.90 €
.guide|47.42 €|53.30 €
.healthcare|86.75 €|98.33 €
.hockey|74.50 €|84.12 €
.holdings|70.14 €|79.48 €
.holiday|72.04 €|81.63 €
.hospital|73.13 €|82.79 €
.immo|43.44 €|49.16 €
.immobilien|46.52 €|52.60 €
.industries|46.18 €|51.94 €
.insure|80.70 €|91.46 €
.jetzt|29.12 €|33.36 €
.jewelry|73.15 €|82.61 €
.kaufen|34.63 €|39.16 €
.lease|61.01 €|68.73 €
.legal|76.23 €|85.97 €
.lighting|68.87 €|77.38 €
.limited|29.90 €|34.02 €
.limo|61.25 €|68.86 €
.loans|126.57 €|142.88 €
.maison|63.37 €|71.32 €
.memorial|61.96 €|69.75 €
.mortgage|65.71 €|73.95 €
.navy|51.33 €|58.03 €
.pictures|16.87 €|18.55 €
.plumbing|92.85 €|104.62 €
.rehab|38.79 €|43.86 €
.reise|129.07 €|145.87 €
.reisen|26.00 €|29.75 €
.republican|34.63 €|39.16 €
.rip|25.30 €|29.19 €
.salon|73.13 €|82.79 €
.sarl|37.06 €|41.90 €
.school|46.36 €|51.56 €
.schule|31.35 €|35.93 €
.shoes|83.37 €|93.32 €
.singles|38.18 €|43.30 €
.soccer|29.33 €|33.46 €
.solar|89.95 €|101.41 €
.supplies|27.07 €|30.99 €
.supply|30.45 €|34.65 €
.surgery|64.53 €|72.64 €
.tax|66.36 €|75.22 €
.tennis|81.68 €|92.27 €
.theater|75.13 €|84.84 €
.tienda|61.42 €|69.13 €
.tires|98.85 €|111.40 €
.vacations|44.56 €|50.07 €
.viajes|53.99 €|60.82 €
.video|39.74 €|44.85 €
.villas|71.06 €|79.98 €
.voyage|65.14 €|73.32 €
.build|72.23 €|74.43 €
.cricket|34.63 €|39.16 €
.faith|34.63 €|39.16 €
.men|30.41 €|36.54 €
.menu|38.86 €|43.42 €
.party|27.87 €|36.54 €
.racing|34.63 €|39.16 €
.stream|27.03 €|33.96 €
.tube|30.41 €|34.80 €
.win|30.41 €|36.54 €
.boston|25.34 €|26.10 €
.casa|22.38 €|22.80 €
.rodeo|51.50 €|54.88 €
.vip|33.79 €|37.17 €
.work|14.78 €|16.89 €
.at|15.42 €|17.79 €
.com.au|9.63 €|11.38 €
.ca|14.18 €|14.63 €
.fi|25.49 €|28.49 €
.ga|20.99 €|22.65 €
.lv|20.87 €|23.29 €
.se|30.41 €|31.34 €
.co.za|7.17 €|8.44 €
.capetown|105.61 €|108.78 €
.click|17.73 €|20.27 €
.cologne|42.65 €|47.59 €
.cymru|22.24 €|24.84 €
.durban|109.84 €|126.19 €
.gdn|10.13 €|11.31 €
.icu|17.73 €|28.30 €
.joburg|109.84 €|126.19 €
.koeln|42.65 €|47.59 €
.link|12.67 €|13.93 €
.markets|28.77 €|33.21 €
.nagoya|23.68 €|25.92 €
.okinawa|23.51 €|25.75 €
.one|35.48 €|40.55 €
.onl|24.92 €|28.72 €
.page|19.00 €|21.76 €
.qpon|35.48 €|40.04 €
.ryukyu|23.51 €|25.75 €
.wales|22.24 €|24.84 €
.wang|10.98 €|12.21 €
.yokohama|23.68 €|25.92 €
.gay|28.30 €|30.83 €
.es|9.98 €|11.25 €
.beauty|21.96 €|22.38 €
.hair|23.23 €|26.18 €
.quest|23.23 €|26.18 €
.skin|23.23 €|26.18 €
.makeup|23.23 €|26.18 €
.homes|23.23 €|26.18 €
.motorcycles|23.23 €|26.18 €
.autos|21.96 €|22.38 €
.boats|21.96 €|22.38 €
.yachts|23.23 €|26.18 €
.day|19.00 €|21.76 €
.au|9.63 €|11.38 €
.game|457.94 €|516.06 €
.lol|43.89 €|48.96 €
.mom|43.01 €|48.66 €
.audio|168.13 €|173.20 €
.flowers|176.58 €|199.30 €
.diet|176.58 €|199.30 €
.pics|45.58 €|51.50 €
.guitars|176.58 €|199.30 €
.christmas|50.26 €|51.78 €
.hosting|483.28 €|545.68 €
.lat|43.89 €|48.96 €
.net.au|9.63 €|11.38 €
.accountant|34.63 €|39.16 €
.adult|152.08 €|160.53 €
.aero|52.30 €|59.10 €
.africa|32.52 €|47.27 €
.attorney|74.82 €|84.40 €
.beer|36.32 €|36.32 €
.berlin|69.24 €|71.77 €
.bet|29.42 €|30.34 €
.bio|98.84 €|101.84 €
.black|76.98 €|79.29 €
.blog|34.21 €|35.27 €
.blue|27.57 €|28.44 €
.broker|43.62 €|44.97 €
.buzz|36.32 €|37.42 €
.cam|35.05 €|36.12 €
.career|105.60 €|108.78 €
.cat|29.99 €|36.41 €
.cloud|21.11 €|29.61 €
.compare|44.74 €|48.96 €
.contact|20.61 €|23.36 €
.cooking|38.86 €|41.39 €
.country|1891.05 €|1947.79 €
.courses|46.43 €|51.50 €
.creditcard|158.84 €|179.28 €
.earth|26.18 €|29.61 €
.eco|101.39 €|113.17 €
.fashion|40.97 €|45.58 €
.film|103.92 €|117.52 €
.fish|85.71 €|95.65 €
.fit|40.97 €|45.58 €
.garden|40.97 €|45.58 €
.gift|24.49 €|28.30 €
.green|106.41 €|119.95 €
.health|97.16 €|105.61 €
.help|45.58 €|51.50 €
.hiphop|39.70 €|45.19 €
.hiv|277.13 €|312.44 €
.horse|38.86 €|41.39 €
.how|33.79 €|38.32 €
.inc|2927.58 €|3302.59 €
.istanbul|26.18 €|29.61 €
.jobs|432.59 €|445.59 €
.kim|26.35 €|30.31 €
.llc|60.22 €|67.79 €
.miami|26.18 €|29.14 €
.moe|19.42 €|21.76 €
.museum|61.59 €|69.53 €
.new|603.26 €|680.56 €
.organic|99.12 €|112.66 €
.pet|30.43 €|34.62 €
.photo|40.12 €|45.24 €
.pink|27.92 €|31.06 €
.poker|89.60 €|100.81 €
.porn|152.08 €|160.53 €
.promo|32.09 €|36.20 €
.property|176.58 €|199.30 €
.radio|360.77 €|407.28 €
.radio.am|21.11 €|23.48 €
.radio.fm|21.11 €|23.48 €
.red|27.33 €|31.31 €
.scot|50.61 €|57.36 €
.sex|160.53 €|168.98 €
.sexy|2365.88 €|2436.85 €
.ski|91.70 €|102.95 €
.spa|38.01 €|42.66 €
.sucks|343.87 €|388.14 €
.top|16.89 €|21.76 €
.trading|27.04 €|31.06 €
.travel|150.99 €|170.28 €
.vote|106.42 €|119.76 €
.wedding|40.97 €|45.58 €
.wien|62.48 €|70.46 €
.yoga|39.70 €|43.89 €
.ac|76.84 €|86.98 €
.ae|50.26 €|51.78 €
.ag|110.68 €|125.34 €
.am|52.30 €|59.10 €
.as|76.80 €|86.09 €
.bi|63.78 €|65.72 €
.cl|46.39 €|52.12 €
.club.tw|26.18 €|29.61 €
.co.at|12.67 €|13.93 €
.co.gg|64.97 €|73.89 €
.co.je|63.28 €|71.30 €
.co.nl|9.29 €|10.43 €
.co.no|25.34 €|28.72 €
.com.ag|78.49 €|88.79 €
.com.ai|102.23 €|114.90 €
.com.ar|92.94 €|100.11 €
.com.es|3.37 €|3.51 €
.com.gl|50.61 €|57.36 €
.com.hn|84.41 €|94.87 €
.com.lc|21.96 €|25.25 €
.com.nf|89.56 €|100.96 €
.com.ng|8.44 €|9.59 €
.com.pe|59.90 €|67.80 €
.com.ph|142.79 €|161.03 €
.com.sc|118.29 €|135.18 €
.com.tw|26.18 €|29.61 €
.com.vc|38.01 €|42.66 €
.com.vn|211.23 €|143.62 €
.dk|14.35 €|15.67 €
.dm|257.69 €|291.49 €
.ebiz.tw|26.18 €|29.61 €
.ec|72.58 €|81.74 €
.gd|39.70 €|43.42 €
.gg|104.77 €|118.36 €
.gl|50.61 €|57.36 €
.gs|24.49 €|27.84 €
.gy|40.55 €|46.04 €
.hn|84.41 €|94.87 €
.ht|112.37 €|127.06 €
.im|13.51 €|15.67 €
.is|80.22 €|88.71 €
.isla.pr|12.67 €|13.93 €
.je|105.61 €|119.26 €
.lc|30.41 €|34.80 €
.md|202.78 €|228.87 €
.mg|142.79 €|161.03 €
.mn|63.33 €|70.93 €
.ms|84.45 €|97.16 €
.mu|94.63 €|106.20 €
.net.ag|78.49 €|88.79 €
.net.gg|63.28 €|71.30 €
.net.je|63.28 €|71.30 €
.net.pe|59.90 €|67.80 €
.net.sc|118.29 €|135.18 €
.ng|43.85 €|49.55 €
.nu|30.41 €|31.34 €
.nz|38.01 €|43.89 €
.org.ag|78.49 €|88.79 €
.org.es|3.37 €|3.51 €
.org.gg|63.28 €|71.30 €
.org.il|27.87 €|31.34 €
.org.je|63.28 €|71.30 €
.org.sc|118.29 €|135.18 €
.pe|59.90 €|67.80 €
.ph|141.10 €|159.26 €
.pr|1522.51 €|1717.00 €
.ps|70.89 €|80.00 €
.sc|126.74 €|143.63 €
.sh|76.84 €|86.98 €
.so|86.18 €|97.49 €
.tc|135.18 €|152.08 €
.tl|87.87 €|66.06 €
.tw|31.25 €|35.70 €
.uz|125.05 €|141.01 €
.vc|38.01 €|42.66 €
.vn|232.35 €|165.39 €
.forex|131.38 €|148.67 €
.kiwi|30.00 €|34.26 €
.law|152.08 €|156.31 €
.rugby|68.05 €|76.79 €
.blackfriday|138.97 €|138.97 €
.bond|16.90 €|16.90 €
.boo|14.13 €|14.13 €
.bot|69.61 €|69.61 €
.cfd|16.90 €|16.90 €
.co.am|38.84 €|38.84 €
.co.im|6.94 €|6.94 €
.com.ec|43.50 €|43.50 €
.com.ro|9.71 €|9.71 €
.cyou|16.90 €|16.90 €
.hamburg|51.57 €|51.57 €
.ki|1387.15 €|1387.15 €
.luxe|21.11 €|21.11 €
.madrid|34.90 €|34.90 €
.name|9.40 €|9.40 €
.net.za|105.61 €|105.61 €
.or.at|11.79 €|11.79 €
.org.au|13.09 €|13.09 €
.org.za|105.61 €|105.61 €
.paris|52.95 €|52.95 €
.ruhr|27.99 €|27.99 €
.sb|83.23 €|83.23 €
.sbs|16.90 €|16.90 €
.select|33.54 €|33.54 €
.sydney|69.66 €|69.66 €
.tattoo|41.86 €|41.86 €
.versicherung|137.52 €|137.52 €
.vodka|33.54 €|33.54 €
.qa|67.97 €|67.97 €
.net.gl|37.45 €|37.45 €
EOF
)

# ── External pricing file loader ──────────────────────────────────────────────
# Called once after the built-in PRICING_DATA is defined.
# When PRICING_FILE is set and valid, it replaces PRICING_DATA entirely.
load_pricing_file() {
    [[ -z "${PRICING_FILE:-}" ]] && return 0   # feature not enabled

    if [[ ! -f "$PRICING_FILE" ]]; then
        echo -e "${RED}❗ Error:${NC} PRICING_FILE not found: $PRICING_FILE" >&2
        exit 1
    fi

    local ext="${PRICING_FILE##*.}"
    ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    local loaded=""

    # Helper: strip any currency symbol / whitespace, keep only digits . and ,
    # e.g.  "$ 12.00"  "12,58 €"  "12.00$"  -> "12.00" / "12,58" / "12.00"
    _clean_price() {
        echo "$1" | sed 's/[^0-9.,]//g'
    }

    case "$ext" in
        csv|tsv)
            # ── Smart CSV/TSV loader — pure bash + awk, no python3 needed ────
            # Detects two layouts automatically:
            #   Layout A: TLD | Registration | Renewal   (simple 3-col)
            #   Layout B: TLD | [Years] | Operation | Price | ...
            #             create/register → reg price;  renew/renewal → renewal price

            # Detect delimiter from first real data line (skip blank/header lines)
            local _delim=',' _first_real
            _first_real=$(grep -v '^[[:space:]]*,' "$PRICING_FILE" | awk 'NR>1{print;exit}')
            [[ "$_first_real" == *$'\t'* ]] && _delim=$'\t'

            # Find which column (2 or 3) contains operation keywords
            # Strip UTF-8 BOM (\xEF\xBB\xBF) that Excel/some editors add to CSV headers
            local _op_col=0
            while IFS="$_delim" read -r _f1 _f2 _f3 _rest; do
                [[ -z "$_f1" ]] && continue
                # Strip BOM from first field, then lowercase
                _f1l=$(echo "$_f1" | sed 's/^\xEF\xBB\xBF//' | tr '[:upper:]' '[:lower:]' | tr -d ' ')
                # Skip any row that looks like a header (known column label words)
                case "$_f1l" in
                    tld|domain|extension|"")
                        continue ;;
                esac
                _f2l=$(echo "$_f2" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
                _f3l=$(echo "$_f3" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
                # If col2 or col3 looks like a header label, not an op keyword, skip row
                case "$_f2l" in register|registration|renewal|price|operation|years|op|action) continue ;; esac
                case "$_f3l" in register|registration|renewal|price|operation|years|op|action) continue ;; esac
                # Now check for actual operation values
                case "$_f2l" in
                    create|renew|update|transfer|restore|trade)
                        _op_col=2; break ;;
                esac
                case "$_f3l" in
                    create|renew|update|transfer|restore|trade)
                        _op_col=3; break ;;
                esac
                break
            done < "$PRICING_FILE"

            if [[ $_op_col -gt 0 ]]; then
                # Layout B: operation-row format
                local _pcol=$(( _op_col + 1 ))
                loaded=$(awk -v FS="$_delim" -v opcol="$_op_col" -v pcol="$_pcol" '
                    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
                    function clean(s) { gsub(/[^0-9.,]/, "", s); return s }
                    function normtld(t) { return (substr(t,1,1)!=".") ? "." t : t }
                    NR==1 { next }
                    NF < pcol { next }
                    {
                        tld=trim($1)
                        if (tld=="" || tolower(tld)=="tld" || tolower(tld)=="domain") next
                        if (substr(tld,1,1)==",") next
                        tld=normtld(tld)
                        op=tolower(trim($opcol)); price=clean(trim($pcol))
                        if (op=="create"||op=="register"||op=="registration") {
                            if (!reg[tld]) reg[tld]=price
                        } else if (op=="renew"||op=="renewal") {
                            if (!ren[tld]) ren[tld]=price
                        }
                    }
                    END {
                        for (t in reg) { n=(ren[t]?ren[t]:""); print t "|" reg[t] "|" n }
                        for (t in ren) { if (!reg[t]) print t "||" ren[t] }
                    }
                ' "$PRICING_FILE")

            else
                # Layout A: simple 3-col format — strip BOM, skip header, output tld|reg|renew
                loaded=$(sed 's/^\xEF\xBB\xBF//' "$PRICING_FILE" | awk -v FS="$_delim" '
                    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
                    function clean(s) { gsub(/[^0-9.,]/, "", s); return s }
                    NR==1 { next }
                    NF>=2 && $1!="" {
                        tld=trim($1); reg=clean(trim($2)); renew=clean(trim($3))
                        if (tld=="" || substr(tld,1,1)==",") next
                        if (tolower(tld)=="tld"||tolower(tld)=="domain"||tolower(tld)=="extension") next
                        if (substr(tld,1,1)!=".") tld="." tld
                        if (tld!=".") print tld "|" reg "|" renew
                    }
                ')
            fi
            ;;
        *)
            echo -e "${RED}❗ Error:${NC} Unsupported file type: .$ext  (use .csv or .tsv)" >&2
            exit 1
            ;;
    esac

    if [[ -z "$loaded" ]]; then
        echo -e "${YELLOW}⚠️  Warning:${NC} PRICING_FILE loaded but contained no usable rows. Using built-in data." >&2
        return 0
    fi

    PRICING_DATA="$loaded"
    #echo -e "${GREEN}ℹ️  Pricing loaded from:${NC} $PRICING_FILE" >&2
}

# Run loader (no-op when PRICING_FILE is not set)
load_pricing_file

# ── Helper: look up pricing for a domain ─────────────────────────────────────
# Sorts TLD candidates longest-first so .co.uk matches before .uk, etc.
get_pricing() {
    local domain="$1"
    # Build a list of TLDs sorted by length descending
    local sorted_tlds
    sorted_tlds=$(echo "$PRICING_DATA" | awk -F'|' '{print length($1), $0}' | sort -rn | cut -d' ' -f2-)

    while IFS='|' read -r tld reg renew; do
        # Check if domain ends with this TLD
        case "$domain" in
            *"$tld") echo "$tld|$reg|$renew"; return 0 ;;
        esac
    done <<< "$sorted_tlds"

    echo ""
    return 1
}

# ── Helper: validate that a domain's TLD is in our pricing list ───────────────
is_valid_tld() {
    local domain="$1"
    local result
    result=$(get_pricing "$domain")
    [[ -n "$result" ]]
}

# ── check_domain ─────────────────────────────────────────────────────────────
# Uses RDAP (rdap.org) instead of whois.
check_domain() {
    local domain="$1"
    local extended="$2"   # "true" = verbose; default (empty) = compact

    # Ensure curl is installed
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}❗ Error:${NC} 'curl' is not installed. Please install it first."
        exit 1
    fi

    # Query RDAP (rdap.org follows IANA bootstrap; -L follows redirects)
    local rdap_url="https://rdap.org/domain/${domain}"
    local raw http_code output

    # ── Inner query helper — called once (and again on 429) ──────────────
    _do_rdap_query() {
        raw=$(curl -sL -w "\n__HTTP_CODE__:%{http_code}" "$rdap_url" 2>/dev/null)
        http_code=$(printf '%s' "$raw" | grep -o '__HTTP_CODE__:[0-9]*' | cut -d: -f2)
        output=$(printf '%s' "$raw" | sed '/^__HTTP_CODE__:/d')
    }

    _do_rdap_query

    # Handle rate limiting (HTTP 429 or RDAP servers that return 503/429 body)
    if [[ "$http_code" == "429" || "$http_code" == "503" ]]; then
        echo -e "${YELLOW}⏳ Rate limited by RDAP server for ${domain}. Waiting 5 seconds...${NC}" >&2
        sleep 5
        _do_rdap_query
    fi

    # HTTP 404 → domain available; 200 → taken; anything else → error
    if [[ "$http_code" == "404" ]]; then

        # ── AVAILABLE ────────────────────────────────────────────────────────
        local pricing
        pricing=$(get_pricing "$domain")

        if [[ "$extended" == "true" ]]; then
            if [[ -n "$pricing" ]]; then
                local reg renew
                reg=$(echo "$pricing" | cut -d'|' -f2)
                renew=$(echo "$pricing" | cut -d'|' -f3)
                echo -e "${GREEN}✅ AVAILABLE:${NC} ${domain}"
                echo -e "   ${GREEN}1st Year:${NC} $reg"
                echo -e "   ${GREEN}Renewal:${NC} $renew"
                echo "$reg" | tr -d ',€ '
            else
                echo -e "${GREEN}✅ AVAILABLE:${NC} ${domain}"
                echo "0"
            fi
        else
            if [[ -n "$pricing" ]]; then
                local reg renew
                reg=$(echo "$pricing" | cut -d'|' -f2)
                renew=$(echo "$pricing" | cut -d'|' -f3)
                echo -e "${GREEN}✅${NC} - ${domain} - ${reg}"
                echo "$reg" | tr -d ',€ '
            else
                echo -e "${GREEN}✅${NC} - ${domain}"
                echo "0"
            fi
        fi

    elif [[ "$http_code" == "200" ]]; then
        # ── TAKEN ────────────────────────────────────────────────────────────

        # Guard: some RDAP upstreams return HTTP 200 with a rate-limit HTML/text
        # body instead of JSON. Detect this and retry once after a pause.
        local _first_char
        _first_char=$(printf '%s' "$output" | head -c1)
        if [[ "$_first_char" != "{" && "$_first_char" != "[" ]]; then
            echo -e "${YELLOW}⏳ Unexpected response for ${domain} (possible rate limit). Waiting 5 seconds...${NC}" >&2
            sleep 5
            _do_rdap_query
            _first_char=$(printf '%s' "$output" | head -c1)
            if [[ "$_first_char" != "{" && "$_first_char" != "[" ]]; then
                echo -e "${YELLOW}⚠️  Could not get valid RDAP data for ${domain}. Skipping detail parse.${NC}" >&2
                echo -e "${RED}❌${NC} - TAKEN: ${domain}"
                echo "0"
                return
            fi
        fi

        if [[ "$extended" != "true" ]]; then
            echo -e "${RED}❌${NC} - TAKEN: ${domain}"
        else
            printf '\033[0;31m❌ TAKEN:\033[0m \033]8;;http://%s\a%s\033]8;;\a\n' "$domain" "$domain"

            # Parse RDAP JSON using python3 (handles nested vcard + events array)
            local registrar updated expiry
            registrar=$(printf '%s' "$output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()
for ent in d.get('entities', []):
    if 'registrar' in ent.get('roles', []):
        vcard = ent.get('vcardArray', [])
        if len(vcard) > 1:
            for item in vcard[1]:
                if item[0] == 'fn':
                    print(item[3]); sys.exit()
" 2>/dev/null)
            updated=$(printf '%s' "$output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()
for ev in d.get('events', []):
    if ev.get('eventAction','').lower() == 'last changed':
        print(ev.get('eventDate','')); sys.exit()
" 2>/dev/null)
            expiry=$(printf '%s' "$output" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()
for ev in d.get('events', []):
    if ev.get('eventAction','').lower() in ('expiration','expires'):
        print(ev.get('eventDate','')); sys.exit()
" 2>/dev/null)

            [[ -n "$registrar" ]] && echo -e "   ${YELLOW}Registrar:${NC} $registrar"
            [[ -n "$updated"   ]] && echo -e "   ${YELLOW}Last Update:${NC} $updated"
            [[ -n "$expiry"    ]] && echo -e "   ${YELLOW}Expiration Date:${NC} $expiry"

            # DNS records via dig
            if command -v dig &>/dev/null; then
                local dig_records
                dig_records=$(
                    {
                        dig "$domain" A     +noall +answer 2>/dev/null
                        dig "$domain" CNAME +noall +answer 2>/dev/null
                    } | awk '$4 == "A" || $4 == "CNAME" {
                        name=$1; sub(/\.$/, "", name);
                        type=$4;
                        val=$NF; sub(/\.$/, "", val);
                        print "   " name " - " type " - " val
                      }' | sort -u
                )
                [[ -n "$dig_records" ]] && echo -e "$dig_records"
            fi
        fi

        echo "0"

    else
        # ── ERROR / UNEXPECTED ────────────────────────────────────────────────
        echo -e "${YELLOW}⚠️ ERROR:${NC} RDAP lookup failed for ${domain} (HTTP ${http_code:-no response}). Try again later."
        exit 1
    fi
}

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
    echo "Usage: $(basename "$0") <domain> [-o] [-e]"
    echo "  -o   Prompt for TLD options (pre-filled with your defaults)"
    echo "  -e   Extended output — full details with spacing"
    echo ""
    echo "  --install   Install script to system bin and run setup wizard"
    echo "  --setup     Re-run the setup wizard (update defaults / pricing file)"
    echo "  --update    Pull the latest version from GitHub"
    exit 1
}

# Handle --install / --setup / --update before standard argument loop (no domain required)
for _pre_arg in "$@"; do
    case "$_pre_arg" in
        --install) do_install ;;   # do_install calls exit 0
        --setup)   run_setup; exit 0 ;;
        --update)  do_update ;;    # do_update calls exit 0
    esac
done

OPTIONS=""
EXTENDED=""
PRIMARY_DOMAIN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--options)   OPTIONS="true" ;;
        -e|--extended)  EXTENDED="true" ;;
        --install|--setup|--update) : ;;   # already handled above
        -h|--help)      usage ;;
        -*)             echo -e "${RED}❗ Error:${NC} Unknown option: $1"; usage ;;
        *)
            if [[ -z "$PRIMARY_DOMAIN" ]]; then
                PRIMARY_DOMAIN="$1"
            else
                echo -e "${RED}❗ Error:${NC} Unexpected argument: $1"; usage
            fi
            ;;
    esac
    shift
done

if [[ -z "$PRIMARY_DOMAIN" ]]; then
    usage
fi

# ── First-run detection ───────────────────────────────────────────────────────
# If no personal config exists, this user hasn't done setup yet.
# Offer the wizard but don't block the query if they decline.
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}👋 Welcome! Looks like this is your first time running the domains tool.${NC}"
    echo -en "   Run the setup wizard now? [Y/n]: "
    read -r _first_ans
    if [[ ! "$_first_ans" =~ ^[Nn]$ ]]; then
        run_setup
        # Reload pricing if PRICING_FILE was configured during setup
        [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
        load_pricing_file
    else
        # Write minimal config so this prompt doesn't repeat
        mkdir -p "$(dirname "$CONFIG_FILE")"
        {   echo "# domains personal configuration"
            echo "SETUP_DONE=true"
            echo "# Run: $(basename "$0") --setup   to configure at any time"
        } > "$CONFIG_FILE"
    fi
fi

# ── Validate primary domain TLD ───────────────────────────────────────────────
if ! is_valid_tld "$PRIMARY_DOMAIN"; then
    raw_tld=".${PRIMARY_DOMAIN##*.}"
    echo -e "\n ${RED}⚠️  Error:${NC} ${raw_tld} is not a valid TLD.\n"
    exit 1
fi

# ── Build domain list ─────────────────────────────────────────────────────────
domains_to_check=("$PRIMARY_DOMAIN")

if [[ "$OPTIONS" == "true" ]]; then
    # Trap Ctrl+C gracefully
    trap 'echo -e "\n${RED}Operation cancelled.${NC}"; exit 0' INT

    # Build pre-filled default string from CONFIG
    default_str=""
    if [[ ${#DEFAULT_TLDS[@]} -gt 0 ]]; then
        default_str=$(printf "%s " "${DEFAULT_TLDS[@]}")
        default_str="${default_str% }"  # trim trailing space
    fi

    echo -e "${YELLOW}Enter additional TLDs (space/comma separated). Press Enter to use defaults.${NC}"
    if [[ -n "$default_str" ]]; then
        echo -e "${YELLOW}Defaults:${NC} ${default_str}"
    fi
    echo -en "${YELLOW}TLDs: ${NC}"
    read -r user_input

    # If blank, fall back to defaults
    if [[ -z "${user_input// /}" ]] && [[ -n "$default_str" ]]; then
        user_input="$default_str"
    fi

    trap - INT  # reset trap

    # Strip surrounding parentheses if present
    user_input="${user_input#(}"
    user_input="${user_input%)}"

    # Extract base name (everything before the last dot)
    if [[ "$PRIMARY_DOMAIN" == *.* ]]; then
        base_name="${PRIMARY_DOMAIN%.*}"
    else
        base_name="$PRIMARY_DOMAIN"
    fi

    # Replace commas with spaces
    user_input="${user_input//,/ }"

    for tld in $user_input; do
        [[ -z "$tld" ]] && continue
        clean_tld="${tld#.}"          # strip leading dot if present
        ext_domain="${base_name}.${clean_tld}"

        if ! is_valid_tld "$ext_domain"; then
            echo -e "\n⚠️  Error: .${clean_tld} is not a valid TLD."
            continue
        fi

        # Prevent duplicates
        already=false
        for d in "${domains_to_check[@]}"; do
            [[ "$d" == "$ext_domain" ]] && already=true && break
        done
        $already || domains_to_check+=("$ext_domain")
    done
fi

# ── Guards & rate limiting ────────────────────────────────────────────────────
# RDAP rate limit: never exceed 10 requests per 11 seconds.
#   1–6  domains → 500 ms between requests  (≤ 12 req/11 s, safe with margin)
#   7–20 domains → 1100 ms between requests (≤ 10 req/11 s, exact limit)
#   21+  domains → refuse (too risky)
total_domains="${#domains_to_check[@]}"

echo ""  # blank line before first result

if (( total_domains > 20 )); then
    echo -e "\n  ${RED}🛑 Too many domains.${NC} Please limit to 20 at a time to avoid hitting the RDAP rate limit.\n"
    exit 1
fi

if (( total_domains <= 6 )); then
    delay=0.5
else
    delay=1.1
fi

# ── Run checks ────────────────────────────────────────────────────────────────
total_cost=0

for (( i=0; i<total_domains; i++ )); do
    domain="${domains_to_check[$i]}"

    # Capture output — last line is the numeric cost (or 0)
    raw_output=$(check_domain "$domain" "$EXTENDED")
    cost=$(echo "$raw_output" | tail -1)
    display=$(echo "$raw_output" | sed '$d')

    echo -e "$display"

    # Accumulate cost (use bc for float arithmetic)
    total_cost=$(echo "$total_cost + $cost" | bc)

    # Newline + delay between domains (not after last)
    if (( i < total_domains - 1 )); then
        [[ "$EXTENDED" == "true" ]] && echo ""
        sleep "$delay"
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
if (( $(echo "$total_cost > 0" | bc -l) )); then
    if [[ "$EXTENDED" == "true" ]]; then
        printf "\n${GREEN}💰 Your potential spend is:${NC} %.2f \n\n" "$total_cost"
    else
        printf "${GREEN}💰${NC} - Spend: %.2f \n" "$total_cost" 
        printf "\n"
    fi
else
    [[ "$EXTENDED" == "true" ]] && echo ""
fi
