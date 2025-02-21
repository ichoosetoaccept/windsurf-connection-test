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
    assert_contains "$output" "DNS resolver access                                OK " "Should show OK when IPv4 DNS works"
}

test_check_dns_resolvers_when_all_fail() {
    # Mock ping to fail for all
    mock "ping" "return 1"
    
    output=$(check_dns_resolvers)
    assert_contains "$output" "DNS resolver access                                FAILED " "Should show FAILED when no DNS resolvers work"
    assert_contains "$output" "Cannot reach any DNS resolvers" "Should show error message"
}

# Domain connectivity tests
test_check_wildcard_domain_when_working() {
    # Mock curl success
    mock "curl" "return 0"
    
    output=$(check_wildcard_domain)
    assert_contains "$output" "Access to *.codeium.com                            OK " "Should show OK when domain is accessible"
}

test_check_wildcard_domain_when_dns_fails() {
    # Mock curl failure
    mock "curl" "return 6"  # DNS error
    
    output=$(check_wildcard_domain)
    assert_contains "$output" "Access to *.codeium.com                            FAILED " "Should show FAILED when DNS resolution fails"
    assert_contains "$output" "DNS resolution failed" "Should show DNS error message"
}

# Proxy tests
test_check_proxy_when_none_configured() {
    output=$(check_proxy)
    assert_contains "$output" "No proxy detected                                  OK " "Should detect no proxy when env vars are not set"
}

test_check_proxy_when_configured() {
    export http_proxy="http://proxy:8080"
    
    output=$(check_proxy)
    assert_contains "$output" "Proxy detected (http_proxy)                        WARNING " "Should detect proxy when env vars are set"
    assert_contains "$output" "Value: http://proxy:8080" "Should show proxy value"
    
    unset http_proxy
}

# VPN tests
test_check_vpn_when_tailscale() {
    # Mock ifconfig to show tun0
    mock "ifconfig" 'echo "tun0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500"'
    
    output=$(check_vpn)
    assert_contains "$output" "VPN detected (Tailscale)                           OK " "Should detect Tailscale VPN"
}

test_check_vpn_when_none() {
    # Mock ifconfig to show no VPN
    mock "ifconfig" 'echo "eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500"'
    
    output=$(check_vpn)
    assert_contains "$output" "No VPN detected                                    OK " "Should detect no VPN"
}

# Browser redirect tests
test_check_browser_redirect_when_all_working() {
    # Mock nc to show port is free
    mock "nc" "return 1"
    
    output=$(check_browser_redirect)
    assert_contains "$output" "Browser redirect capability                        OK " "Should show OK when all browser redirect requirements are met"
}

test_check_browser_redirect_when_port_in_use() {
    # Mock nc to show port is in use
    mock "nc" "return 0"
    
    output=$(check_browser_redirect)
    assert_contains "$output" "Browser redirect capability                        FAILED " "Should show FAILED when port 8000 is in use"
    assert_contains "$output" "Port 8000 is in use" "Should show port in use message"
}
