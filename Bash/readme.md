# Bash Scripts

## speedtest-linux

This script tests your internet connection by downloading a 100MB file to test your internet speed through a proxy or without a proxy. The test file is served from a CDN that automatically routes to the nearest edge location for accurate results. Allows selection of parallel connections (1-16) for multi-threaded download testing.

### Features

- Proxy selection (3 pre-configured proxies or custom)
- Multi-threaded download with configurable connections (1-16)
- Progress bar during download
- Color-coded output (Cyan for info, Yellow for results, Green/Red for pass/fail)
- Displays hostname and IP address
- Bandwidth validation against Microsoft minimum (10 Mbps) and recommended (20 Mbps) for Azure Local deployment

### Usage

```bash
# Download and run
curl -o /tmp/speedtest-linux https://raw.githubusercontent.com/TideWithBleach/Tools/main/Bash/speedtest-linux
chmod +x /tmp/speedtest-linux
/tmp/speedtest-linux
```

Or with optional proxy for the download:

```bash
curl -o /tmp/speedtest-linux https://raw.githubusercontent.com/TideWithBleach/Tools/main/Bash/speedtest-linux -x http://pzen.fpl.com:10262
chmod +x /tmp/speedtest-linux
/tmp/speedtest-linux
```

### Requirements

- bash
- curl
- bc (for floating point calculations)
- stat (for file size)
- hostname

The script will automatically check for these dependencies and provide installation instructions if any are missing. On RHEL, install missing dependencies with:

```bash
sudo dnf install curl bc
```

### Azure Local Bandwidth Requirements

For Azure Local bandwidth requirements, see: [Microsoft Learn - System Requirements](https://learn.microsoft.com/en-us/azure/azure-local/concepts/system-requirements-disaggregated)
