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

# 4. WASABI CONFIGURATION
echo "☁️ [4/9] Configuring cloud storage..."

ACCESS_KEY=$(zenity --entry --title="Wasabi Access Key" \
    --text="Enter the Wasabi Access Key provided by your instructor:" \
    --width=400)

SECRET_KEY=$(zenity --password --title="Wasabi Secret Key" \
    --text="Enter the Wasabi Secret Key provided by your instructor:")

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    zenity --error --text="Wasabi credentials required!\n\nInstallation aborted."
    exit 1
fi

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
# Ensures rclone works under systemd uploads even if HOME changes at boot
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
echo "Your Student ID: $STUDENT_ID" > ~/De
