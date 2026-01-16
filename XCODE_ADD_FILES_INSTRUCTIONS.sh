#!/bin/bash

# This script will print the exact paths for Xcode to add files directly

echo "════════════════════════════════════════════════════════"
echo "  WiFi FILES - COPY-PASTE PATHS FOR XCODE"
echo "════════════════════════════════════════════════════════"
echo ""
echo "In Xcode, do this:"
echo ""
echo "1. Right-click on 'TRiANGL' folder (yellow) → 'Add Files to TRiANGL...'"
echo "2. Press: Cmd + Shift + G"
echo "3. Paste this path:"
echo ""
echo "   ~/TRiANGL-Native-iOS/TRiANGL/TRiANGL"
echo ""
echo "4. In search field type: WiFi"
echo ""
echo "5. You should see these 8 files:"
echo ""

cd /home/user/TRiANGL-Native-iOS/TRiANGL/TRiANGL
for file in WiFi*.swift; do
    if [ -f "$file" ]; then
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "   ✓ $file ($size)"
    fi
done

echo ""
echo "6. Select all (Cmd+A)"
echo "7. Settings:"
echo "   ❌ Copy items if needed - UNCHECK"
echo "   ✓ Add to targets: TRiANGL - CHECK"
echo "8. Click 'Add'"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "Files are located at:"
echo "/home/user/TRiANGL-Native-iOS/TRiANGL/TRiANGL/"
echo ""
echo "On Mac this should be:"
echo "~/TRiANGL-Native-iOS/TRiANGL/TRiANGL/"
echo ""
