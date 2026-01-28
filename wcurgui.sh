#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  WCURGUI - Bitcoin Core GUI Dashboard
#  A terminal-based monitoring and management interface for Bitcoin Core
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Get the directory where this script lives
WCURGUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WCURGUI_DIR

# Source libraries
source "$WCURGUI_DIR/lib/ui.sh"
source "$WCURGUI_DIR/lib/prereqs.sh"
source "$WCURGUI_DIR/lib/detection.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# VERSION AND CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

VERSION="0.1.0"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wcurgui"

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND LINE ARGUMENTS
# ═══════════════════════════════════════════════════════════════════════════════

FORCE_DETECT=0
MANUAL_CONFIG=0
SKIP_PREREQS=0
SHOW_HELP=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                SHOW_HELP=1
                ;;
            -v|--version)
                echo "wcurgui version $VERSION"
                exit 0
                ;;
            --force-detect)
                FORCE_DETECT=1
                ;;
            --manual)
                MANUAL_CONFIG=1
                ;;
            --skip-prereqs)
                SKIP_PREREQS=1
                ;;
            --reset)
                reset_config
                exit 0
                ;;
            *)
                msg_err "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

show_help() {
    echo ""
    echo -e "${BWHITE}WCURGUI${RST} - Bitcoin Core GUI Dashboard v${VERSION}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  -v, --version      Show version"
    echo "  --force-detect     Force re-detection (ignore cache)"
    echo "  --manual           Manually configure Bitcoin Core connection"
    echo "  --skip-prereqs     Skip prerequisite checks"
    echo "  --reset            Reset all cached configuration"
    echo ""
}

reset_config() {
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        msg_ok "Configuration reset"
    else
        msg_info "No configuration to reset"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════════════

show_banner() {
    clear
    echo ""
    echo -e "${T_PRIMARY}"
    cat << 'EOF'
 ██╗    ██╗ ██████╗██╗   ██╗██████╗  ██████╗ ██╗   ██╗██╗
 ██║    ██║██╔════╝██║   ██║██╔══██╗██╔════╝ ██║   ██║██║
 ██║ █╗ ██║██║     ██║   ██║██████╔╝██║  ███╗██║   ██║██║
 ██║███╗██║██║     ██║   ██║██╔══██╗██║   ██║██║   ██║██║
 ╚███╔███╔╝╚██████╗╚██████╔╝██║  ██║╚██████╔╝╚██████╔╝██║
  ╚══╝╚══╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝
EOF
    echo -e "${RST}"
    echo -e "  ${T_DIM}Bitcoin Core GUI Dashboard${RST}          ${T_DIM}v${VERSION}${RST}"
    echo ""
    print_divider "═" 60
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════

show_main_menu() {
    echo ""
    echo -e "${T_SECONDARY}${BOLD}Main Menu${RST}"
    echo ""
    echo -e "  ${T_INFO}1)${RST} View Node Status"
    echo -e "  ${T_INFO}2)${RST} View Peer Information"
    echo -e "  ${T_INFO}3)${RST} View Mempool Stats"
    echo -e "  ${T_INFO}4)${RST} View Blockchain Info"
    echo -e "  ${T_INFO}5)${RST} Re-detect Bitcoin Core"
    echo -e "  ${T_INFO}6)${RST} Manual Configuration"
    echo ""
    echo -e "  ${T_WARN}q)${RST} Quit"
    echo ""

    local choice
    echo -en "${T_DIM}Enter choice:${RST} "
    read -r choice

    case "$choice" in
        1) show_node_status ;;
        2) show_peer_info ;;
        3) show_mempool_stats ;;
        4) show_blockchain_info ;;
        5)
            detect_bitcoin_core --force
            press_enter_to_continue
            ;;
        6)
            detect_bitcoin_core --manual
            press_enter_to_continue
            ;;
        q|Q) exit 0 ;;
        *) msg_warn "Invalid choice" ;;
    esac
}

