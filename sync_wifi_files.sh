#!/bin/bash

# ════════════════════════════════════════════════════════════════
# Скрипт для копирования WiFi файлов на ваш Mac
# ════════════════════════════════════════════════════════════════

set -e

echo "🔄 Синхронизация WiFi файлов..."
echo ""

# Проверяем что мы в правильной директории
if [ ! -d "TRiANGL/TRiANGL" ]; then
    echo "❌ Ошибка: Запустите скрипт из корневой папки проекта TRiANGL-Native-iOS"
    exit 1
fi

# Список файлов для синхронизации
FILES=(
    "WiFiDevice.swift"
    "WiFiScanner.swift"
    "WiFiScannerView.swift"
    "WiFiSignalMeasurement.swift"
    "WiFiSignalMonitor.swift"
    "WiFiHeatmapManager.swift"
    "WiFiHeatmapARContainer.swift"
    "WiFiHeatmapView.swift"
)

echo "📥 Получаем последние изменения с GitHub..."
git fetch origin claude/scan-wifi-devices-JP3V2

echo ""
echo "🔀 Переключаемся на ветку с WiFi функционалом..."
git checkout claude/scan-wifi-devices-JP3V2

echo ""
echo "⬇️  Подтягиваем изменения..."
git pull origin claude/scan-wifi-devices-JP3V2

echo ""
echo "✅ Проверяем наличие файлов:"
echo ""

FOUND=0
MISSING=0

for file in "${FILES[@]}"; do
    if [ -f "TRiANGL/TRiANGL/$file" ]; then
        SIZE=$(ls -lh "TRiANGL/TRiANGL/$file" | awk '{print $5}')
        echo "   ✓ $file ($SIZE)"
        ((FOUND++))
    else
        echo "   ✗ $file - НЕ НАЙДЕН"
        ((MISSING++))
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "Найдено: $FOUND из ${#FILES[@]} файлов"

if [ $MISSING -eq 0 ]; then
    echo "✅ Все WiFi файлы успешно синхронизированы!"
    echo ""
    echo "Теперь:"
    echo "1. Откройте TRiANGL.xcodeproj в Xcode"
    echo "2. Добавьте WiFi файлы в проект (если еще не добавлены)"
    echo "3. Нажмите Cmd+B для компиляции"
    echo ""
    echo "📂 Открыть папку с файлами?"
    read -p "Открыть? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open TRiANGL/TRiANGL
    fi
else
    echo "⚠️  Внимание: Не все файлы найдены"
    echo "Попробуйте снова выполнить: git pull origin claude/scan-wifi-devices-JP3V2"
fi

echo "════════════════════════════════════════════════════════════════"
