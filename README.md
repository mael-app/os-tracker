# os-tracker

Lightweight daemon and serverless edge API to track and expose active OS presence (*macOS* and/or *Linux*) in real time on personal portfolios.

---

## 🚀 Installation & Setup

### 1. Configuration (All Platforms)

Create your local configuration file at `~/.config/os-tracker/config.toml`:

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

#### Manage Service on Linux:
- **Service status:** `systemctl --user status os-tracker`
- **Live logs:** `journalctl --user -u os-tracker -f`
- **Restart service:** `systemctl --user restart os-tracker`
- **Stop service:** `systemctl --user stop os-tracker`

---

## ⚡ Serverless Backend (Cloudflare Worker + D1)

### Initial Cloudflare Deployment

Deploy the D1 database and Edge Worker in one automated step:

```bash
./scripts/setup.sh
```

### API Endpoints

- `POST /heartbeat`: Authenticated endpoint (`Authorization: Bearer <AUTH_TOKEN>`) receiving `{ "os": "macos" | "linux" }`.
- `GET /status`: Public CORS-enabled endpoint returning active machines.

#### Response Example:
```json
{
  "online": true,
  "machines": [
    { "os": "macos", "online": true, "last_seen": 1787234567000 },
    { "os": "linux", "online": true, "last_seen": 1787234500000 }
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

    const onlineMachines = data.machines
      .filter((m) => m.online)
      .map((m) => (m.os === "macos" ? "macOS" : "Linux"));

    badge.textContent = `🟢 Online on ${onlineMachines.join(" & ")}`;
  } catch {
    document.getElementById("os-badge").textContent = "⚪ Status unavailable";
  }
}

updateOsStatus();
setInterval(updateOsStatus, 60_000);
```