press_enter_to_continue() {
    echo ""
    echo -en "${T_DIM}Press Enter to continue...${RST}"
    read -r
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS DISPLAYS (Placeholder implementations)
# ═══════════════════════════════════════════════════════════════════════════════

show_node_status() {
    print_header "Node Status"

    local cli_cmd
    cli_cmd=$(get_cli_command)

    # Get network info
    start_spinner "Fetching node status"
    local network_info
    network_info=$($cli_cmd getnetworkinfo 2>&1)
    local blockchain_info
    blockchain_info=$($cli_cmd getblockchaininfo 2>&1)
    stop_spinner 0 "Data retrieved"

    if command -v jq &>/dev/null; then
        echo ""
        echo -e "${T_SECONDARY}Network Information${RST}"
        print_kv "Version" "$(echo "$network_info" | jq -r '.subversion')" 25
        print_kv "Protocol Version" "$(echo "$network_info" | jq -r '.protocolversion')" 25
        print_kv "Connections" "$(echo "$network_info" | jq -r '.connections')" 25
        print_kv "Networks Active" "$(echo "$network_info" | jq -r '[.networks[] | select(.reachable==true) | .name] | join(", ")')" 25

        echo ""
        echo -e "${T_SECONDARY}Blockchain Status${RST}"
        print_kv "Chain" "$(echo "$blockchain_info" | jq -r '.chain')" 25
        print_kv "Blocks" "$(echo "$blockchain_info" | jq -r '.blocks')" 25
        print_kv "Headers" "$(echo "$blockchain_info" | jq -r '.headers')" 25
        print_kv "Verification Progress" "$(echo "$blockchain_info" | jq -r '.verificationprogress * 100 | . * 100 | floor / 100')%" 25
        print_kv "Size on Disk" "$(echo "$blockchain_info" | jq -r '.size_on_disk / 1073741824 | . * 100 | floor / 100') GB" 25

        local pruned
        pruned=$(echo "$blockchain_info" | jq -r '.pruned')
        if [[ "$pruned" == "true" ]]; then
            print_kv "Pruned" "Yes ($(echo "$blockchain_info" | jq -r '.pruneheight') blocks retained)" 25
        else
            print_kv "Pruned" "No (full node)" 25
        fi
    else
        echo "$network_info"
        echo "$blockchain_info"
    fi

    press_enter_to_continue
}

show_peer_info() {
    print_header "Peer Information"

    local cli_cmd
    cli_cmd=$(get_cli_command)

    start_spinner "Fetching peer data"
    local peer_info
    peer_info=$($cli_cmd getpeerinfo 2>&1)
    stop_spinner 0 "Data retrieved"

    if command -v jq &>/dev/null; then
        local peer_count
        peer_count=$(echo "$peer_info" | jq 'length')

        echo ""
        echo -e "${T_SECONDARY}Connected Peers: ${BWHITE}${peer_count}${RST}"
        echo ""

        # Table header
        printf "${T_DIM}%-45s %-10s %-12s %-8s${RST}\n" "Address" "Direction" "Ping (ms)" "Version"
        print_divider "─" 80

        # Show each peer (limit to first 20 for display)
        echo "$peer_info" | jq -r '.[:20][] | "\(.addr)\t\(if .inbound then "inbound" else "outbound" end)\t\((.pingtime // 0) * 1000 | floor)\t\(.subver)"' | \
        while IFS=$'\t' read -r addr dir ping ver; do
            printf "%-45s %-10s %-12s %-8s\n" "$addr" "$dir" "${ping}ms" "$ver"
        done

        if [[ $peer_count -gt 20 ]]; then
            echo ""
            msg_info "Showing first 20 of $peer_count peers"
        fi
    else
        echo "$peer_info"
    fi

    press_enter_to_continue
}

show_mempool_stats() {
    print_header "Mempool Statistics"

    local cli_cmd
    cli_cmd=$(get_cli_command)

    start_spinner "Fetching mempool data"
    local mempool_info
    mempool_info=$($cli_cmd getmempoolinfo 2>&1)
    stop_spinner 0 "Data retrieved"

    if command -v jq &>/dev/null; then
        echo ""
        print_kv "Transactions" "$(echo "$mempool_info" | jq -r '.size')" 25
        print_kv "Memory Usage" "$(echo "$mempool_info" | jq -r '.bytes / 1048576 | . * 100 | floor / 100') MB" 25
        print_kv "Max Memory" "$(echo "$mempool_info" | jq -r '.maxmempool / 1048576 | floor') MB" 25
        print_kv "Memory Usage %" "$(echo "$mempool_info" | jq -r '(.bytes / .maxmempool * 100) | . * 100 | floor / 100')%" 25
        print_kv "Min Fee Rate" "$(echo "$mempool_info" | jq -r '.mempoolminfee * 100000 | floor / 100') sat/vB" 25
        print_kv "Total Fee" "$(echo "$mempool_info" | jq -r '.total_fee // "N/A"') BTC" 25
    else
        echo "$mempool_info"
    fi

    press_enter_to_continue
}

show_blockchain_info() {
    print_header "Blockchain Information"

    local cli_cmd
    cli_cmd=$(get_cli_command)

    start_spinner "Fetching blockchain data"
    local blockchain_info
    blockchain_info=$($cli_cmd getblockchaininfo 2>&1)
    local best_block_hash
    best_block_hash=$(echo "$blockchain_info" | jq -r '.bestblockhash' 2>/dev/null)
    local block_header
    if [[ -n "$best_block_hash" && "$best_block_hash" != "null" ]]; then
        block_header=$($cli_cmd getblockheader "$best_block_hash" 2>&1)
    fi
    stop_spinner 0 "Data retrieved"

    if command -v jq &>/dev/null; then
        echo ""
        echo -e "${T_SECONDARY}Chain Status${RST}"
        print_kv "Chain" "$(echo "$blockchain_info" | jq -r '.chain')" 25
        print_kv "Current Height" "$(echo "$blockchain_info" | jq -r '.blocks')" 25
        print_kv "Difficulty" "$(echo "$blockchain_info" | jq -r '.difficulty | . / 1000000000000 | . * 100 | floor / 100')T" 25
        print_kv "Chain Work" "$(echo "$blockchain_info" | jq -r '.chainwork')" 25

        if [[ -n "$block_header" ]]; then
            echo ""
            echo -e "${T_SECONDARY}Latest Block${RST}"
            print_kv "Hash" "$(echo "$block_header" | jq -r '.hash')" 25
            local block_time
            block_time=$(echo "$block_header" | jq -r '.time')
            local formatted_time
            formatted_time=$(date -d "@$block_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$block_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$block_time")
            print_kv "Block Time" "$formatted_time" 25

            local time_ago
            local now
            now=$(date +%s)
            local diff=$((now - block_time))
            if [[ $diff -lt 60 ]]; then
                time_ago="${diff} seconds ago"
            elif [[ $diff -lt 3600 ]]; then
                time_ago="$((diff / 60)) minutes ago"
            else
                time_ago="$((diff / 3600)) hours ago"
            fi
            print_kv "Time Since Block" "$time_ago" 25
            print_kv "Confirmations" "$(echo "$block_header" | jq -r '.confirmations')" 25
        fi

        # Show warnings if any
        local warnings
        warnings=$(echo "$blockchain_info" | jq -r '.warnings // empty')
        if [[ -n "$warnings" && "$warnings" != "" ]]; then
            echo ""
            msg_warn "Warnings: $warnings"
        fi
    else
        echo "$blockchain_info"
    fi

    press_enter_to_continue
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    parse_args "$@"

    if [[ $SHOW_HELP -eq 1 ]]; then
        show_help
        exit 0
    fi

    show_banner

    # Check prerequisites
    if [[ $SKIP_PREREQS -ne 1 ]]; then
        if ! run_prereq_check; then
            msg_err "Cannot continue without required prerequisites"
            exit 1
        fi
    fi

    # Detect Bitcoin Core
    local detect_args=""
    [[ $FORCE_DETECT -eq 1 ]] && detect_args="--force"
    [[ $MANUAL_CONFIG -eq 1 ]] && detect_args="--manual"

    if ! detect_bitcoin_core $detect_args; then
        echo ""
        msg_warn "Bitcoin Core not fully detected"

        if prompt_yn "Try manual configuration?"; then
            if ! detect_bitcoin_core --manual; then
                msg_err "Could not connect to Bitcoin Core"
                echo ""
                msg_info "Make sure bitcoind is running and accessible"
                msg_info "Run with --manual to configure manually"
                exit 1
            fi
        else
            msg_info "Run with --manual to configure connection"
            exit 1
        fi
    fi

    # Main loop
    while true; do
        show_main_menu
    done
}

# Run main function
main "$@"
