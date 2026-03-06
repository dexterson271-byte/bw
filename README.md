# BedWars Server - Hypixel Style
## Railway Pro | Zero-Lag | Auth + Ranks + Backups + File Manager

### What's Included
- **Paper MC 1.20.4** - High-performance Minecraft server (6GB RAM on Railway Pro)
- **Screaming BedWars 0.2.42.2** - Full BedWars minigame plugin
- **Hypixel-style configs** - Shop, upgrades, spawners, scoreboards, game events
- **AuthMe + FastLogin** - Cracked players `/login` & `/register`, premium players auto-login
- **LuckPerms + Vault** - Rank system with chat tags (Owner, Admin, MVP, VIP, Player)
- **FileBrowser** - Web-based file manager to access all server files from your browser
- **Auto Backups** - Automatic server backups every 30 minutes to Railway volume

### Owner
- **HassanLegend** - `&4[OWNER] &c` tag, all permissions

---

## Deploy to Railway

### Step 1: Install Git (if not already)
Download from https://git-scm.com

### Step 2: Initialize Git repo
```bash
cd C:\Users\Lee\Pictures\bw
git init
git add .
git commit -m "BedWars server - Hypixel style"
```

### Step 3: Push to GitHub
```bash
git remote add origin https://github.com/YOUR_USERNAME/bedwars-server.git
git branch -M main
git push -u origin main
```

### Step 4: Deploy on Railway
1. Go to https://railway.app and sign in with GitHub
2. Click **"New Project"** -> **"Deploy from GitHub Repo"**
3. Select your bedwars-server repo

### Step 5: Add a Volume (IMPORTANT for backups & persistence)
1. In Railway dashboard -> click your service
2. Click **"+ New"** -> **"Volume"**
3. Set mount path to: `/data`
4. This stores your worlds, backups, configs persistently

### Step 6: Configure Environment Variables
| Variable | Value | Description |
|----------|-------|-------------|
| `PORT` | `25565` | Minecraft server port |
| `SERVER_PORT` | `25565` | Server port |
| `MEMORY` | `6G` | Minimum RAM |
| `MAX_MEMORY` | `6G` | Maximum RAM |
| `FILEBROWSER_PORT` | `8080` | File manager web port |
| `BACKUP_INTERVAL` | `30` | Backup every N minutes |
| `MAX_BACKUPS` | `10` | Keep last N backups |

### Step 7: Enable TCP Networking (for Minecraft)
1. In Railway dashboard -> **Settings** -> **Networking**
2. Click **"Generate TCP Proxy"** for port `25565`
3. You'll get: `moniker.proxy.rlwy.net:12345` - this is your server IP!

### Step 8: Enable HTTP Networking (for File Manager)
1. Click **"Generate Domain"** for port `8080`
2. You'll get a URL like `bedwars-server-production.up.railway.app`
3. Open it in browser -> login: `admin` / `admin` (CHANGE THIS!)

---

## Authentication System

### How it works:
| Player Type | What Happens |
|-------------|-------------|
| **Premium (paid MC)** | Auto-login, no /login needed (like Hypixel) |
| **Cracked (no premium)** | Must `/register <password> <password>` first time |
| **Cracked (returning)** | Must `/login <password>` each time |

- Any password allowed (min 4 characters, no restrictions)
- Sessions last 12 hours (auto-login if reconnecting quickly)
- Max 3 accounts per IP

---

## Rank System

| Rank | Tag | Weight | How to assign |
|------|-----|--------|--------------|
| **Owner** | `&4[OWNER] &c` | 100 | Auto-assigned to HassanLegend |
| **Admin** | `&c[ADMIN] &f` | 50 | `/lp user <name> parent set admin` |
| **MVP** | `&b[MVP] &f` | 20 | `/lp user <name> parent set mvp` |
| **VIP** | `&a[VIP] &f` | 10 | `/lp user <name> parent set vip` |
| **Player** | `&7[Player] &f` | 1 | Default for everyone |

### Quick rank commands:
```
/lp user <player> parent set owner    # Make someone owner
/lp user <player> parent set admin    # Make someone admin
/lp user <player> parent set mvp      # Give MVP rank
/lp user <player> parent set vip      # Give VIP rank
/lp user <player> parent set default  # Reset to player
```

---

## Backup System

- Auto-backups every 30 minutes (configurable via `BACKUP_INTERVAL`)
- Stored in `/data/backups/` on the Railway volume
- Keeps last 10 backups (configurable via `MAX_BACKUPS`)
- Backs up: plugins, worlds, configs (not JARs or cache)
- Access backups via the File Manager web UI

