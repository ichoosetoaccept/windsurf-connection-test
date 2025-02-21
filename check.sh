#!/bin/bash

# Colors for output
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[36m'
BOLD='\033[1m'
NC='\033[0m'

# Emoji (using printf to ensure proper display)
CHECK_MARK="$(printf '\xe2\x9c\x85')"
CROSS_MARK="$(printf '\xe2\x9d\x8c')"
WARNING="$(printf '\xe2\x9a\xa0\xef\xb8\x8f')"
GLOBE="$(printf '\xf0\x9f\x8c\x8e')"
LOCK="$(printf '\xf0\x9f\x94\x92')"
BROWSER="$(printf '\xf0\x9f\x8c\x90')"
INFO="$(printf '\xe2\x84\xb9\xef\xb8\x8f')"

# Configuration
REDIRECT_PORT=8000

# Log file
LOG_FILE="connection_test.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_status() {
    local message="$1"
    local status="$2"
    local emoji="$3"
    local help="$4"
    
    # Add padding to align status indicators
    printf "\n%-50s %s %s" "$message" "$status" "$emoji"
    if [ -n "$help" ]; then
        printf "\n    ${BLUE}${INFO} %s${NC}" "$help"
    fi
    printf "\n"
}

print_header() {
    local title="$1"
    local emoji="$2"
    printf "\n\n${BOLD}${BLUE}%s %s${NC}\n" "$emoji" "$title"
    printf "${BLUE}%s${NC}\n" "$(printf '=%.0s' {1..60})"
}

check_wildcard_domain() {
    local domain="$1"
    local base_domain="${domain#*.}"  # Remove first subdomain
    local test_subdomain="test-$(date +%s)"
    local timeout=5
    local success=true
    local error_msg=""
    
    log "Testing wildcard domain: *.$base_domain"
    
    # 1. Check DNS resolution
    if ! host -t A "$base_domain" >/dev/null 2>&1; then
        success=false
        error_msg="DNS resolution failed"
        log "DNS resolution failed for $base_domain"
    fi
    
    # 2. Check SSL certificate wildcard coverage
    if ! echo | openssl s_client -connect "$base_domain:443" -servername "$test_subdomain.$base_domain" 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
        success=false
        error_msg="SSL certificate validation failed"
        log "SSL certificate validation failed for *.$base_domain"
    fi
    
    # 3. Test connection to base domain
    if ! curl --max-time $timeout -sI "https://$base_domain" &>/dev/null; then
        success=false
        error_msg="Cannot connect to base domain"
        log "Connection failed to $base_domain"
    fi
    
    if [ "$success" = true ]; then
        print_status "Access to *.$base_domain" "OK" "$CHECK_MARK"
        log "Successfully verified access to *.$base_domain"
    else
        print_status "Access to *.$base_domain" "FAILED" "$CROSS_MARK" \
            "$error_msg. Check your DNS and firewall settings."
        log "Failed to verify access to *.$base_domain: $error_msg"
    fi
}

check_proxy() {
    local proxy_vars=("http_proxy" "https_proxy" "HTTP_PROXY" "HTTPS_PROXY")
    local proxy_detected=false
    
    log "Checking for proxy configuration"
    for var in "${proxy_vars[@]}"; do
        if [ -n "${!var}" ]; then
            proxy_detected=true
            print_status "Proxy detected ($var)" "WARNING" "$WARNING" \
                "Proxy might interfere with Windsurf connectivity. Consider disabling it temporarily."
            log "Proxy found: $var=${!var}"
        fi
    done
    
    # Check system proxy settings on macOS
    if [ "$(uname)" == "Darwin" ]; then
        local proxy_enabled
        proxy_enabled=$(networksetup -getwebproxy Wi-Fi | grep "^Enabled:" | awk '{print $2}')
        if [ "$proxy_enabled" == "Yes" ]; then
            proxy_detected=true
            print_status "System proxy enabled (Wi-Fi)" "WARNING" "$WARNING" \
                "System-wide proxy might affect connectivity. Check System Settings > Network > Wi-Fi > Proxies."
            log "System proxy enabled on Wi-Fi interface"
        fi
    fi
    
    if [ "$proxy_detected" = false ]; then
        print_status "No proxy detected" "OK" "$CHECK_MARK"
        log "No proxy configuration found"
    fi
}

check_vpn() {
    log "Checking for VPN connection"
    
    # Check for tun/tap interfaces
    if ifconfig | grep -q "tun\|tap"; then
        print_status "VPN connection detected" "WARNING" "$WARNING" \
            "VPN might interfere with Windsurf connectivity. Try disconnecting if issues persist."
        log "VPN detected: tun/tap interface found"
        return 0
    fi
    
    # Compare local and public IP
    local_ip=$(ipconfig getifaddr en0 2>/dev/null || echo "none")
    public_ip=$(curl -s https://api.ipify.org 2>/dev/null || echo "none")
    
    if [ "$local_ip" != "none" ] && [ "$public_ip" != "none" ]; then
        log "Local IP: $local_ip, Public IP: $public_ip"
        if [ "$local_ip" != "$public_ip" ]; then
            print_status "Possible VPN/NAT detected" "WARNING" "$WARNING" \
                "Network translation detected. This might affect connectivity."
        else
            print_status "No VPN detected" "OK" "$CHECK_MARK"
        fi
    else
        print_status "VPN check inconclusive" "WARNING" "$WARNING" \
            "Could not determine network configuration. Check your internet connection."
        log "Could not determine VPN status"
    fi
}

check_browser_redirect() {
    log "Checking browser redirect capabilities"
    
    # Check if required port is available
    if nc -z localhost $REDIRECT_PORT 2>/dev/null; then
        print_status "Port $REDIRECT_PORT is in use" "WARNING" "$WARNING" \
            "This port is needed for browser-based login. Try closing other applications."
        log "Port $REDIRECT_PORT is already in use"
    else
        print_status "Port $REDIRECT_PORT is available" "OK" "$CHECK_MARK"
        log "Port $REDIRECT_PORT is available for browser redirect"
    fi
    
    # Check if we can bind to localhost
    if timeout 1 nc -l localhost $REDIRECT_PORT </dev/null >/dev/null 2>&1; then
        print_status "Can bind to localhost" "OK" "$CHECK_MARK"
        log "Successfully tested localhost binding"
    else
        print_status "Cannot bind to localhost" "FAILED" "$CROSS_MARK" \
            "Unable to bind to localhost. Check if another application is using port $REDIRECT_PORT."
        log "Failed to bind to localhost"
    fi
}

main() {
    clear
    printf "${BOLD}${BLUE}🔍 Windsurf Connection Checker${NC}\n"
    printf "${BLUE}%s${NC}\n" "$(printf '=%.0s' {1..60})"
    
    # Clear previous log
    > "$LOG_FILE"
    log "Starting connection check"
    
    # Check Codeium domains
    print_header "Domain Connectivity" "$GLOBE"
    check_wildcard_domain "*.codeium.com"
    check_wildcard_domain "*.codeiumdata.com"
    
    # Check network configuration
    print_header "Network Configuration" "$LOCK"
    check_proxy
    check_vpn
    
    # Check browser redirect capability
    print_header "Browser Redirect" "$BROWSER"
    check_browser_redirect
    
    printf "\n${BLUE}Detailed logs available in:${NC} $LOG_FILE\n"
}

# Redirect stderr to hide nc termination messages
exec 2>/dev/null

main "$@"
