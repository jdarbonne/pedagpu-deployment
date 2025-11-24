#!/bin/bash
# PedaGPU VM1 Complete Installer - Spring 2025
# Usage: curl -sL https://raw.githubusercontent.com/jdarbonne/pedagpu-deployment/main/install.sh | bash

set -e

# Get actual username dynamically
INSTALL_USER=$(whoami)
INSTALL_HOME=$HOME

echo "🚀 PedaGPU VM1 Installation Starting..."
echo "Installing for user: $INSTALL_USER"

# 1. SYSTEM PACKAGES
echo "📦 [1/9] Installing system packages..."
sudo apt update -qq
sudo apt install -y python3-venv zenity rclone jq curl

# 2. CREATE ISOLATED VENV
echo "🐍 [2/9] Creating isolated Python environment..."
python3 -m venv "$INSTALL_HOME/pedagpu-venv"
source "$INSTALL_HOME/pedagpu-venv/bin/activate"
pip install --upgrade pip
pip install watchdog

# 3. DIRECTORIES
echo "📁 [3/9] Creating workspace..."
mkdir -p "$INSTALL_HOME/Desktop/MY_OUTPUT"
mkdir -p "$INSTALL_HOME/Desktop/MY_INPUT"
mkdir -p "$INSTALL_HOME/.local/bin"
mkdir -p "$INSTALL_HOME/.config/autostart"

# 3.5 AGGRESSIVE CLOCK SYNC (Fixes Wasabi AccessDenied due to clock skew)
echo "⏰ [3.5/9] Forcing system clock synchronization..."
sudo apt install -y ntpdate >/dev/null 2>&1
sudo ntpdate -u pool.ntp.org >/dev/null 2>&1
sudo timedatectl set-ntp true
sleep 2
echo "⏱️ Clock sync complete."

# 4. WASABI CONFIGURATION
echo "☁️ [4/9] Configuring cloud storage..."

# Hardcoded credentials (Spring 2025 - Read-only student access)
ACCESS_KEY="WC4QSUSGR2DRWDHE02A6"
SECRET_KEY="nJ0rgmVGaZz8loEOgKI5VKjC5VVbvrqqVEivRaLp"

mkdir -p "$INSTALL_HOME/.config/rclone"
cat > "$INSTALL_HOME/.config/rclone/rclone.conf" << RCLONE_EOF
[wasabi-artemis]
type = s3
provider = Wasabi
access_key_id = ${ACCESS_KEY}
secret_access_key = ${SECRET_KEY}
region = us-central-1
endpoint = https://s3.us-central-1.wasabisys.com
acl = private
v2_auth = true
RCLONE_EOF

chmod 600 "$INSTALL_HOME/.config/rclone/rclone.conf"

# CRITICAL FIX: Create global rclone config for systemd services
sudo ln -sf "$INSTALL_HOME/.config/rclone/rclone.conf" /etc/rclone.conf

# 5. UPLOAD AUTOMATION
echo "📤 [5/9] Creating upload automation..."
cat > "$INSTALL_HOME/.local/bin/upload-to-wasabi.sh" << 'UPLOAD_EOF'
#!/bin/bash
STUDENT_ID=$(cat ~/.student_id 2>/dev/null)
if [ -n "$STUDENT_ID" ] && [ -f "$1" ]; then
    rclone copy "$1" \
      wasabi-artemis:pedagpu-student-work/Spring2025/${STUDENT_ID}/OUTPUT/ \
      --ignore-existing
fi
UPLOAD_EOF
chmod +x "$INSTALL_HOME/.local/bin/upload-to-wasabi.sh"

# 6. SYSTEMD SERVICE
echo "⚙️ [6/9] Installing auto-upload service..."
WATCHMEDO_PATH="$INSTALL_HOME/pedagpu-venv/bin/watchmedo"

sudo tee /etc/systemd/system/swarm-upload.service > /dev/null << SERVICE_EOF
[Unit]
Description=SwarmUI Auto-Upload to Wasabi
After=network.target

[Service]
Type=simple
User=${INSTALL_USER}
Environment=HOME=${INSTALL_HOME}
WorkingDirectory=${INSTALL_HOME}
ExecStart=${WATCHMEDO_PATH} shell-command \\
  --patterns="*.png;*.jpg;*.jpeg;*.webp" \\
  --recursive \\
  --ignore-directories \\
  --command="${INSTALL_HOME}/.local/bin/upload-to-wasabi.sh \\\${watch_src_path}" \\
  ${INSTALL_HOME}/Desktop/MY_OUTPUT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable swarm-upload.service
sudo systemctl start swarm-upload.service

# 7. STUDENT SETUP BUTTON
echo "👤 [7/9] Creating student workspace setup..."
cat > "$INSTALL_HOME/Desktop/SETUP_MY_WORKSPACE.sh" << 'SETUP_EOF'
#!/bin/bash
RAW=$(zenity --entry --text="Enter your student ID\n(example: emily_r)\n\nUse: firstname_lastinitial" --width=400)
if [ -z "$RAW" ]; then
    zenity --error --text="No ID entered!"
    exit 1
