# Windsurf Connection Checker

A cross-platform diagnostic tool to verify connectivity requirements for the Windsurf code editor.

## Quick Start

### Option 1: Direct execution (recommended)
```bash
# Unix-like systems (macOS, Linux)
curl -sSL https://raw.githubusercontent.com/codeium/windsurf-connection-test/main/check.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/codeium/windsurf-connection-test/main/check.ps1 | iex
```

### Option 2: Download and run
1. Download the [latest release](https://github.com/codeium/windsurf-connection-test/releases/latest)
2. Extract the ZIP file
3. Run the checker:
   - Unix-like systems: `./check.sh`
   - Windows: `.\check.ps1`

## What does it check?

1. **Domain Connectivity**
   - *.codeium.com endpoints
   - *.codeiumdata.com endpoints

2. **Network Configuration**
   - Proxy detection and configuration
   - VPN detection
   - Firewall restrictions
   - SSL/TLS inspection

3. **Browser Authentication**
   - Browser redirect capability
   - Required ports availability
   - SSL certificate validation
   - Cookie settings
   - JavaScript execution

## Output

The tool provides:
- ✅ Success or ❌ failure status for each check
- Detailed error messages and troubleshooting steps
- Network configuration summary
- Recommendations for fixing detected issues

## Requirements

- No installation required
- Works on Windows, macOS, and Linux
- Minimal dependencies (uses built-in OS commands)
- Requires bash (Unix) or PowerShell (Windows)

## Privacy & Security

- No data is collected or transmitted
- All checks are performed locally
- Code is open source and auditable
- No elevated privileges required

## Troubleshooting

If you encounter issues:
1. Check your network connection
2. Verify any VPN or proxy settings
3. Ensure your firewall allows outbound HTTPS connections
4. Review detailed logs in `connection_test.log`

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - See [LICENSE](LICENSE) file for details
