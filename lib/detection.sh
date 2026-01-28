#!/bin/bash
# WCURGUI - Bitcoin Core Detection
# Detects Bitcoin Core installation, datadir, conf, and RPC auth

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Cache file location
CACHE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wcurgui"
CACHE_FILE="$CACHE_DIR/detection_cache.json"

# Detection results (exported for other scripts)
export BITCOIN_CLI_PATH=""
export BITCOIN_DATADIR=""
export BITCOIN_CONF=""
export BITCOIN_NETWORK="main"   # main, test, signet, regtest
export BITCOIN_RPC_HOST="127.0.0.1"
export BITCOIN_RPC_PORT="8332"
export BITCOIN_RPC_USER=""
export BITCOIN_RPC_PASS=""
export BITCOIN_COOKIE_PATH=""
export BITCOIN_VERSION=""
export BITCOIN_RUNNING=0
export BITCOIN_DETECTION_METHOD=""

# Common datadir locations to search (Linux)
DATADIR_CANDIDATES=(
    "$HOME/.bitcoin"
    "/var/lib/bitcoind"
    "/var/lib/bitcoin"
    "/srv/bitcoin"
    "/data/bitcoin"
    "/opt/bitcoin/data"
    "/home/bitcoin/.bitcoin"
)

# Common binary locations
BINARY_PATHS=(
    "/usr/bin"
    "/usr/local/bin"
    "/opt/bitcoin/bin"
    "/snap/bin"
    "$HOME/bin"
    "$HOME/.local/bin"
)

# ═══════════════════════════════════════════════════════════════════════════════
# CACHE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Save detection results to cache
save_cache() {
    mkdir -p "$CACHE_DIR"

    cat > "$CACHE_FILE" << EOF
{
    "cli_path": "$BITCOIN_CLI_PATH",
    "datadir": "$BITCOIN_DATADIR",
    "conf": "$BITCOIN_CONF",
    "network": "$BITCOIN_NETWORK",
    "rpc_host": "$BITCOIN_RPC_HOST",
    "rpc_port": "$BITCOIN_RPC_PORT",
    "rpc_user": "$BITCOIN_RPC_USER",
    "cookie_path": "$BITCOIN_COOKIE_PATH",
    "timestamp": "$(date -Iseconds)"
}
EOF
    chmod 600 "$CACHE_FILE"
}