fi
STUDENT_ID=$(echo "$RAW" | tr '[:upper:]' '[:lower:]')
if rclone lsd wasabi-artemis:pedagpu-student-work/Spring2025/ 2>/dev/null | grep -q "${STUDENT_ID}"; then
    zenity --error --text="❌ ID already taken!\n\nTry adding middle initial:\n(example: emily_m_r)"
    exit 1
fi
rclone mkdir wasabi-artemis:pedagpu-student-work/Spring2025/${STUDENT_ID}/OUTPUT
rclone mkdir wasabi-artemis:pedagpu-student-work/Spring2025/${STUDENT_ID}/INPUT
echo "$STUDENT_ID" > ~/.student_id
echo "Your Student ID: $STUDENT_ID" > ~/Desktop/MY_ID.txt
zenity --info --text="✅ Setup complete!\n\nYour ID: ${STUDENT_ID}\n\nAll images auto-save to Wasabi."
SETUP_EOF
chmod +x "$INSTALL_HOME/Desktop/SETUP_MY_WORKSPACE.sh"

cat > "$INSTALL_HOME/Desktop/SETUP_MY_WORKSPACE.desktop" << DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Setup My Workspace
Comment=First-time student setup
Exec=${INSTALL_HOME}/Desktop/SETUP_MY_WORKSPACE.sh
Icon=user-info
Terminal=false
Categories=Utility;
DESKTOP_EOF
chmod +x "$INSTALL_HOME/Desktop/SETUP_MY_WORKSPACE.desktop"

# 8. MODEL DOWNLOADER
echo "📦 [8/9] Creating model downloader..."
cat > "$INSTALL_HOME/Desktop/DOWNLOAD_MODELS.sh" << 'MODELS_EOF'
#!/bin/bash
MANIFEST_URL="https://raw.githubusercontent.com/jdarbonne/pedagpu-deployment/main/manifest.json"

curl -sL "$MANIFEST_URL" -o /tmp/pedagpu-manifest.json

if [ ! -f /tmp/pedagpu-manifest.json ]; then
    zenity --error --text="Cannot fetch model manifest!\n\nCheck internet connection."
    exit 1
fi

PACKS=$(jq -r '.packs[] | "\(.name)|\(.size)|\(.description)"' /tmp/pedagpu-manifest.json)

CHOICE=$(echo "$PACKS" | awk -F'|' '{print $1}' | zenity --list \
    --title="Download Models" \
    --text="Select model pack to download:" \
    --column="Model Pack" \
    --height=400 --width=600)

if [ -z "$CHOICE" ]; then
    exit 0
fi

PACK_PATH=$(jq -r ".packs[] | select(.name==\"$CHOICE\") | .path" /tmp/pedagpu-manifest.json)
SIZE=$(jq -r ".packs[] | select(.name==\"$CHOICE\") | .size" /tmp/pedagpu-manifest.json)
DESC=$(jq -r ".packs[] | select(.name==\"$CHOICE\") | .description" /tmp/pedagpu-manifest.json)

zenity --question \
    --text="Download: $CHOICE\n\nSize: $SIZE\nDescription: $DESC\n\nThis may take 5-15 minutes.\n\nContinue?" \
    --width=400

if [ $? -eq 0 ]; then
    (
        rclone copy \
          "wasabi-artemis:pedagpu-models/${PACK_PATH}/" \
          ~/apps/StableSwarmUI/Models/ \
          --progress --checksum 2>&1 | \
        while read line; do
            echo "# $line"
        done
    ) | zenity --progress --title="Downloading Models" --pulsate --auto-close --width=500
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        zenity --info --text="✅ $CHOICE installed successfully!\n\nRestart SwarmUI to use new models."
    else
        zenity --error --text="❌ Download failed or was interrupted.\n\nPlease try again."
    fi
fi
MODELS_EOF
chmod +x "$INSTALL_HOME/Desktop/DOWNLOAD_MODELS.sh"

cat > "$INSTALL_HOME/Desktop/DOWNLOAD_MODELS.desktop" << MODELS_DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Download Models
Comment=Download AI models for assignments
Exec=${INSTALL_HOME}/Desktop/DOWNLOAD_MODELS.sh
Icon=folder-download
Terminal=false
Categories=Utility;
MODELS_DESKTOP_EOF
chmod +x "$INSTALL_HOME/Desktop/DOWNLOAD_MODELS.desktop"

# 9. VERIFICATION
echo "✅ [9/9] Verifying installation..."
sudo systemctl status swarm-upload.service --no-pager | grep -q "active (running)"
if [ $? -eq 0 ]; then
    echo "✅ Auto-upload service: RUNNING"
else
    echo "⚠️ Auto-upload service: CHECK FAILED"
fi

echo ""
echo "🎉 PedaGPU VM1 Installation Complete!"
echo ""
echo "📋 Next steps:"
echo "1. Double-click 'Setup My Workspace' on desktop"
echo "2. Double-click 'Download Models' to get AI models"
echo "3. Launch SwarmUI and start creating!"
echo ""
echo "💡 Your work auto-saves to Wasabi cloud storage"
echo "⚠️ Remember to DELETE your VM when done (not just stop!)"
