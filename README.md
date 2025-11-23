# pedagpu-deployment
PedaGPU VM1 installer for Spring 2025 AI Filmmaking courses at Texas A&M University-Corpus Christi
# PedaGPU VM1 Deployment

One-click installer for Texas A&M University-Corpus Christi AI Filmmaking courses (Spring 2025).

## Student Quick Start

### Step 1: Deploy VM
1. Go to [Massed Compute](https://massedcompute.com)
2. Use student discount code provided in Canvas
3. Deploy Ubuntu 22.04 with RTX 4090 GPU

### Step 2: Connect via ThinLinc
1. Download [ThinLinc client](https://www.cendio.com/thinlinc/download)
2. Connect to your VM IP address
3. Username: `Ubuntu` (or as provided)
4. Password: Provided by Massed Compute

### Step 3: Install PedaGPU
Open Terminal (`Ctrl+Alt+T`) and run:
```bash
curl -sL https://raw.githubusercontent.com/jdarbonne/pedagpu-deployment/main/install.sh | bash
```

When prompted, enter the Wasabi credentials from Canvas.

### Step 4: Setup Workspace
1. Double-click **"Setup My Workspace"** on desktop
2. Enter your student ID: `firstname_lastinitial`

### Step 5: Download Models
1. Double-click **"Download Models"** on desktop
2. Select **"Core Models (Required)"**
3. Wait 10-15 minutes for download

### Step 6: Start Creating!
1. Launch SwarmUI from desktop
2. Generate AI images
3. Everything auto-saves to Wasabi cloud storage

## ⚠️ CRITICAL: Delete VM After Each Session

Your VM costs approximately **$2-3/hour** if left running. Always **DELETE** (not stop) your VM after working.

Your work is automatically backed up to Wasabi and is safe.

## Features

- ✅ Automatic cloud backup of all generated images
- ✅ Isolated Python environment (no system conflicts)
- ✅ Manifest-based model management
- ✅ Zero-configuration after initial setup
- ✅ Research-grade metadata capture

## Architecture

- **Cloud Storage:** Wasabi S3-compatible storage
- **AI Framework:** SwarmUI with FLUX models
- **Auto-upload:** Python watchdog + systemd service
- **Model Management:** Versioned model packs with manifest

## Support

Contact your instructor if you experience issues.

## Repository Contents

- `install.sh` - Main installation script
- `manifest.json` - Model pack definitions
- `LICENSE` - MIT License

---

**Course:** AI Filmmaking  
**Instructor:** Professor John Davis  
**Institution:** Texas A&M University-Corpus Christi  
**Semester:** Spring 2025
