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
    TESTING=true
}

# Cleanup
tear_down() {
    HOME=$OLD_HOME
    rm -rf "$TEST_DIR"
}

# Helper function to extract status from output
get_status() {
    echo "$1" | grep -o "OK\|FAILED\|WARNING"
}

# DNS resolver tests
test_check_dns_resolvers_when_ipv4_works() {
    # Mock ping for IPv4 success
    mock "ping" 'case "$4" in "8.8.8.8"|"8.8.4.4") return 0;; *) return 1;; esac'
    
    # Mock ip for no IPv6
    mock "ip" "return 1"
    
    output=$(check_dns_resolvers)
    status=$(get_status "$output")
    assert_equals "OK" "$status" "DNS check should be OK when IPv4 resolvers work"
}

test_check_dns_resolvers_when_all_fail() {
    # Mock ping to fail for all
    mock "ping" "return 1"
    mock "ip" "return 1"
    
    output=$(check_dns_resolvers)
    status=$(get_status "$output")
    assert_equals "FAILED" "$status" "DNS check should fail when no resolvers work"
    assert_contains "$output" "Cannot reach any DNS resolvers" "Should show error message"
}

# Domain connectivity tests
test_check_wildcard_domain_when_working() {
    # Mock curl success
    mock "curl" "return 0"
    mock "host" "return 0"
    
    output=$(check_wildcard_domain "*.codeium.com")
    status=$(get_status "$output")
    assert_equals "OK" "$status" "Domain check should be OK when accessible"
}

test_check_wildcard_domain_when_dns_fails() {
    # Mock curl failure
    mock "curl" "return 6"  # DNS error
    mock "host" "return 1"
    
    output=$(check_wildcard_domain "*.codeium.com")
    status=$(get_status "$output")
    assert_equals "FAILED" "$status" "Domain check should fail when DNS fails"
    assert_contains "$output" "Cannot connect to api.codeium.com" "Should show DNS error message"
}

# Proxy tests
test_check_proxy_when_none_configured() {
    output=$(check_proxy)
    status=$(get_status "$output")
    assert_equals "OK" "$status" "Should detect no proxy when env vars are not set"
}

test_check_proxy_when_configured() {
    export http_proxy="http://proxy:8080"
    
    output=$(check_proxy)
    status=$(get_status "$output")
    assert_equals "WARNING" "$status" "Should show warning when proxy is configured"
    assert_contains "$output" "Value: http://proxy:8080" "Should show proxy value"
    
    unset http_proxy
}

# VPN tests
test_check_vpn_when_tailscale() {
    # Mock ifconfig to show tun0
    mock "ifconfig" 'echo "tun0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500"'
    
    output=$(check_vpn)
    status=$(get_status "$output")
    assert_equals "WARNING" "$status" "Should show warning when VPN is detected"
    assert_contains "$output" "Active VPN interfaces: tun0" "Should show VPN interface"
}

test_check_vpn_when_none() {
    # Mock ifconfig to show no VPN
    mock "ifconfig" 'echo "eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500"'
    
    output=$(check_vpn)
    status=$(get_status "$output")
    assert_equals "OK" "$status" "Should show OK when no VPN is detected"
}

# Browser redirect tests
test_check_browser_redirect_when_all_working() {
    # Mock nc to show port is free
    mock "nc" "return 1"
    
    output=$(check_browser_redirect)
    status=$(get_status "$output")
    assert_equals "OK" "$status" "Should show OK when port is available"
}

test_check_browser_redirect_when_port_in_use() {
    # Mock nc to show port is in use
    mock "nc" "return 0"
    
    output=$(check_browser_redirect)
    status=$(get_status "$output")
    assert_equals "FAILED" "$status" "Should show FAILED when port is in use"
    assert_contains "$output" "Port 8000 is in use" "Should show port in use message"
}
