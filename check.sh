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
    local known_endpoint="api.$base_domain"  # Use known working endpoint
    local timeout=5
    local success=true
    local error_msg=""
    
    log "Testing wildcard domain: *.$base_domain"
    
    # 1. Check DNS resolution using both IPv4 and IPv6
    if ! (host -t A "$known_endpoint" >/dev/null 2>&1 || host -t AAAA "$known_endpoint" >/dev/null 2>&1); then
        success=false
        error_msg="DNS resolution failed"
        log "DNS resolution failed for $known_endpoint"
    fi
    
    # 2. Test connection to known endpoint with simple HTTPS check
    if ! curl --max-time $timeout -sI "https://$known_endpoint" &>/dev/null; then
        success=false
        error_msg="Cannot connect to $known_endpoint"
        log "Connection failed to $known_endpoint"
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

check_dns_resolvers() {
    log "Checking DNS resolver connectivity"
    local ipv4_servers=("8.8.8.8" "8.8.4.4")
    local ipv6_servers=("2001:4860:4860::8888" "2001:4860:4860::8844")
    local ipv4_ok=false
    local ipv6_ok=false
    local has_ipv6=false
    
    # Check if system has IPv6 connectivity
    if ip addr show | grep -q "inet6"; then
        has_ipv6=true
        log "IPv6 is supported on this system"
    else
        log "IPv6 is not supported on this system"
    fi
    
    # Check IPv4 DNS servers
    for server in "${ipv4_servers[@]}"; do
        if ping -c 1 -W 2 "$server" >/dev/null 2>&1; then
            ipv4_ok=true
            log "Successfully reached IPv4 DNS server: $server"
            break
        fi
    done
    
    # Only check IPv6 if system supports it
    if [ "$has_ipv6" = true ]; then
        for server in "${ipv6_servers[@]}"; do
            if ping -c 1 -W 2 "$server" >/dev/null 2>&1; then
                ipv6_ok=true
                log "Successfully reached IPv6 DNS server: $server"
                break
            fi
        done
    fi
    
    # Determine status
    if [ "$ipv4_ok" = true ]; then
        print_status "DNS resolver access" "OK" "$CHECK_MARK"
        log "DNS resolver check passed (IPv4 working)"
    elif [ "$has_ipv6" = true ] && [ "$ipv6_ok" = true ]; then
        print_status "DNS resolver access" "OK" "$CHECK_MARK"
        log "DNS resolver check passed (IPv6 working)"
    else
        print_status "DNS resolver access" "FAILED" "$CROSS_MARK" \
            "Cannot reach any DNS resolvers. Check your internet connection."
        log "Failed to reach any DNS resolvers"
        return 1
    fi
}

check_proxy() {
    local proxy_vars=("http_proxy" "https_proxy" "HTTP_PROXY" "HTTPS_PROXY")
    local proxy_detected=false
    
    log "Checking for proxy configuration"
    
    # Check environment variables
    for var in "${proxy_vars[@]}"; do
        if [ -n "${!var}" ]; then
            proxy_detected=true
            print_status "Proxy detected ($var)" "WARNING" "$WARNING" \
                "Environment proxy might affect connectivity. Value: ${!var}"
            log "Proxy found: $var=${!var}"
        fi
    done
    
    # Check system proxy settings on macOS
    if [ "$(uname)" == "Darwin" ]; then
        local proxy_enabled proxy_server proxy_port
        proxy_enabled=$(networksetup -getwebproxy Wi-Fi | grep "^Enabled:" | awk '{print $2}')
        proxy_server=$(networksetup -getwebproxy Wi-Fi | grep "^Server:" | awk '{print $2}')
        proxy_port=$(networksetup -getwebproxy Wi-Fi | grep "^Port:" | awk '{print $2}')
        
        if [ "$proxy_enabled" == "Yes" ]; then
            proxy_detected=true
            print_status "System proxy enabled (Wi-Fi)" "WARNING" "$WARNING" \
                "System proxy configured: $proxy_server:$proxy_port"
            log "System proxy enabled on Wi-Fi: $proxy_server:$proxy_port"
        fi
    fi
    
    if [ "$proxy_detected" = false ]; then
        print_status "No proxy detected" "OK" "$CHECK_MARK"
        log "No proxy configuration found"
    fi
}

