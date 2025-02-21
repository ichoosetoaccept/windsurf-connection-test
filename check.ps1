# Windsurf Connection Checker for Windows
# Requires PowerShell 5.1 or later

# Color and emoji constants
$CHECK_MARK = [char]0x2705
$CROSS_MARK = [char]0x274C
$WARNING = [char]0x26A0
$INFO = [char]0x2139
$GLOBE = [char]0x1F30E
$LOCK = [char]0x1F512
$BROWSER = [char]0x1F310

# ANSI color codes
$BLUE = "`e[34m"
$GREEN = "`e[32m"
$RED = "`e[31m"
$YELLOW = "`e[33m"
$BOLD = "`e[1m"
$NC = "`e[0m"

# Initialize log file
$LOG_FILE = "connection_test.log"
"" | Out-File -FilePath $LOG_FILE

function Write-Log {
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message" | Out-File -FilePath $LOG_FILE -Append
}

function Write-Status {
    param(
        [string]$Check,
        [string]$Status,
        [string]$Icon,
        [string]$Message = ""
    )
    
    $padding = " " * (50 - $Check.Length)
    
    if ($Message) {
        Write-Host "`n$Check$padding$Status $Icon"
        Write-Host "    ${INFO} $Message"
    } else {
        Write-Host "$Check$padding$Status $Icon"
    }
}

function Write-Header {
    param(
        [string]$Title,
        [string]$Icon
    )
    Write-Host "`n`n$Icon $Title"
    Write-Host "$BLUE$("=" * 60)$NC"
}

function Test-DnsResolvers {
    Write-Log "Checking DNS resolver connectivity"
    $ipv4_servers = @("8.8.8.8", "8.8.4.4")
    $ipv6_servers = @("2001:4860:4860::8888", "2001:4860:4860::8844")
    $ipv4_ok = $false
    $ipv6_ok = $false
    $has_ipv6 = $false
    
    # Check if system has IPv6
    if (Get-NetAdapter | Where-Object { $_.NetworkProtocols -match "IPv6" }) {
        $has_ipv6 = $true
        Write-Log "IPv6 is supported on this system"
    }
    
    # Check IPv4 DNS servers
    foreach ($server in $ipv4_servers) {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
            $ipv4_ok = $true
            Write-Log "Successfully reached IPv4 DNS server: $server"
            break
        }
    }
    
    # Check IPv6 DNS servers if supported
    if ($has_ipv6) {
        foreach ($server in $ipv6_servers) {
            if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
                $ipv6_ok = $true
                Write-Log "Successfully reached IPv6 DNS server: $server"
                break
            }
        }
    }
    
    if ($ipv4_ok -or ($has_ipv6 -and $ipv6_ok)) {
        Write-Status "DNS resolver access" "OK" $CHECK_MARK
        Write-Log "DNS resolver check passed"
    } else {
        Write-Status "DNS resolver access" "FAILED" $CROSS_MARK "Cannot reach any DNS resolvers. Check your internet connection."
        Write-Log "Failed to reach any DNS resolvers"
    }
}

function Test-WildcardDomain {
    param([string]$Domain)
    
    $baseDomain = $Domain -replace '^\*\.', ''
    $knownEndpoint = "api.$baseDomain"
    $success = $true
    $errorMsg = ""
    
    Write-Log "Testing wildcard domain: *.$baseDomain"
    
    # Test DNS resolution
    try {
        $null = Resolve-DnsName -Name $knownEndpoint -ErrorAction Stop
    } catch {
        $success = $false
        $errorMsg = "DNS resolution failed"
        Write-Log "DNS resolution failed for $knownEndpoint"
    }
    
    # Test HTTPS connection
    if ($success) {
        try {
            $response = Invoke-WebRequest -Uri "https://$knownEndpoint" -Method Head -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -ne 200) { throw }
        } catch {
            $success = $false
            $errorMsg = "Cannot connect to $knownEndpoint"
            Write-Log "Connection failed to $knownEndpoint"
        }
    }
    
    if ($success) {
        Write-Status "Access to *.$baseDomain" "OK" $CHECK_MARK
        Write-Log "Successfully verified access to *.$baseDomain"
    } else {
        Write-Status "Access to *.$baseDomain" "FAILED" $CROSS_MARK "$errorMsg. Check your DNS and firewall settings."
        Write-Log "Failed to verify access to *.$baseDomain: $errorMsg"
    }
}

