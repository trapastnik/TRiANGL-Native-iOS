#!/bin/bash

# Script to add WiFi files to Xcode project
# This adds the files to the project structure

cd /home/user/TRiANGL-Native-iOS/TRiANGL

echo "Files to add to Xcode project:"
echo "1. WiFiDevice.swift"
echo "2. WiFiScanner.swift"
echo "3. WiFiScannerView.swift"
echo "4. WiFiSignalMeasurement.swift"
echo "5. WiFiSignalMonitor.swift"
echo "6. WiFiHeatmapManager.swift"
echo "7. WiFiHeatmapARContainer.swift"
echo "8. WiFiHeatmapView.swift"
echo ""
echo "⚠️  Please add these files manually in Xcode:"
echo ""
echo "INSTRUCTIONS:"
echo "1. Open TRiANGL.xcodeproj in Xcode"
echo "2. In the Project Navigator (left sidebar), right-click on the 'TRiANGL' folder"
echo "3. Select 'Add Files to TRiANGL...'"
echo "4. Navigate to: TRiANGL/TRiANGL/"
echo "5. Select ALL WiFi*.swift files (8 files total)"
echo "6. Make sure these options are set:"
echo "   - 'Copy items if needed' is UNCHECKED ❌"
echo "   - 'Create groups' is SELECTED ✓"
echo "   - 'Add to targets: TRiANGL' is CHECKED ✓"
echo "7. Click 'Add'"
echo ""
echo "Then build the project with: Cmd+B"
