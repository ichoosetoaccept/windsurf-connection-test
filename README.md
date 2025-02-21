# Windsurf Connection Test

A simple tool to check network connectivity for the Windsurf code editor. It verifies:
- Domain connectivity (DNS and HTTPS)
- Network configuration (proxies and VPNs)
- Browser redirect capability for authentication

## Quick Start

### macOS and Linux
```bash
curl -fsSL https://raw.githubusercontent.com/ichoosetoaccept/windsurf-connection-test/main/check.sh | bash
```

### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/ichoosetoaccept/windsurf-connection-test/main/check.ps1 | iex
```

## What it Checks

1. **Domain Connectivity**
   - DNS resolver access (IPv4 and IPv6)
   - Access to *.codeium.com

2. **Network Configuration**
   - Proxy detection
   - VPN detection (with special handling for Tailscale)

3. **Browser Redirect**
   - OAuth callback port availability
   - Browser launch capability
   - Localhost resolution

## Requirements

### macOS and Linux
The bash script uses common Unix tools that are typically pre-installed:
- bash
- curl
- ping
- nc (netcat)
- lsof
- grep
- host

### Windows
The PowerShell script requires:
- PowerShell 5.1 or later (pre-installed on Windows 10 and later)
- Administrator privileges are NOT required

## Output

The script provides:
- Clear status indicators with emojis
- Detailed error messages when issues are found
- A log file with additional debugging information

## Testing

### macOS and Linux
The bash script is tested using [bashunit](https://github.com/TypedDevs/bashunit):

1. Install bashunit:
```bash
git clone https://github.com/TypedDevs/bashunit.git
cd bashunit
./install.sh
```

2. Run the tests:
```bash
cd tests
./test_check.sh
```

The script is automatically tested on both macOS and Linux using GitHub Actions on every push.

### Windows
The PowerShell script is automatically tested on Windows using GitHub Actions on every push. You can:

1. View the latest test results in the [Actions tab](https://github.com/ichoosetoaccept/windsurf-connection-test/actions)
2. Manually trigger a test by:
   - Going to Actions
   - Selecting "Test Windows Script" or "Test Unix Script"
   - Clicking "Run workflow"

This ensures both scripts are regularly tested on their respective platforms with the latest updates.

## Security

The script:
- Only checks connectivity and system configuration
- Does not modify any files
- Does not collect or transmit any data
- Can be inspected before running: [check.sh](check.sh) or [check.ps1](check.ps1)

## License

MIT License - feel free to modify and distribute!
