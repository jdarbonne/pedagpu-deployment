#!/bin/bash
# PedaGPU Kaggle/Headless Installer - Spring 2025
# Usage: 
# export WASABI_ACCESS_KEY="your_key"
# export WASABI_SECRET_KEY="your_secret"
# export STUDENT_ID="john_d"
# curl -sL https://raw.githubusercontent.com/jdarbonne/pedagpu-deployment/main/install-kaggle.sh | bash

set -e

INSTALL_USER=$(whoami)
INSTALL_HOME=$HOME

echo "🚀 PedaGPU Kaggle Installation Starting..."
echo "Installing for user: $INSTALL_USER"

# Check for required environment variables
if [ -z "$WASABI_ACCESS_KEY" ] || [ -z "$WASABI_SECRET_KEY" ]; then
    echo "❌ ERROR: Wasabi credentials required!"
    echo ""
    echo "Set environment variables before running:"
    echo "  export WASABI_ACCESS_KEY='your_access_key'"
    echo "  export WASABI_SECRET_KEY='your_secret_key'"
    echo "  export STUDENT_ID='your_id' (optional)"
    exit 1
fi

if [ -z "$STUDENT_ID" ]; then
    STUDENT_ID="kaggle_test_$(date +%s)"
    echo "⚠️  No STUDENT_ID set, using: $STUDENT_ID"
fi

# 1. SYSTEM PACKAGES
echo "📦 [1/8] Installing system packages..."
apt-get update -qq
apt-get install -y python3-venv rclone jq curl

# 2. CREATE ISOLATED VENV
echo "🐍 [2/8] Creating isolated Python environment..."
python3 -m venv "$INSTALL_HOME/pedagpu-venv"
source "$INSTALL_HOME/pedagpu-venv/bin/activate"
pip install --upgrade pip -q
pip install watchdog -q

# 3. DIRECTORIES
echo "📁 [3/8] Creating workspace..."
mkdir -p "$INSTALL_HOME/MY_OUTPUT"
mkdir -p "$INSTALL_HOME/MY_INPUT"
mkdir -p "$INSTALL_HOME/.local/bin"

# 4. WASABI CONFIGURATION
echo "☁️ [4/8] Configuring cloud storage..."
mkdir -p "$INSTALL_HOME/.config/rclone"
cat > "$INSTALL_HOME/.config/rclone/rclone.conf" << RCLONE_EOF
[wasabi-artemis]
type = s3
provider = Wasabi
access_key_id = ${WASABI_ACCESS_KEY}
secret_access_key = ${WASABI_SECRET_KEY}
region = us-central-1
endpoint = https://s3.us-central-1.wasabisys.com
acl = private
v2_auth = true
RCLONE_EOF

chmod 600 "$INSTALL_HOME/.config/rclone/rclone.conf"
ln -sf "$INSTALL_HOME/.config/rclone/rclone.conf" /etc/rclone.conf

# 5. UPLOAD AUTOMATION
echo "📤 [5/8] Creating upload automation..."
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

# 6. STUDENT SETUP (Auto-configure in Kaggle)
echo "👤 [6/8] Setting up student workspace..."
rclone mkdir wasabi-artemis:pedagpu-student-work/Spring2025/${STUDENT_ID}/OUTPUT
rclone mkdir wasabi-artemis:pedagpu-student-work/Spring2025/${STUDENT_ID}/INPUT
echo "$STUDENT_ID" > ~/.student_id
echo "Your Student ID: $STUDENT_ID" > ~/MY_ID.txt

# 7. TEST UPLOAD
echo "📤 [7/8] Testing upload functionality..."
echo "Test file created at $(date)" > ~/MY_OUTPUT/test-upload.txt
bash "$INSTALL_HOME/.local/bin/upload-to-wasabi.sh" ~/MY_OUTPUT/test-upload.txt
sleep 3

# 8. VERIFICATION
echo "✅ [8/8] Verifying installation..."
if rclone ls wasabi-artemis:pedagpu-student-work/Spring2025/${STUDENT_ID}/OUTPUT/ | grep -q "test-upload.txt"; then
    echo "✅ Upload test: SUCCESS"
else
    echo "❌ Upload test: FAILED"
    exit 1
fi

echo ""
echo "🎉 PedaGPU Kaggle Installation Complete!"
echo ""
echo "Student ID: $STUDENT_ID"
echo "Output folder: ~/MY_OUTPUT"
echo "Wasabi location: wasabi-artemis:pedagpu-student-work/Spring2025/${STUDENT_ID}/OUTPUT/"
echo ""
echo "✅ All systems operational!"
