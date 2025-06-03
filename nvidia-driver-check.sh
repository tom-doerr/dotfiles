#!/bin/bash

# Check for NVIDIA hardware
echo "1. NVIDIA Hardware Detection:"
lspci -k | grep -EA3 'VGA|3D|Display' | grep -i nvidia

# Check loaded kernel modules
echo -e "\n2. Loaded NVIDIA Modules:"
lsmod | grep nvidia

# Check driver version
echo -e "\n3. Driver Version:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=driver_version --format=csv,noheader
else
    echo "nvidia-smi not found - drivers likely not installed"
fi

# Check Xorg configuration
echo -e "\n4. Xorg Driver:"
grep -i driver /var/log/Xorg.0.log | grep -i nvidia

# Check package installation
echo -e "\n5. Installed Packages:"
dpkg -l | grep -i nvidia 2>/dev/null || echo "No NVIDIA packages found via dpkg"

# Check DKMS status
echo -e "\n6. DKMS Module Status:"
sudo dkms status | grep nvidia 2>/dev/null

echo -e "\nInterpretation:"
if nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA drivers appear properly installed"
else
    echo "❌ NVIDIA drivers not found - Install with:"
    echo "sudo apt install nvidia-driver-535 nvidia-dkms-535"
fi
