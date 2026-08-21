# os-tracker

Lightweight daemon and serverless edge API to track and expose active OS presence (*macOS* and/or *Linux*) in real time on personal portfolios.

## Components

- **Daemon (`os-tracker`)**: Native Rust client running in the background sending heartbeats via `ureq`.
- **Worker (`worker/`)**: Cloudflare Worker with D1 SQLite database exposing `/heartbeat` and `/status` (multi-OS supported).
- **Distribution**: Automated release pipeline for macOS (Universal binary + Homebrew tap) and Linux (musl static binary + `.deb` package).

## Setup & Deployment

### 1. Cloudflare Worker Setup
```bash
./scripts/setup.sh
```

### 2. Daemon Configuration
Create `~/.config/os-tracker/config.toml`:
```toml
api_url = "https://os-tracker.mael-app.workers.dev"
token = "<AUTH_TOKEN>"
interval_secs = 120
```

Alternatively, configure via environment variables:
- `OS_TRACKER_API_URL`
- `OS_TRACKER_TOKEN`
- `OS_TRACKER_INTERVAL`

### 3. Local Build
```bash
cargo build --release
```

## API Endpoints

- `POST /heartbeat`: Authenticated endpoint (`Authorization: Bearer <AUTH_TOKEN>`) receiving `{ "os": "macos" | "linux" }`.
- `GET /status`: Public CORS-enabled endpoint returning current machine availability.

```json
{
  "online": true,
  "machines": [
    { "os": "macos", "online": true, "last_seen": 1787234567000 },
    { "os": "linux", "online": true, "last_seen": 1787234500000 }
  ]
}
```