# Load cache and validate it still works
load_cache() {
    [[ ! -f "$CACHE_FILE" ]] && return 1

    local cached
    cached=$(cat "$CACHE_FILE" 2>/dev/null) || return 1

    # Parse with jq if available, otherwise basic parsing
    if command -v jq &>/dev/null; then
        BITCOIN_CLI_PATH=$(echo "$cached" | jq -r '.cli_path // empty')
        BITCOIN_DATADIR=$(echo "$cached" | jq -r '.datadir // empty')
        BITCOIN_CONF=$(echo "$cached" | jq -r '.conf // empty')
        BITCOIN_NETWORK=$(echo "$cached" | jq -r '.network // "main"')
        BITCOIN_RPC_HOST=$(echo "$cached" | jq -r '.rpc_host // "127.0.0.1"')
        BITCOIN_RPC_PORT=$(echo "$cached" | jq -r '.rpc_port // "8332"')
        BITCOIN_RPC_USER=$(echo "$cached" | jq -r '.rpc_user // empty')
        BITCOIN_COOKIE_PATH=$(echo "$cached" | jq -r '.cookie_path // empty')
    else
        # Fallback grep parsing
        BITCOIN_CLI_PATH=$(grep -oP '"cli_path":\s*"\K[^"]+' <<< "$cached")
        BITCOIN_DATADIR=$(grep -oP '"datadir":\s*"\K[^"]+' <<< "$cached")
        BITCOIN_CONF=$(grep -oP '"conf":\s*"\K[^"]+' <<< "$cached")
    fi

    # Validate the cached values still work
    [[ -n "$BITCOIN_CLI_PATH" && -x "$BITCOIN_CLI_PATH" ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# PROCESS DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Check if bitcoind is running and extract its arguments
detect_running_process() {
    local pinfo

    # Try to find bitcoind process
    pinfo=$(pgrep -a bitcoind 2>/dev/null | head -1) || return 1

    [[ -z "$pinfo" ]] && return 1

    BITCOIN_RUNNING=1
    BITCOIN_DETECTION_METHOD="process"

    # Extract the binary path
    local bin_path
    bin_path=$(echo "$pinfo" | awk '{print $2}')

    # If it's just "bitcoind", find full path
    if [[ "$bin_path" == "bitcoind" ]]; then
        bin_path=$(command -v bitcoind)
    fi

    # Extract arguments
    local args
    args=$(echo "$pinfo" | cut -d' ' -f3-)

    # Parse -datadir
    if [[ "$args" =~ -datadir=([^[:space:]]+) ]]; then
        BITCOIN_DATADIR="${BASH_REMATCH[1]}"
    fi

    # Parse -conf
    if [[ "$args" =~ -conf=([^[:space:]]+) ]]; then
        BITCOIN_CONF="${BASH_REMATCH[1]}"
    fi

    # Parse network flags
    if [[ "$args" =~ -testnet ]]; then
        BITCOIN_NETWORK="test"
        BITCOIN_RPC_PORT="18332"
    elif [[ "$args" =~ -signet ]]; then
        BITCOIN_NETWORK="signet"
        BITCOIN_RPC_PORT="38332"
    elif [[ "$args" =~ -regtest ]]; then
        BITCOIN_NETWORK="regtest"
        BITCOIN_RPC_PORT="18443"
    fi

    # Parse RPC settings
    if [[ "$args" =~ -rpcport=([0-9]+) ]]; then
        BITCOIN_RPC_PORT="${BASH_REMATCH[1]}"
    fi
    if [[ "$args" =~ -rpcuser=([^[:space:]]+) ]]; then
        BITCOIN_RPC_USER="${BASH_REMATCH[1]}"
    fi
    if [[ "$args" =~ -rpcpassword=([^[:space:]]+) ]]; then
        BITCOIN_RPC_PASS="${BASH_REMATCH[1]}"
    fi
    if [[ "$args" =~ -rpccookiefile=([^[:space:]]+) ]]; then
        BITCOIN_COOKIE_PATH="${BASH_REMATCH[1]}"
    fi

    # Derive bitcoin-cli path from bitcoind path
    if [[ -n "$bin_path" ]]; then
        local cli_path="${bin_path%d}"  # Remove trailing 'd' -> bitcoin-cli
        cli_path="${cli_path}-cli"
        if [[ -x "$cli_path" ]]; then
            BITCOIN_CLI_PATH="$cli_path"
        fi
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEMD DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Check systemd services for bitcoin
detect_systemd_service() {
    command -v systemctl &>/dev/null || return 1

    local services
    services=$(systemctl list-units --type=service --all 2>/dev/null | grep -iE 'bitcoin' | awk '{print $1}')

    [[ -z "$services" ]] && return 1

    for service in $services; do
        # Check if service is active
        if ! systemctl is-active --quiet "$service" 2>/dev/null; then
            continue
        fi

        BITCOIN_DETECTION_METHOD="systemd"

        # Get the ExecStart line
        local exec_start
        exec_start=$(systemctl show "$service" --property=ExecStart 2>/dev/null)

        # Parse datadir from ExecStart
        if [[ "$exec_start" =~ -datadir=([^[:space:]\;]+) ]]; then
            BITCOIN_DATADIR="${BASH_REMATCH[1]}"
        fi

        # Parse conf from ExecStart
        if [[ "$exec_start" =~ -conf=([^[:space:]\;]+) ]]; then
            BITCOIN_CONF="${BASH_REMATCH[1]}"
        fi

        # Check environment files
        local env_file
        env_file=$(systemctl show "$service" --property=EnvironmentFile 2>/dev/null | cut -d'=' -f2-)

        if [[ -n "$env_file" && -f "$env_file" ]]; then
            # Source env file to get variables
            while IFS='=' read -r key value; do
                case "$key" in
                    BITCOIND_DATADIR|BITCOIN_DATADIR|DATADIR)
                        BITCOIN_DATADIR="$value"
                        ;;
                    BITCOIND_CONF|BITCOIN_CONF)
                        BITCOIN_CONF="$value"
                        ;;
                esac
            done < "$env_file"
        fi

        # If we found something, break
        [[ -n "$BITCOIN_DATADIR" ]] && return 0
    done

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# BINARY DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Find bitcoin-cli binary
find_bitcoin_cli() {
    # Already found?
    [[ -n "$BITCOIN_CLI_PATH" && -x "$BITCOIN_CLI_PATH" ]] && return 0

    # Check PATH first
    local cli_in_path
    cli_in_path=$(command -v bitcoin-cli 2>/dev/null)
    if [[ -n "$cli_in_path" && -x "$cli_in_path" ]]; then
        BITCOIN_CLI_PATH="$cli_in_path"
        return 0
    fi

    # Search common locations
    for dir in "${BINARY_PATHS[@]}"; do
        if [[ -x "$dir/bitcoin-cli" ]]; then
            BITCOIN_CLI_PATH="$dir/bitcoin-cli"
            return 0
        fi
    done

    # Try locate if available
    if command -v locate &>/dev/null; then
        local found
        found=$(locate -l 1 bitcoin-cli 2>/dev/null | head -1)
        if [[ -n "$found" && -x "$found" ]]; then
            BITCOIN_CLI_PATH="$found"
            return 0
        fi
    fi

    return 1
}

# Get version from binary
get_bitcoin_version() {
    if [[ -n "$BITCOIN_CLI_PATH" && -x "$BITCOIN_CLI_PATH" ]]; then
        BITCOIN_VERSION=$("$BITCOIN_CLI_PATH" --version 2>/dev/null | head -1 | grep -oP 'v[\d.]+' || echo "unknown")
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATADIR DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Validate a datadir looks like a Bitcoin Core datadir
validate_datadir() {
    local dir="$1"

    [[ ! -d "$dir" ]] && return 1

    # Check for typical Bitcoin Core files/folders
    # At minimum should have blocks/ or bitcoin.conf
    if [[ -d "$dir/blocks" ]] || [[ -f "$dir/bitcoin.conf" ]] || [[ -f "$dir/.cookie" ]]; then
        return 0
    fi

    # Check for testnet/signet/regtest subdirs
    for subdir in testnet3 signet regtest; do
        if [[ -d "$dir/$subdir/blocks" ]]; then
            return 0
        fi
    done

    return 1
}

# Find datadir if not already known
find_datadir() {
    # Already found?
    if [[ -n "$BITCOIN_DATADIR" ]] && validate_datadir "$BITCOIN_DATADIR"; then
        return 0
    fi

    # Check default first
    if validate_datadir "$HOME/.bitcoin"; then
        BITCOIN_DATADIR="$HOME/.bitcoin"
        return 0
    fi

    # Check candidate locations
    for dir in "${DATADIR_CANDIDATES[@]}"; do
        if validate_datadir "$dir"; then
            BITCOIN_DATADIR="$dir"
            return 0
        fi
    done

    # Check mounted drives
    for mount in /mnt/* /media/*/* /data/*; do
        if [[ -d "$mount" ]]; then
            for subdir in bitcoin .bitcoin bitcoind; do
                if validate_datadir "$mount/$subdir"; then
                    BITCOIN_DATADIR="$mount/$subdir"
                    return 0
                fi
            done
        fi
    done 2>/dev/null

    return 1
}

# Determine network subdirectory
get_network_datadir() {
    local base="$1"
    local network="$2"

    case "$network" in
        test|testnet)
            echo "$base/testnet3"
            ;;
        signet)
            echo "$base/signet"
            ;;
        regtest)
            echo "$base/regtest"
            ;;
        *)
            echo "$base"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG FILE DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Find and parse bitcoin.conf
find_and_parse_conf() {
    # If conf already set, validate it
    if [[ -n "$BITCOIN_CONF" && -f "$BITCOIN_CONF" ]]; then
        parse_conf_file "$BITCOIN_CONF"
        return 0
    fi

    # Look in datadir
    if [[ -n "$BITCOIN_DATADIR" && -f "$BITCOIN_DATADIR/bitcoin.conf" ]]; then
        BITCOIN_CONF="$BITCOIN_DATADIR/bitcoin.conf"
        parse_conf_file "$BITCOIN_CONF"
        return 0
    fi

    # Check common system locations
    for conf in /etc/bitcoin/bitcoin.conf /etc/bitcoind/bitcoin.conf; do
        if [[ -f "$conf" ]]; then
            BITCOIN_CONF="$conf"
            parse_conf_file "$BITCOIN_CONF"
            return 0
        fi
    done

    return 1
}

# Parse bitcoin.conf for RPC settings
parse_conf_file() {
    local conf="$1"

    [[ ! -f "$conf" ]] && return 1

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        case "$key" in
            datadir)
                [[ -z "$BITCOIN_DATADIR" ]] && BITCOIN_DATADIR="$value"
                ;;
            testnet)
                [[ "$value" == "1" ]] && BITCOIN_NETWORK="test" && BITCOIN_RPC_PORT="18332"
                ;;
            signet)
                [[ "$value" == "1" ]] && BITCOIN_NETWORK="signet" && BITCOIN_RPC_PORT="38332"
                ;;
            regtest)
                [[ "$value" == "1" ]] && BITCOIN_NETWORK="regtest" && BITCOIN_RPC_PORT="18443"
                ;;
            rpcuser)
                BITCOIN_RPC_USER="$value"
                ;;
            rpcpassword)
                BITCOIN_RPC_PASS="$value"
                ;;
            rpcport)
                BITCOIN_RPC_PORT="$value"
                ;;
            rpcbind)
                # First rpcbind is typically the primary
                [[ -z "$BITCOIN_RPC_HOST" || "$BITCOIN_RPC_HOST" == "127.0.0.1" ]] && BITCOIN_RPC_HOST="$value"
                ;;
            rpccookiefile)
                BITCOIN_COOKIE_PATH="$value"
                ;;
        esac
    done < "$conf"

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# COOKIE AUTH
# ═══════════════════════════════════════════════════════════════════════════════

# Find and read .cookie file
find_cookie() {
    # If cookie path explicitly set, use it
    if [[ -n "$BITCOIN_COOKIE_PATH" && -f "$BITCOIN_COOKIE_PATH" ]]; then
        return 0
    fi

    # Determine effective datadir (with network subdir)
    local effective_datadir
    effective_datadir=$(get_network_datadir "$BITCOIN_DATADIR" "$BITCOIN_NETWORK")

    # Check for .cookie
    if [[ -f "$effective_datadir/.cookie" ]]; then
        BITCOIN_COOKIE_PATH="$effective_datadir/.cookie"
        return 0
    fi

    # Also check base datadir for mainnet
    if [[ -f "$BITCOIN_DATADIR/.cookie" ]]; then
        BITCOIN_COOKIE_PATH="$BITCOIN_DATADIR/.cookie"
        return 0
    fi

    return 1
}

# Read cookie auth credentials
read_cookie_auth() {
    [[ ! -f "$BITCOIN_COOKIE_PATH" ]] && return 1

    local cookie
    cookie=$(cat "$BITCOIN_COOKIE_PATH" 2>/dev/null) || return 1

    # Cookie format is __cookie__:random_string
    BITCOIN_RPC_USER="${cookie%%:*}"
    BITCOIN_RPC_PASS="${cookie#*:}"

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# RPC VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

# Test RPC connection
test_rpc_connection() {
    [[ -z "$BITCOIN_CLI_PATH" || ! -x "$BITCOIN_CLI_PATH" ]] && return 1

    local cli_args=()

    # Add datadir if set
    [[ -n "$BITCOIN_DATADIR" ]] && cli_args+=("-datadir=$BITCOIN_DATADIR")

    # Add conf if set
    [[ -n "$BITCOIN_CONF" ]] && cli_args+=("-conf=$BITCOIN_CONF")

    # Add network flag if not mainnet
    case "$BITCOIN_NETWORK" in
        test)   cli_args+=("-testnet") ;;
        signet) cli_args+=("-signet") ;;
        regtest) cli_args+=("-regtest") ;;
    esac

    # Add RPC credentials if using user/pass (not cookie)
    if [[ -n "$BITCOIN_RPC_USER" && -n "$BITCOIN_RPC_PASS" && -z "$BITCOIN_COOKIE_PATH" ]]; then
        cli_args+=("-rpcuser=$BITCOIN_RPC_USER")
        cli_args+=("-rpcpassword=$BITCOIN_RPC_PASS")
    fi

    # Try a simple RPC call
    local result
    result=$("$BITCOIN_CLI_PATH" "${cli_args[@]}" getnetworkinfo 2>&1)

    if [[ $? -eq 0 ]] && [[ "$result" != *"error"* ]]; then
        # Extract version from response
        if command -v jq &>/dev/null; then
            local subversion
            subversion=$(echo "$result" | jq -r '.subversion // empty' 2>/dev/null)
            [[ -n "$subversion" ]] && BITCOIN_VERSION="$subversion"
        fi
        return 0
    fi

    return 1
}

# Build the full bitcoin-cli command with proper arguments
get_cli_command() {
    local cmd="$BITCOIN_CLI_PATH"

    [[ -n "$BITCOIN_DATADIR" ]] && cmd+=" -datadir=$BITCOIN_DATADIR"
    [[ -n "$BITCOIN_CONF" ]] && cmd+=" -conf=$BITCOIN_CONF"

    case "$BITCOIN_NETWORK" in
        test)   cmd+=" -testnet" ;;
        signet) cmd+=" -signet" ;;
        regtest) cmd+=" -regtest" ;;
    esac

    echo "$cmd"
}

# ═══════════════════════════════════════════════════════════════════════════════
# EXHAUSTIVE SEARCH
# ═══════════════════════════════════════════════════════════════════════════════

# Deep search for Bitcoin Core (slow but thorough)
exhaustive_search() {
    msg_warn "Starting exhaustive search (this may take a while)..."

    # Search for bitcoin.conf files
    local conf_files
    conf_files=$(find / -name "bitcoin.conf" -type f 2>/dev/null | head -20)

    for conf in $conf_files; do
        local potential_datadir
        potential_datadir=$(dirname "$conf")

        if validate_datadir "$potential_datadir"; then
            BITCOIN_DATADIR="$potential_datadir"
            BITCOIN_CONF="$conf"
            BITCOIN_DETECTION_METHOD="exhaustive"
            return 0
        fi
    done

    # Search for blocks directories
    local block_dirs
    block_dirs=$(find / -type d -name "blocks" 2>/dev/null | head -20)

    for blocks in $block_dirs; do
        local potential_datadir
        potential_datadir=$(dirname "$blocks")

        # Check if this looks like a Bitcoin datadir
        if [[ -d "$potential_datadir/chainstate" ]] || [[ -f "$potential_datadir/bitcoin.conf" ]]; then
            BITCOIN_DATADIR="$potential_datadir"
            BITCOIN_DETECTION_METHOD="exhaustive"
            return 0
        fi
    done

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN DETECTION FUNCTION
# ═══════════════════════════════════════════════════════════════════════════════

# Run full detection with UI
run_detection() {
    local force_new="${1:-0}"
    local total_steps=7
    local current_step=0

    print_section "Bitcoin Core Detection"

    # Step 0: Check cache (unless forced)
    if [[ "$force_new" != "1" ]]; then
        ((current_step++))
        print_step $current_step $total_steps "Checking cached configuration"
        print_dots "Loading cache" 2

        if load_cache && test_rpc_connection; then
            msg_ok "Using cached configuration (validated)"
            BITCOIN_DETECTION_METHOD="cache"
            display_detection_results
            print_section_end
            return 0
        else
            msg_info "Cache invalid or missing, running fresh detection"
        fi
    fi

    # Step 1: Detect running process
    ((current_step++))
    print_step $current_step $total_steps "Checking for running bitcoind process"
    start_spinner "Scanning processes"

    if detect_running_process; then
        stop_spinner 0 "Found running bitcoind"
    else
        stop_spinner 1 "No running bitcoind found"
    fi

    # Step 2: Check systemd services
    ((current_step++))
    print_step $current_step $total_steps "Checking systemd services"
    start_spinner "Querying systemd"

    if detect_systemd_service; then
        stop_spinner 0 "Found Bitcoin systemd service"
    else
        stop_spinner 1 "No Bitcoin systemd service found"
    fi

    # Step 3: Find bitcoin-cli
    ((current_step++))
    print_step $current_step $total_steps "Locating bitcoin-cli binary"
    start_spinner "Searching for binary"

    if find_bitcoin_cli; then
        stop_spinner 0 "Found: $BITCOIN_CLI_PATH"
        get_bitcoin_version
    else
        stop_spinner 1 "bitcoin-cli not found in common locations"
    fi

    # Step 4: Find datadir
    ((current_step++))
    print_step $current_step $total_steps "Locating data directory"
    start_spinner "Searching directories"

    if find_datadir; then
        stop_spinner 0 "Found: $BITCOIN_DATADIR"
    else
        stop_spinner 1 "Could not locate datadir"
    fi

    # Step 5: Find and parse config
    ((current_step++))
    print_step $current_step $total_steps "Reading configuration"
    start_spinner "Parsing config"

    find_and_parse_conf
    find_cookie

    if [[ -n "$BITCOIN_COOKIE_PATH" ]]; then
        read_cookie_auth
        stop_spinner 0 "Using cookie authentication"
    elif [[ -n "$BITCOIN_RPC_USER" ]]; then
        stop_spinner 0 "Using user/password authentication"
    else
        stop_spinner 1 "No RPC auth found"
    fi

    # Step 6: Validate RPC connection
    ((current_step++))
    print_step $current_step $total_steps "Validating RPC connection"
    start_spinner "Testing connection"

    if test_rpc_connection; then
        stop_spinner 0 "RPC connection successful!"
        save_cache
    else
        stop_spinner 1 "RPC connection failed"

        # Offer exhaustive search
        echo ""
        if prompt_yn "Run exhaustive search? (slow but thorough)"; then
            if exhaustive_search; then
                find_and_parse_conf
                find_cookie
                [[ -n "$BITCOIN_COOKIE_PATH" ]] && read_cookie_auth

                if test_rpc_connection; then
                    msg_ok "Found Bitcoin Core via exhaustive search!"
                    save_cache
                fi
            fi
        fi
    fi

    display_detection_results
    print_section_end

    # Return success if we have a working CLI
    [[ -n "$BITCOIN_CLI_PATH" && -x "$BITCOIN_CLI_PATH" ]]
}

# Display detection results
display_detection_results() {
    echo ""
    echo -e "${T_PRIMARY}${BOX_H}${BOX_H}${BOX_H} Detection Results ${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${BOX_H}${RST}"
    echo ""

    print_kv "Detection Method" "${BITCOIN_DETECTION_METHOD:-unknown}" 20
    print_kv "Bitcoin CLI" "${BITCOIN_CLI_PATH:-not found}" 20
    print_kv "Version" "${BITCOIN_VERSION:-unknown}" 20
    print_kv "Data Directory" "${BITCOIN_DATADIR:-not found}" 20
    print_kv "Config File" "${BITCOIN_CONF:-default}" 20
    print_kv "Network" "${BITCOIN_NETWORK}" 20
    print_kv "RPC Host" "${BITCOIN_RPC_HOST}:${BITCOIN_RPC_PORT}" 20

    if [[ -n "$BITCOIN_COOKIE_PATH" ]]; then
        print_kv "Auth Method" "Cookie ($BITCOIN_COOKIE_PATH)" 20
    elif [[ -n "$BITCOIN_RPC_USER" ]]; then
        print_kv "Auth Method" "User/Password (rpcuser: $BITCOIN_RPC_USER)" 20
    else
        print_kv "Auth Method" "None configured" 20
    fi

    if [[ "$BITCOIN_RUNNING" -eq 1 ]]; then
        echo ""
        echo -e "  ${T_SUCCESS}${SYM_CHECK} Bitcoin Core is running${RST}"
    fi

    echo ""
    echo -e "${T_DIM}CLI Command: $(get_cli_command)${RST}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MANUAL CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Interactive manual configuration
manual_configure() {
    print_section "Manual Configuration"

    # Get bitcoin-cli path
    local cli_input
    cli_input=$(prompt_text "Path to bitcoin-cli" "$(command -v bitcoin-cli 2>/dev/null)")
    if [[ -n "$cli_input" && -x "$cli_input" ]]; then
        BITCOIN_CLI_PATH="$cli_input"
    else
        msg_err "Invalid bitcoin-cli path"
        print_section_end
        return 1
    fi

    # Get datadir
    local datadir_input
    datadir_input=$(prompt_text "Data directory" "$HOME/.bitcoin")
    if [[ -d "$datadir_input" ]]; then
        BITCOIN_DATADIR="$datadir_input"
    else
        msg_warn "Directory does not exist: $datadir_input"
        if ! prompt_yn "Continue anyway?"; then
            print_section_end
            return 1
        fi
        BITCOIN_DATADIR="$datadir_input"
    fi

    # Get network
    local network_choice
    network_choice=$(prompt_select "Select network:" "mainnet" "testnet" "signet" "regtest")
    case "$network_choice" in
        testnet)  BITCOIN_NETWORK="test"; BITCOIN_RPC_PORT="18332" ;;
        signet)   BITCOIN_NETWORK="signet"; BITCOIN_RPC_PORT="38332" ;;
        regtest)  BITCOIN_NETWORK="regtest"; BITCOIN_RPC_PORT="18443" ;;
        *)        BITCOIN_NETWORK="main"; BITCOIN_RPC_PORT="8332" ;;
    esac

    # Find conf and cookie
    find_and_parse_conf
    find_cookie
    [[ -n "$BITCOIN_COOKIE_PATH" ]] && read_cookie_auth

    # Test the configuration
    echo ""
    start_spinner "Testing configuration"
    if test_rpc_connection; then
        stop_spinner 0 "Configuration valid!"
        save_cache
        display_detection_results
        print_section_end
        return 0
    else
        stop_spinner 1 "Configuration test failed"

        # Offer to enter RPC credentials manually
        if prompt_yn "Enter RPC credentials manually?"; then
            BITCOIN_RPC_USER=$(prompt_text "RPC username")
            echo -n "RPC password: "
            read -rs BITCOIN_RPC_PASS
            echo ""

            if test_rpc_connection; then
                msg_ok "Configuration valid with manual credentials!"
                save_cache
                display_detection_results
                print_section_end
                return 0
            fi
        fi

        print_section_end
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

# Main detection entry point
# Usage: detect_bitcoin_core [--force] [--manual] [--quiet]
detect_bitcoin_core() {
    local force=0
    local manual=0
    local quiet=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)  force=1 ;;
            --manual) manual=1 ;;
            --quiet)  quiet=1 ;;
            *)        ;;
        esac
        shift
    done

    if [[ "$manual" -eq 1 ]]; then
        manual_configure
    else
        run_detection "$force"
    fi
}

# Export functions for use by other scripts
export -f detect_bitcoin_core
export -f get_cli_command
export -f test_rpc_connection