function Test-Proxy {
    Write-Log "Checking proxy settings"
    $proxyServer = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer
    $proxyEnable = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyEnable
    
    if ($proxyEnable -and $proxyServer) {
        Write-Status "Proxy configuration" "WARNING" $WARNING "Proxy detected: $proxyServer"
        Write-Log "Proxy detected: $proxyServer"
    } else {
        Write-Status "No proxy detected" "OK" $CHECK_MARK
        Write-Log "No proxy detected"
    }
}

function Test-VPN {
    Write-Log "Checking VPN connections"
    $vpnConnections = Get-VpnConnection -AllUserConnection | Where-Object { $_.ConnectionStatus -eq "Connected" }
    $tailscaleAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match "Tailscale" -and $_.Status -eq "Up" }
    
    if ($tailscaleAdapter) {
        Write-Status "Tailscale VPN detected" "OK" $CHECK_MARK "Tailscale is active but should not affect Windsurf connectivity"
        Write-Log "Tailscale VPN detected (allowed)"
    } elseif ($vpnConnections) {
        Write-Status "VPN detected" "WARNING" $WARNING "Active VPN connection might affect Windsurf connectivity"
        Write-Log "VPN connection detected"
    } else {
        Write-Status "No VPN detected" "OK" $CHECK_MARK
        Write-Log "No VPN detected"
    }
}

function Test-BrowserRedirect {
    Write-Log "Checking browser redirect capabilities"
    $success = $true
    $messages = @()
    
    # Check localhost resolution
    try {
        $null = Resolve-DnsName -Name "localhost" -ErrorAction Stop
    } catch {
        $success = $false
        $messages += "Cannot resolve localhost - check your hosts file"
        Write-Log "Failed to resolve localhost"
    }
    
    # Check port 8000
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 8000)
        $listener.Start()
        $listener.Stop()
    } catch {
        $success = $false
        $messages += "Port 8000 is in use or blocked"
        Write-Log "Failed to bind to port 8000"
    }
    
    # Check default browser
    try {
        $null = Get-ItemProperty HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice -ErrorAction Stop
    } catch {
        $success = $false
        $messages += "No default browser set"
        Write-Log "No default browser configured"
    }
    
    if ($success) {
        Write-Status "Browser redirect capability" "OK" $CHECK_MARK "All requirements for browser-based authentication are met"
        Write-Log "Browser redirect check passed"
    } else {
        $message = $messages[0]
        if ($messages.Count -gt 1) {
            $message += "`n    $INFO " + ($messages[1..($messages.Count-1)] -join "`n    $INFO ")
        }
        Write-Status "Browser redirect capability" "FAILED" $CROSS_MARK $message
        Write-Log "Browser redirect check failed: $($messages -join ', ')"
    }
}

# Main script
Write-Host "${BOLD}🌊 Windsurf Connection Checker${NC}"
Write-Host "$BLUE$("=" * 60)$NC"

# Domain connectivity
Write-Header "Domain Connectivity" $GLOBE
Test-DnsResolvers
Test-WildcardDomain "*.codeium.com"

# Network configuration
Write-Header "Network Configuration" $LOCK
Test-Proxy
Test-VPN

# Browser redirect
Write-Header "Browser Redirect" $BROWSER
Test-BrowserRedirect

Write-Host "`n${BLUE}Detailed logs available in: ${NC}${LOG_FILE}`n"
