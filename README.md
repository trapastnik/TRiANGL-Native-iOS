# TRiANGL Native iOS - LiDAR Corner Illusion App

## Описание

Native iOS приложение для создания 3D оптических иллюзий в углах комнаты, используя LiDAR scanner для точного сканирования геометрии.

## Требования

- **Устройство:** iPhone 12 Pro или новее (с LiDAR)
- **iOS:** 14.0+
- **Xcode:** 15.0+
- **Swift:** 5.9+

## Технологии

- ARKit - AR session, plane detection
- RealityKit - 3D rendering
- SceneKit - 3D геометрия
- LiDAR Scanner - depth sensing
- PDFKit - генерация паттернов

## Основные функции

1. **Live LiDAR Scanning** - real-time детекция углов и плоскостей
2. **Corner Geometry Analysis** - вычисление углов между стенами и потолком
3. **AR Cube Preview** - размещение 3D куба в углу с preview
4. **PDF Pattern Generation** - генерация паттернов для печати с anamorphic projection

## Структура проекта

```
TRiANGL-Native-iOS/
├── README.md                    # Этот файл
├── TZ.md                        # Полное техническое задание
├── TRiANGL.xcodeproj           # Xcode project (будет создан)
├── TRiANGL/
│   ├── App/                     # App entry point
│   ├── Views/                   # SwiftUI views
│   ├── AR/                      # ARKit managers
│   ├── Models/                  # Data models
│   ├── Services/                # Business logic
│   ├── Utilities/               # Helpers
│   └── Resources/               # Assets, designs
└── Tests/                       # Unit & UI tests
```

## Начало работы

### 1. Создать Xcode Project

```bash
# Откройте Xcode
# File → New → Project
# iOS → App
# Interface: SwiftUI
# Language: Swift
# Include Tests: Yes
```

### 2. Добавить необходимые frameworks

В project settings → General → Frameworks, Libraries, and Embedded Content:
- ARKit.framework
- RealityKit.framework
- SceneKit.framework
- PDFKit.framework
- Accelerate.framework

### 3. Настроить Info.plist

Добавить разрешения:
- `NSCameraUsageDescription`: "TRiANGL needs camera access for AR scanning"
- `NSMotionUsageDescription`: "TRiANGL needs motion sensors for AR tracking"

### 4. Настроить capabilities

- Background Modes: OFF (не нужны)
- Camera: ON (автоматически через Info.plist)

## Workflow разработки

### Phase 1: Core AR Infrastructure (Week 1-2)
- [ ] Создать ARManager с ARSession
- [ ] Настроить LiDAR depth capture
- [ ] Базовая plane detection
- [ ] Point cloud generation

### Phase 2: Corner Detection (Week 3-4)
- [ ] RANSAC plane detection algorithm
- [ ] Line-line intersection math
- [ ] Corner vertex detection
- [ ] Real-time visualization

### Phase 3: Geometry & Math (Week 5-6)
- [ ] Angle calculations между плоскостями
- [ ] CornerGeometry data model
- [ ] Validation logic
- [ ] Geometry review UI

### Phase 4: AR Cube Preview (Week 7-8)
- [ ] 3D cube models
- [ ] AR placement в углу
- [ ] Viewing position calculation
- [ ] Interactive controls (rotate, scale)

### Phase 5: Anamorphic Projection (Week 9-10)
- [ ] 3D → 2D projection algorithm
- [ ] Texture mapping
- [ ] Pattern generation для каждой плоскости

### Phase 6: PDF Generation (Week 11-12)
- [ ] PDF creation с PDFKit
- [ ] Multi-page layout
- [ ] Calibration page
- [ ] Assembly instructions

### Phase 7: UI/UX Polish (Week 13-14)
- [ ] Все screens
- [ ] Transitions
- [ ] Error handling
- [ ] User testing

### Phase 8: Testing & Release (Week 15-16)
- [ ] Bug fixes
- [ ] Performance optimization
- [ ] App Store submission

## Ключевые файлы

- `TZ.md` - Полное техническое задание
- `ARManager.swift` - Main ARKit manager
- `LiDARScanner.swift` - LiDAR depth processing
- `CornerDetector.swift` - Corner detection algorithm
- `GeometryCalculator.swift` - 3D math
- `AnamorphicProjector.swift` - 3D → 2D projection
- `PDFGenerator.swift` - PDF creation

## Математика

### Plane Detection (RANSAC)
```swift
// Найти плоскость из point cloud
// Iterations: 1000
// Inlier threshold: 5cm
// Result: Plane equation Ax + By + Cz + D = 0
```

### Corner Vertex
```swift
// Intersection of 3 lines (ceiling-wall edges)
// Using least squares minimization
// Result: 3D point (x, y, z)
```

### Anamorphic Projection
```swift
// For each pixel in output pattern:
//   1. World position на стене/потолке
//   2. Ray от viewing position через world position
//   3. Intersection с cube face
//   4. UV coordinates на cube texture
//   5. Sample color → output pixel
```

## Testing

### Unit Tests
```bash
⌘ + U в Xcode
```

Тесты:
- Geometry calculations (angles, intersections)
- Plane detection algorithms
- Projection math

### UI Tests
```bash
⌘ + U (UI Test target)
```

### Manual Testing
- Разные комнаты (размеры, освещение)
- Разные расстояния (1m - 5m)
- Печать и установка паттернов

## Troubleshooting

### LiDAR не работает
- Проверить устройство (iPhone 12 Pro+)
- Проверить разрешения камеры
- Restart AR session

### Plane detection fails
- Улучшить освещение
- Двигаться медленнее
- Убедиться что угол чистый (не загроможден)

### Углы неправильные
- Проверить что это действительно 90° угол
- Убедиться что все 3 плоскости найдены
- Попробовать пересканировать

### PDF паттерны неправильного размера
- Проверить calibration page
- Убедиться что принтер печатает в масштабе 100%
- Использовать матовую бумагу

## Документация

См. `TZ.md` для полного технического задания с:
- Детальными алгоритмами
- UI mockups
- Data models
- Error handling
- Performance optimization

## Next Steps

1. **Создать новый чат** для работы над native iOS приложением
2. **Скопировать `TZ.md`** в новый проект
3. **Начать с Phase 1**: ARKit infrastructure

## Support

Для вопросов и помощи - начните новый чат с AI assistant с контекстом этого проекта.

---

**Статус:** ✅ ТЗ готово, структура создана, готов к разработке!

**Дата создания:** 2025-12-28