## File Manager

- Web-based file manager at your Railway HTTP domain
- Browse/edit/download/upload ALL server files
- Default login: `admin` / `admin` (change after first login!)
- Can view backups, edit configs, manage worlds

---

## Hypixel-Style Features Configured

### Resource Spawners (Island)
| Resource | Interval | Max Stack |
|----------|----------|-----------|
| Iron | 1 second | 64 |
| Gold | 6 seconds | 16 |

### Resource Spawners (Map)
| Resource | Tier I | Tier II | Tier III |
|----------|--------|---------|----------|
| Diamond | 30s | 20s | 10s |
| Emerald | 60s | 40s | 20s |

### Game Events Timeline
| Time | Event |
|------|-------|
| 6:00 | Diamond Generators → Tier II |
| 12:00 | Emerald Generators → Tier II |
| 18:00 | Diamond Generators → Tier III |
| 24:00 | Emerald Generators → Tier III |
| 30:00 | All Beds Destroyed |
| 40:00 | Sudden Death (Dragons) |
| 50:00 | Game Over |

### Shop Categories (Hypixel Layout)
- Quick Buy | Blocks | Melee | Armor | Tools | Ranged | Potions | Utility

### Team Upgrades
- Sharpened Swords | Reinforced Armor (I-IV) | Maniac Miner (I-II) | Iron Forge (4 tiers) | Heal Pool

### Traps
- It's a Trap! | Counter-Offensive | Alarm | Miner Fatigue

---

## Setting Up Arenas (After Server Starts)

Once the server is running, you need to create BedWars arenas:

```
/bw admin <arena_name>         # Create a new arena
/bw admin <arena_name> pos1    # Set arena corner 1
/bw admin <arena_name> pos2    # Set arena corner 2
/bw admin <arena_name> lobby   # Set lobby spawn
/bw admin <arena_name> spec    # Set spectator spawn
/bw admin <arena_name> team add <team_name> <color>  # Add team
/bw admin <arena_name> team spawn <team_name>         # Set team spawn
/bw admin <arena_name> team bed <team_name>           # Set bed location
/bw admin <arena_name> store add                      # Add shop villager
/bw admin <arena_name> spawner add <type>             # Add resource spawner
/bw admin <arena_name> save                           # Save the arena
```

### Example: Creating a Solo (8 teams) Arena
```
/bw admin solo1
# Set arena boundaries
/bw admin solo1 pos1
/bw admin solo1 pos2
/bw admin solo1 lobby
/bw admin solo1 spec

# Add all 8 teams
/bw admin solo1 team add Red RED
/bw admin solo1 team add Blue BLUE
/bw admin solo1 team add Green GREEN
/bw admin solo1 team add Yellow YELLOW
/bw admin solo1 team add Aqua AQUA
/bw admin solo1 team add White WHITE
/bw admin solo1 team add Pink LIGHT_PURPLE
/bw admin solo1 team add Gray DARK_GRAY

# For each team: set spawn, bed, and island spawners
# Then add diamond and emerald spawners on the map
/bw admin solo1 save
```

---

## File Structure
```
bw/
├── Dockerfile              # Railway build config (downloads all plugins)
├── railway.toml            # Railway deployment settings
├── entrypoint.sh           # Startup script (server + backups + file manager)
├── backup.sh               # Auto backup daemon
├── setup-permissions.sh    # First-run rank/permission setup
├── server.properties       # MC server settings (optimized)
├── spigot.yml              # Spigot optimization config
├── eula.txt                # Minecraft EULA acceptance
├── .gitignore
├── .dockerignore
├── config/
│   ├── paper-global.yml    # Paper global performance config
│   └── paper-world-defaults.yml  # Paper world performance config
├── plugins/
│   ├── BedWars-0.2.42.2.jar     # Screaming BedWars plugin
│   ├── BedWars/
│   │   ├── config.yml            # BedWars config (Hypixel-style)
│   │   ├── shop.yml              # Item shop (Hypixel layout)
│   │   └── upgrades.yml          # Team upgrades & traps
│   ├── AuthMe/
│   │   └── config.yml            # Auth config (cracked + premium)
│   ├── FastLogin/
│   │   └── config.yml            # Auto-login for premium players
│   └── LuckPerms/
│       ├── config.yml            # Permissions config
│       └── setup-permissions.json # Rank definitions + owner setup
```

### On Railway Volume (`/data/`):
```
/data/
├── server/          # Full server (worlds, plugins, configs)
├── backups/         # Auto backups (backup_2026-03-06_12-00-00.tar.gz)
└── filebrowser/     # File manager database
```