check_vpn() {
    log "Checking for VPN connection"
    
    # Check for VPN interfaces and identify them
    local vpn_interfaces=""
    local tailscale_active=false
    
    # Check for Tailscale
    if ifconfig | grep -q "utun" && ifconfig | grep -q "100."; then
        tailscale_active=true
        vpn_interfaces="Tailscale"
        print_status "Tailscale VPN detected" "OK" "$CHECK_MARK" \
            "Tailscale is active but should not affect Windsurf connectivity"
        log "Tailscale VPN detected and marked as safe"
        return 0
    fi
    
    # Check for other VPN interfaces
    if ifconfig | grep -q "tun\|tap"; then
        vpn_interfaces="$(ifconfig | grep -E "^(tun|tap)" | cut -d: -f1 | tr '\n' ' ')"
        print_status "VPN connection detected" "WARNING" "$WARNING" \
            "Active VPN interfaces: $vpn_interfaces. If you experience issues, try disconnecting temporarily."
        log "VPN interfaces detected: $vpn_interfaces"
    else
        print_status "Network configuration" "OK" "$CHECK_MARK"
        log "No VPN interfaces detected"
    fi
}

check_browser_redirect() {
    log "Checking browser redirect capabilities"
    local success=true
    local messages=()
    
    # 1. Check localhost resolution (required for OAuth callback)
    if ! ping -c 1 localhost >/dev/null 2>&1; then
        success=false
        messages+=("Cannot resolve localhost - check your /etc/hosts file")
        log "Failed to resolve localhost"
    fi
    
    # 2. Check if a browser can be launched
    if ! command -v open >/dev/null 2>&1; then
        success=false
        messages+=("Cannot find 'open' command - browser-based auth will not work")
        log "Cannot find 'open' command for launching browser"
    fi
    
    # 3. Check port 8000 (Windsurf's default OAuth callback port)
    if lsof -i :8000 >/dev/null 2>&1; then
        if lsof -i :8000 2>/dev/null | grep -q "windsurf\|electron"; then
            log "Port 8000 is in use by Windsurf (expected)"
        else
            success=false
            messages+=("Port 8000 is in use by another application")
            log "Port 8000 is in use by another application"
        fi
    else
        # Try to bind to the port briefly to test availability
        if ! (nc -l localhost 8000 </dev/null >/dev/null 2>&1 & pid=$!; sleep 0.1; kill $pid 2>/dev/null) &>/dev/null; then
            success=false
            messages+=("Cannot bind to port 8000 - check permissions or other applications")
            log "Failed to bind to port 8000"
        fi
    fi
    
    # Report status
    if [ "$success" = true ]; then
        print_status "Browser redirect capability" "OK" "$CHECK_MARK" \
            "All requirements for browser-based authentication are met"
        log "Browser redirect check passed"
    else
        local help_msg
        help_msg=$(printf "%s\n    ${BLUE}${INFO} %s${NC}" "${messages[0]}" "${messages[@]:1}" | sed 's/^/    /')
        print_status "Browser redirect capability" "FAILED" "$CROSS_MARK" \
            "$(echo -e "$help_msg")"
        log "Browser redirect check failed: ${messages[*]}"
        return 1
    fi
}

main() {
    # Skip main when testing
    if [ "${TESTING:-}" = true ]; then
        return 0
    fi
    
    # Clear previous log
    > "$LOG_FILE"
    log "Starting Windsurf connection test"
    
    # Print title
    printf "${BOLD}🌊 Windsurf Connection Checker${NC}\n"
    printf "${BLUE}%s${NC}\n" "$(printf '=%.0s' {1..60})"
    
    # Domain connectivity
    print_header "Domain Connectivity" "$GLOBE"
    check_dns_resolvers
    check_wildcard_domain
    
    # Network configuration
    print_header "Network Configuration" "$LOCK"
    check_proxy
    check_vpn
    
    # Browser redirect
    print_header "Browser Redirect" "$BROWSER"
    check_browser_redirect
    
    printf "\n${BLUE}Detailed logs available in: ${NC}${LOG_FILE}\n\n"
}

# Only run main if script is executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main
fi

# Redirect stderr to hide nc termination messages
exec 2>/dev/null
