# os-tracker

Lightweight daemon and serverless edge API to track and expose active OS presence (*macOS*, *Linux*, and/or *Windows*) in real time on personal portfolios.

---

## 🚀 Installation & Setup

### 1. Configuration (All Platforms)

Create your local configuration file at:
- **macOS / Linux:** `~/.config/os-tracker/config.toml`
- **Windows:** `%APPDATA%\os-tracker\config.toml` (or `~/.config/os-tracker/config.toml`)

```toml
api_url = "https://os-tracker.mael-app.workers.dev"
token = "<YOUR_AUTH_TOKEN>"
interval_secs = 120
```

*Alternatively, you can pass these via environment variables:*
`OS_TRACKER_API_URL`, `OS_TRACKER_TOKEN`, `OS_TRACKER_INTERVAL`.

---

### macOS Installation (Homebrew)

Install the daemon and start it as a background service via Homebrew:

```bash
# 1. Tap the repository
brew tap mael-app/tap

# 2. Install os-tracker
brew install os-tracker

# 3. Create your config (if not already done)
mkdir -p ~/.config/os-tracker
# Add your config.toml here

# 4. Start the background service
brew services start os-tracker
```

#### Manage Service on macOS:
- **Restart service:** `brew services restart os-tracker`
- **Stop service:** `brew services stop os-tracker`
- **View logs:** `tail -f $(brew --prefix)/var/log/os-tracker.log`
- **Upgrade:** `brew upgrade os-tracker`

---

### Linux Installation

#### Option A: Debian / Ubuntu / Pop!_OS (`.deb` Package)

```bash
# 1. Download and install the latest .deb package
curl -fsSL https://github.com/mael-app/os-tracker/releases/latest/download/os-tracker_0.1.0-1_amd64.deb -o os-tracker.deb
sudo apt install ./os-tracker.deb
rm os-tracker.deb

# 2. Create your config (if not already done)
mkdir -p ~/.config/os-tracker
# Add your config.toml here

# 3. Enable and start the user systemd service
systemctl --user enable --now os-tracker
```

#### Option B: Standalone Script (All Linux Distributions, No Root Required)

```bash
curl -fsSL https://raw.githubusercontent.com/mael-app/os-tracker/main/dist/install.sh | sh
```

#### Option C: NixOS / Home Manager (Nix flake)

This repository is a flake exposing the package, an overlay and a Home Manager
module. Add it as an input:

```nix
{
  inputs.os-tracker = {
    url = "github:mael-app/os-tracker";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then, in a Home Manager module:

```nix
{ config, inputs, ... }:

{
  imports = [ inputs.os-tracker.homeModules.default ];

  services.os-tracker = {
    enable = true;
    apiUrl = "https://os-tracker.mael-app.workers.dev";
    interval = 120;
    tokenFile = "${config.home.homeDirectory}/.config/os-tracker/token.env";
  };
}
```

`tokenFile` points at a systemd environment file holding the bearer token, so
it stays out of the Nix store and out of the configuration repository:

```bash
mkdir -p ~/.config/os-tracker
printf 'OS_TRACKER_TOKEN=%s\n' "<YOUR_AUTH_TOKEN>" > ~/.config/os-tracker/token.env
chmod 600 ~/.config/os-tracker/token.env
```

No `config.toml` is needed: the module passes the URL and the interval to the
daemon through the unit environment. Upgrade with
`nix flake update os-tracker` followed by a rebuild.

Other outputs: `packages.<system>.os-tracker`, `overlays.default` (adds
`pkgs.os-tracker`) and a `devShells.default` with the Rust toolchain.

---

#### Manage Service on Linux:
- **Service status:** `systemctl --user status os-tracker`
- **Live logs:** `journalctl --user -u os-tracker -f`
- **Restart service:** `systemctl --user restart os-tracker`
- **Stop service:** `systemctl --user stop os-tracker`

---

### Windows Installation

#### Option A: Standalone PowerShell Script (Automated Setup & Background Task)

Run the following command in PowerShell:

```powershell
irm https://raw.githubusercontent.com/mael-app/os-tracker/main/dist/install.ps1 | iex
```

This script will:
1. Download the latest Windows release (`x86_64-pc-windows-msvc`).
2. Install `os-tracker.exe` to `%LOCALAPPDATA%\os-tracker` and add it to your user `PATH`.
3. Create a configuration template at `%APPDATA%\os-tracker\config.toml`.
4. Register and start a Windows Scheduled Task (`os-tracker`) running at user logon.

#### Option B: Manual Installation

1. Download `os-tracker-x86_64-pc-windows-msvc.zip` from [Releases](https://github.com/mael-app/os-tracker/releases/latest).
2. Extract `os-tracker.exe` to a directory in your `PATH` (e.g. `%LOCALAPPDATA%\os-tracker`).
3. Create your config file at `%APPDATA%\os-tracker\config.toml`.
4. Register the background scheduled task to run at logon:
   ```powershell
   $Action = New-ScheduledTaskAction -Execute "$env:LOCALAPPDATA\os-tracker\os-tracker.exe"
   $Trigger = New-ScheduledTaskTrigger -AtLogon
   $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0)
   Register-ScheduledTask -TaskName "os-tracker" -Action $Action -Trigger $Trigger -Settings $Settings -Description "OS Tracker Daemon"
   Start-ScheduledTask -TaskName "os-tracker"
   ```

#### Manage Service on Windows:
- **Service status:** `Get-ScheduledTask -TaskName os-tracker`
- **Start service:** `Start-ScheduledTask -TaskName os-tracker`
- **Stop service:** `Stop-ScheduledTask -TaskName os-tracker`
- **Restart service:** `Stop-ScheduledTask -TaskName os-tracker; Start-ScheduledTask -TaskName os-tracker`

---

## ⚡ Serverless Backend (Cloudflare Worker + D1)

### Initial Cloudflare Deployment

Deploy the D1 database and Edge Worker in one automated step:

```bash
./scripts/setup.sh
```

### API Endpoints

- `POST /heartbeat`: Authenticated endpoint (`Authorization: Bearer <AUTH_TOKEN>`) receiving `{ "os": "macos" | "linux" | "nixos" | "windows" }`. The daemon reports `nixos` when `/etc/os-release` says so, and `linux` on every other distribution.
- `GET /status`: Public CORS-enabled endpoint returning active machines.

#### Response Example:
```json
{
  "online": true,
  "machines": [
    { "os": "macos", "online": true, "last_seen": 1787234567000 },
    { "os": "nixos", "online": true, "last_seen": 1787234590000 },
    { "os": "linux", "online": false, "last_seen": 1787234500000 },
    { "os": "windows", "online": true, "last_seen": 1787234600000 }
  ]
}
```

---

## Frontend Badge Integration

```javascript
async function updateOsStatus() {
  try {
    const res = await fetch("https://os-tracker.mael-app.workers.dev/status");
    const data = await res.json();
    const badge = document.getElementById("os-badge");

    if (!data.online) {
      badge.textContent = "⚪ Offline";
      return;
    }

    const osNames = { macos: "macOS", linux: "Linux", nixos: "NixOS", windows: "Windows" };
    const onlineMachines = data.machines
      .filter((m) => m.online)
      .map((m) => osNames[m.os] || m.os);

    badge.textContent = `🟢 Online on ${onlineMachines.join(" & ")}`;
  } catch {
    document.getElementById("os-badge").textContent = "⚪ Status unavailable";
  }
}

updateOsStatus();
setInterval(updateOsStatus, 60_000);
```
