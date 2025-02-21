#!/usr/bin/env bash

# Test environment setup
set_up() {
    TEST_DIR=$(mktemp -d)
    OLD_HOME=$HOME
    HOME=$TEST_DIR
    mkdir -p "$TEST_DIR/.config"
    
    # Create log file
    LOG_FILE="$TEST_DIR/connection_test.log"
    touch "$LOG_FILE"

    # Source the script under test
    source ../check.sh
}

# Cleanup
tear_down() {
    HOME=$OLD_HOME
    rm -rf "$TEST_DIR"
}

# DNS resolver tests
test_check_dns_resolvers_when_ipv4_works() {
    # Mock ping for IPv4 success
    mock "ping" 'case "$4" in
        "8.8.8.8"|"8.8.4.4") return 0;;
        *) return 1;;
    esac'
    
    # Mock ip for no IPv6
    mock "ip" "return 1"
    
    output=$(check_dns_resolvers)
    assert_contains "$output" "OK" "Should show OK when IPv4 DNS works"
}

test_check_dns_resolvers_when_all_fail() {
    # Mock ping to fail for all
    mock "ping" "return 1"
    mock "ip" "return 1"
    
    output=$(check_dns_resolvers)
    assert_contains "$output" "FAILED" "Should show FAILED when no DNS resolvers work"
}

# Domain connectivity tests
test_check_wildcard_domain_when_working() {
    domain="*.codeium.com"
    # Mock successful DNS resolution
    mock "host" "return 0"
    # Mock successful HTTPS connection
    mock "curl" "return 0"
    
    output=$(check_wildcard_domain "$domain")
    assert_contains "$output" "OK" "Should show OK when domain is accessible"
}

test_check_wildcard_domain_when_dns_fails() {
    domain="*.codeium.com"
    # Mock DNS failure
    mock "host" "return 1"
    
    output=$(check_wildcard_domain "$domain")
    assert_contains "$output" "FAILED" "Should show FAILED when DNS resolution fails"
}

# Proxy tests
test_check_proxy_when_none_configured() {
    # Clear any proxy env vars
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    
    output=$(check_proxy)
    assert_contains "$output" "No proxy detected" "Should detect no proxy when env vars are not set"
}

test_check_proxy_when_configured() {
    export http_proxy="http://proxy:8080"
    
    output=$(check_proxy)
    assert_contains "$output" "Proxy detected" "Should detect proxy when env vars are set"
    
    unset http_proxy
}

# VPN tests
test_check_vpn_when_tailscale() {
    # Mock ifconfig to show Tailscale interface
    mock "ifconfig" 'echo "tailscale0: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280"'
    
    output=$(check_vpn)
    assert_contains "$output" "Tailscale VPN detected" "Should detect Tailscale VPN"
    assert_contains "$output" "OK" "Should show OK for Tailscale"
}

test_check_vpn_when_none() {
    # Mock ifconfig to show no VPN interfaces
    mock "ifconfig" 'echo "en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500"'
    
    output=$(check_vpn)
    assert_contains "$output" "No VPN detected" "Should detect no VPN"
}

# Browser redirect tests
test_check_browser_redirect_when_all_working() {
    # Mock successful localhost ping
    mock "ping" "return 0"
    # Mock port check (not in use)
    mock "lsof" "return 1"
    # Mock successful port binding
    mock "nc" "return 0"
    
    output=$(check_browser_redirect)
    assert_contains "$output" "OK" "Should show OK when all browser redirect requirements are met"
}

test_check_browser_redirect_when_port_in_use() {
    # Mock successful localhost ping
    mock "ping" "return 0"
    # Mock port in use by another app
    mock "lsof" 'echo "someapp    1234   user    7u  IPv4  12345    0t0  TCP localhost:8000"'
    
    output=$(check_browser_redirect)
    assert_contains "$output" "FAILED" "Should show FAILED when port 8000 is in use"
}
