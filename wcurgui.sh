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

VERSION="0.1.0"

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
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    show_banner

    # Check prerequisites
    if ! run_prereq_check; then
        msg_err "Cannot continue without required prerequisites"
        echo ""
        echo -en "${T_DIM}Press Enter to exit...${RST}"
        read -r
        exit 1
    fi

    # Run detection
    if ! run_detection; then
        echo ""
        msg_err "Could not detect Bitcoin Core"
        msg_info "Make sure Bitcoin Core is installed"
        echo ""
        echo -en "${T_DIM}Press Enter to exit...${RST}"
        read -r
        exit 1
    fi

    echo ""
    msg_ok "Detection complete!"
    echo ""
    echo -e "${T_DIM}Environment variables set:${RST}"
    echo -e "  ${BWHITE}\$WCURGUI_CLI_PATH${RST}   = $WCURGUI_CLI_PATH"
    echo -e "  ${BWHITE}\$WCURGUI_DATADIR${RST}    = $WCURGUI_DATADIR"
    echo -e "  ${BWHITE}\$WCURGUI_CONF${RST}       = $WCURGUI_CONF"
    echo -e "  ${BWHITE}\$WCURGUI_NETWORK${RST}    = $WCURGUI_NETWORK"
    echo -e "  ${BWHITE}\$WCURGUI_RPC_HOST${RST}   = $WCURGUI_RPC_HOST"
    echo -e "  ${BWHITE}\$WCURGUI_RPC_PORT${RST}   = $WCURGUI_RPC_PORT"
    [[ -n "$WCURGUI_COOKIE_PATH" ]] && echo -e "  ${BWHITE}\$WCURGUI_COOKIE_PATH${RST}= $WCURGUI_COOKIE_PATH"
    [[ -n "$WCURGUI_RPC_USER" ]] && echo -e "  ${BWHITE}\$WCURGUI_RPC_USER${RST}   = $WCURGUI_RPC_USER"
    echo ""
    echo -e "${T_DIM}Cache saved to: $CACHE_FILE${RST}"
    echo ""
    print_divider "═" 60
    echo ""
    echo -en "${T_INFO}Press Enter to exit...${RST}"
    read -r
}

main "$@"
