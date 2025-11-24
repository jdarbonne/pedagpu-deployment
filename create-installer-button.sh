#!/bin/bash
# Creates PedaGPU installer button on desktop

cat > ~/Desktop/INSTALL_PEDAGPU.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Install PedaGPU
Comment=One-click PedaGPU installation for AI Filmmaking
Exec=bash -c "gnome-terminal -- bash -c 'curl -sL https://raw.githubusercontent.com/jdarbonne/pedagpu-deployment/main/install.sh | bash; echo; echo Installation complete! Press ENTER to close...; read'"
Icon=system-software-install
Terminal=true
Categories=System;
EOF

chmod +x ~/Desktop/INSTALL_PEDAGPU.desktop
gio set ~/Desktop/INSTALL_PEDAGPU.desktop metadata::trusted true 2>/dev/null || true

echo "✅ PedaGPU installer button created on desktop!"
echo "📋 Double-click 'Install PedaGPU' to begin installation."
