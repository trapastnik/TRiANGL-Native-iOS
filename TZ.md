# ТЗ: TRiANGL - Native iOS App с LiDAR

## Описание проекта

**Название:** TRiANGL Native iOS
**Платформа:** iOS 14+ (iPhone 12 Pro и новее с LiDAR)
**Язык:** Swift + SwiftUI
**Технологии:** ARKit, RealityKit, SceneKit, LiDAR Scanner

---

## Основная концепция

Приложение для создания 3D оптических иллюзий в углах комнаты (потолок + две стены). Использует LiDAR для точного сканирования геометрии угла в реальном времени, вычисляет правильные углы между плоскостями, размещает 3D рисунок (куб) в AR, и генерирует PDF паттерны для печати.

---

## Функциональные требования

### 1. Live LiDAR сканирование угла (Главная функция)

#### 1.1 Real-time детектор углов и линий

**Задача:** Автоматическое обнаружение угла потолок-стена-стена в реальном времени

**Алгоритм:**
```swift
// Используя ARKit + LiDAR depth map
1. Получить depth map от LiDAR (CVPixelBuffer)
2. Построить 3D point cloud из depth data
3. Использовать RANSAC plane detection для нахождения 3 плоскостей:
   - Плоскость потолка
   - Плоскость левой стены
   - Плоскость правой стены
4. Найти линии пересечения между плоскостями:
   - Потолок ∩ Левая стена = Линия 1
   - Потолок ∩ Правая стена = Линия 2
   - Левая стена ∩ Правая стена = Линия 3 (вертикальная)
5. Найти точку пересечения всех 3 линий = Corner vertex (угол)
```

**Визуализация в реальном времени:**
- Зеленые линии вдоль пересечений потолка и стен
- Красная точка в углу (corner vertex)
- Полупрозрачные плоскости (потолок - голубой, стены - желтый)
- Текст с углами между плоскостями (должно быть ~90°)

**Требования к детекции:**
- Обновление 30-60 FPS (real-time)
- Точность определения плоскостей: ±2-3°
- Minimum confidence для плоскости: 80%
- Автоматическое подтверждение когда все 3 плоскости найдены с углами ~90° ± 5°

#### 1.2 Опциональное ручное указание угла

**Если автодетекция не работает:**
- Пользователь может тапнуть на экран чтобы указать примерное положение угла
- Приложение ищет ближайший реальный угол в радиусе 50см от указанной точки
- После нахождения угла - стандартный plane detection вокруг этой точки

**UI:**
```
[ Режим: Автоматическое сканирование ▼ ]
[ ] Ручное указание угла

Инструкция:
"Направьте камеру на угол потолка"
[Плоскости найдены: Потолок ✓ | Стена 1 ✓ | Стена 2 ✗]
[Угол между плоскостями: Потолок-Стена1: 91.2° | Потолок-Стена2: -- ]
```

---

### 2. Построение 3D геометрии угла

**Входные данные:**
- Corner vertex: 3D позиция (x, y, z) в world space
- 3 плоскости: каждая описывается уравнением Ax + By + Cz + D = 0
- Углы между плоскостями

**Выходные данные (Corner Geometry Object):**
```swift
struct CornerGeometry {
    // Основные данные
    let cornerVertex: SIMD3<Float>        // Позиция угла в world space
    let ceilingPlane: PlaneAnchor         // Плоскость потолка
    let leftWallPlane: PlaneAnchor        // Левая стена
    let rightWallPlane: PlaneAnchor       // Правая стена

    // Линии пересечения
    let ceilingLeftEdge: Line3D           // Потолок ∩ Левая стена
    let ceilingRightEdge: Line3D          // Потолок ∩ Правая стена
    let wallsEdge: Line3D                 // Левая стена ∩ Правая стена (вертикаль)

    // Углы (в градусах)
    let angleCeilingLeft: Float           // Угол между потолком и левой стеной (должен быть ~90°)
    let angleCeilingRight: Float          // Угол между потолком и правой стеной (должен быть ~90°)
    let angleWalls: Float                 // Угол между стенами (должен быть ~90°)

    // Размеры (для масштабирования куба)
    let ceilingDimensions: CGSize         // Размеры потолка в метрах
    let leftWallDimensions: CGSize        // Размеры левой стены
    let rightWallDimensions: CGSize       // Размеры правой стены

    // Метаданные
    let captureTime: Date
    let confidence: Float                 // 0.0 - 1.0
    let cameraPosition: SIMD3<Float>      // Позиция камеры при захвате
    let viewingDistance: Float            // Расстояние от камеры до угла
}
```

**Визуализация плоскостей:**
- Отрисовать 3 плоскости как SceneKit planes с полупрозрачным материалом
- Каждая плоскость ограничена реальными размерами комнаты (не бесконечная)
- Плоскости должны точно соответствовать реальным стенам/потолку

---

### 3. AR Preview - размещение 3D куба в углу

#### 3.1 Выбор дизайна куба

**Библиотека дизайнов:**
- 5-10 готовых 3D cube designs
- Каждый дизайн - это текстуры для 3 видимых граней куба
- Форматы: PNG/JPEG для текстур, USDZ для 3D моделей

**Пример дизайнов:**
1. **Geometric Grid** - черно-белая геометрическая сетка
2. **Necker Cube** - классическая оптическая иллюзия
3. **Escher Stairs** - невозможная лестница
4. **Floating Cube** - куб с тенями для эффекта левитации
5. **Portal** - иллюзия отверстия в углу

#### 3.2 Размещение куба в AR

**Параметры куба:**
```swift
struct CubeConfiguration {
    let size: Float                       // Размер ребра куба (0.3m - 1.0m)
    let position: SIMD3<Float>            // Позиция куба относительно угла
    let rotation: SIMD3<Float>            // Поворот куба (Euler angles)
    let designID: String                  // ID выбранного дизайна
}
```

**Алгоритм размещения:**
```swift
1. Вычислить optimal viewing position:
   - Обычно 2-3 метра от угла
   - На уровне глаз (1.5-1.7м от пола)
   - По центру между двумя стенами

2. Разместить куб так, чтобы его угол совпадал с corner vertex

3. Ориентировать куб:
   - Одна грань параллельна потолку
   - Две грани параллельны стенам

4. Применить perspective projection:
   - Куб должен выглядеть 3D из viewing position
   - Из других точек может выглядеть искаженным (это нормально для anamorphic art)
```

**AR Визуализация:**
- 3D куб отрисован в SceneKit/RealityKit
- Cube привязан к corner vertex через ARAnchor
- Real-time обновление позиции если угол двигается
- Возможность rotate/scale куба жестами (pinch, rotate)

**UI Controls:**
```
[AR View с кубом]

Внизу экрана:
┌────────────────────────────────┐
│ Размер: [─────●─────] 0.5m     │
│ Дизайн: [< Geometric Grid >]   │
│ [ Изменить позицию ]           │
│ [ Сбросить ]  [ ✓ Утвердить ]  │
└────────────────────────────────┘
```

#### 3.3 Viewing Position Indicator

**Показать пользователю оптимальную точку просмотра:**
- Маркер на полу (AR plane) на расстоянии 2-3м от угла
- Стрелка указывающая куда смотреть
- Текст: "Встаньте здесь для лучшего эффекта"

**Реализация:**
```swift
// Найти пол через ARPlaneAnchor (horizontal)
// Разместить ARReferenceImage или custom 3D marker на полу
// Позиция: projectedGroundPosition от viewing position
```

---

### 4. Генерация PDF паттернов для печати

#### 4.1 Unwrap 3D куба в 2D паттерны

**Задача:** Преобразовать 3D текстуры куба в 2D паттерны, которые при наклейке на реальный угол будут создавать иллюзию 3D

**Математика (Anamorphic Projection):**

```swift
// Для каждой видимой грани куба:
// 1. Ceiling face (грань параллельная потолку)
// 2. Left wall face (грань параллельная левой стене)
// 3. Right wall face (грань параллельная правой стене)

func projectFaceToWall(
    cubeFace: CubeFace,
    targetPlane: PlaneAnchor,
    viewingPosition: SIMD3<Float>
) -> UIImage {
    // 1. Для каждого пикселя текстуры куба:
    //    - Найти его 3D позицию на кубе
    //    - Провести луч от viewing position через эту точку
    //    - Найти пересечение луча с target plane (потолок/стена)
    //    - Это и будет позиция пикселя в 2D паттерне

    // 2. Результат: distorted image который выглядит правильно только из viewing position
}
```

**Формат вывода:**
- 3 отдельных PDF файла (по одному на каждую плоскость)
- Или 1 PDF с 3 страницами
- Каждая страница содержит:
  - Distorted паттерн для печати
  - Alignment marks (метки для выравнивания при наклейке)
  - Инструкции по размещению
  - Размеры в сантиметрах
  - QR код с параметрами для переноса проекта

**Калибровка принтера:**
```
Страница 0: Calibration page
┌────────────────────────┐
│   [10cm × 10cm square] │
│                        │
│ Распечатайте и измерьте│
│ линейкой. Если размер  │
│ не точно 10×10см,      │
│ скорректируйте масштаб │
│ печати принтера.       │
└────────────────────────┘
```

#### 4.2 Структура PDF файла

**Страница 1: Ceiling Pattern**
```
┌─────────────────────────────────────┐
│ TRiANGL - Ceiling Pattern           │
│                                     │
│  ┌───────────────────────────┐     │
│  │                           │     │
│  │  [Distorted cube texture] │     │
│  │                           │     │
│  │  ● ──────────────────── ● │     │
│  │  │   Alignment marks   │ │     │
│  │  ● ──────────────────── ● │     │
│  └───────────────────────────┘     │
│                                     │
│ Инструкция:                         │
│ 1. Вырезать по контуру              │
│ 2. Приклеить к потолку              │
│ 3. Совместить ● с углом комнаты     │
│                                     │
│ Размеры: 45.2 × 38.7 см             │
└─────────────────────────────────────┘
```

**Страница 2: Left Wall Pattern**
```
Аналогично, но для левой стены
```

**Страница 3: Right Wall Pattern**
```
Аналогично, но для правой стены
```

**Страница 4: Assembly Instructions**
```
┌─────────────────────────────────────┐
│ Инструкция по сборке                │
│                                     │
│ [Diagram показывающий порядок       │
│  наклейки паттернов]                │
│                                     │
│ 1. Ceiling pattern → потолок        │
│ 2. Left wall pattern → левая стена  │
│ 3. Right wall pattern → правая стена│
│                                     │
│ Viewing position: 2.8m от угла      │
│ (встаньте на маркер на полу)        │
│                                     │
│ [QR код для повторного              │
│  открытия проекта в AR]             │
└─────────────────────────────────────┘
```

---

### 5. Workflow приложения (User Journey)

```
┌─────────────────────────────────────────────────────────┐
│ Экран 1: Welcome Screen                                 │
│ ┌─────────────────────────────────────────────────────┐ │
│ │          TRiANGL                                    │ │
│ │    Create 3D Corner Illusions                       │ │
│ │                                                     │ │
│ │           [Start Scanning]                          │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Экран 2: LiDAR Corner Scanning                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │  [AR View - live camera feed]                       │ │
│ │                                                     │ │
│ │  Зеленые линии вдоль потолка/стен (live)           │ │
│ │  Красная точка в углу                              │ │
│ │  Полупрозрачные плоскости                          │ │
│ │                                                     │ │
│ │  ┌───────────────────────────────────────┐         │ │
│ │  │ Обнаружено:                            │         │ │
│ │  │ ✓ Потолок (угол: 90.2°)               │         │ │
│ │  │ ✓ Левая стена (угол: 89.8°)           │         │ │
│ │  │ ⏳ Правая стена (поиск...)            │         │ │
│ │  └───────────────────────────────────────┘         │ │
│ │                                                     │ │
│ │  Инструкция:                                       │ │
│ │  "Направьте камеру на угол потолка"                │ │
│ │  "Медленно двигайтесь ближе (2-4 метра от угла)"   │ │
│ │                                                     │ │
│ │  [ Режим: Авто ▼ ]  [ ? Помощь ]                  │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ Когда все 3 плоскости найдены:                          │
│ [✓ Захватить угол]                                      │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Экран 3: Corner Geometry Review                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │  [3D visualization угла с плоскостями]              │ │
│ │                                                     │ │
│ │  Углы между плоскостями:                           │ │
│ │  • Потолок ∩ Левая стена: 90.2° ✓                 │ │
│ │  • Потолок ∩ Правая стена: 89.8° ✓                │ │
│ │  • Левая стена ∩ Правая стена: 90.1° ✓            │ │
│ │                                                     │ │
│ │  Размеры:                                          │ │
│ │  • Потолок: 3.2m × 2.8m                           │ │
│ │  • Левая стена: 3.2m × 2.7m (высота)              │ │
│ │  • Правая стена: 2.8m × 2.7m (высота)             │ │
│ │                                                     │ │
│ │  Расстояние от камеры: 3.5m                        │ │
│ │  Confidence: 94%                                   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ [ ← Пересканировать ]  [ Продолжить → ]                 │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Экран 4: Cube Design Selection                           │
│ ┌─────────────────────────────────────────────────────┐ │
│ │  Выберите дизайн куба:                             │ │
│ │                                                     │ │
│ │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐           │ │
│ │  │ Grid │  │Necker│  │Escher│  │Portal│           │ │
│ │  │ Cube │  │ Cube │  │Stairs│  │ Cube │           │ │
│ │  └──────┘  └──────┘  └──────┘  └──────┘           │ │
│ │     ●                                               │ │
│ │                                                     │ │
│ │  [Preview 3D model]                                │ │
│ │                                                     │ │
│ │  Размер куба: [──────●─────] 0.5m                  │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ [ ← Назад ]  [ AR Preview → ]                           │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Экран 5: AR Preview                                      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │  [AR View - live camera + 3D cube в углу]          │ │
│ │                                                     │ │
│ │  Куб размещен в углу потолка                       │ │
│ │  Выглядит реалистично 3D                           │ │
│ │                                                     │ │
│ │  Маркер на полу:                                   │ │
│ │  "👁️ Встаньте здесь для лучшего просмотра"        │ │
│ │                                                     │ │
│ │  ┌───────────────────────────────────────┐         │ │
│ │  │ Размер: [─────●─────] 0.5m            │         │ │
│ │  │ Дизайн: [< Geometric Grid >]          │         │ │
│ │  │                                        │         │ │
│ │  │ [ 🔄 Повернуть ] [ 📏 Изменить размер] │         │ │
│ │  │ [ 🔙 Назад ]     [ ✓ Готово ]         │         │ │
│ │  └───────────────────────────────────────┘         │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Экран 6: Generate Patterns                               │
│ ┌─────────────────────────────────────────────────────┐ │
│ │  Генерация паттернов для печати...                 │ │
│ │                                                     │ │
│ │  ⏳ Вычисление anamorphic projection...            │ │
│ │  ✓ Ceiling pattern готов                           │ │
│ │  ✓ Left wall pattern готов                         │ │
│ │  ⏳ Right wall pattern (45%)                       │ │
│ │                                                     │ │
│ │  [Progress bar]                                    │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│ Экран 7: PDF Export                                      │
│ ┌─────────────────────────────────────────────────────┐ │
│ │  ✓ Паттерны готовы!                                │ │
│ │                                                     │ │
│ │  ┌────────┐  ┌────────┐  ┌────────┐               │ │
│ │  │Ceiling │  │  Left  │  │ Right  │               │ │
│ │  │Pattern │  │  Wall  │  │  Wall  │               │ │
│ │  └────────┘  └────────┘  └────────┘               │ │
│ │                                                     │ │
│ │  Рекомендации:                                     │ │
│ │  • Печатать на формате A3                          │ │
│ │  • Матовая бумага (плотность 180-250 г/м²)         │ │
│ │  • Масштаб: 100% (без подгонки)                    │ │
│ │  • Цветная печать                                  │ │
│ │                                                     │ │
│ │  [ 💾 Сохранить PDF ]                              │ │
│ │  [ 📧 Отправить на email ]                         │ │
│ │  [ 🖨️ Печатать через AirPrint ]                   │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                          │
│ [ ← Изменить дизайн ]  [ ✓ Готово ]                    │
└─────────────────────────────────────────────────────────┘
```

---

## Технические требования

### Минимальные требования к устройству

- **Устройство:** iPhone 12 Pro, iPhone 12 Pro Max, iPhone 13 Pro, iPhone 13 Pro Max, iPhone 14 Pro, iPhone 14 Pro Max, iPhone 15 Pro, iPhone 15 Pro Max (любое устройство с LiDAR scanner)
- **iOS:** 14.0+
- **Свободное место:** 200 MB
- **Камера:** Доступ к камере required
- **Разрешения:** Camera, Motion (для ARKit)

### Фреймворки и технологии

```swift
import ARKit          // AR session, plane detection
import RealityKit     // 3D rendering, AR anchors
import SceneKit       // 3D геометрия, материалы
import Vision         // Для edge detection (опционально)
import PDFKit         // Генерация PDF
import Accelerate     // Математические операции (векторы, матрицы)
```

### Архитектура приложения

```
TRiANGL-Native/
├── App/
│   ├── TRiANGLApp.swift              // @main
│   └── ContentView.swift
│
├── Views/
│   ├── WelcomeView.swift
│   ├── ScannerView.swift             // LiDAR scanning AR view
│   ├── GeometryReviewView.swift      // Review captured corner
│   ├── DesignPickerView.swift        // Cube design selection
│   ├── ARPreviewView.swift           // AR cube preview
│   └── ExportView.swift              // PDF generation & export
│
├── AR/
│   ├── ARManager.swift               // Main ARKit manager
│   ├── LiDARScanner.swift            // LiDAR depth processing
│   ├── PlaneDetector.swift           // Real-time plane detection
│   ├── CornerDetector.swift          // Corner vertex detection
│   └── ARViewController.swift        // UIViewControllerRepresentable wrapper
│
├── Models/
│   ├── CornerGeometry.swift          // Data model для угла
│   ├── CubeDesign.swift              // Cube design metadata
│   └── PlaneAnchor.swift             // Plane data model
│
├── Services/
│   ├── GeometryCalculator.swift      // 3D math (angles, intersections)
│   ├── AnamorphicProjector.swift     // 3D → 2D projection для печати
│   ├── PDFGenerator.swift            // PDF creation
│   └── ProjectManager.swift          // Save/load projects
│
├── Utilities/
│   ├── MathExtensions.swift          // SIMD, matrix operations
│   ├── ARExtensions.swift            // ARKit helpers
│   └── GeometryHelpers.swift         // Line, plane intersection algorithms
│
├── Resources/
│   ├── CubeDesigns/
│   │   ├── geometric_grid.usdz
│   │   ├── necker_cube.usdz
│   │   └── ...
│   └── Assets.xcassets
│
└── Tests/
    ├── GeometryTests.swift
    └── ProjectionTests.swift
```

---

## Ключевые алгоритмы

### 1. RANSAC Plane Detection

```swift
func detectPlanes(from pointCloud: [SIMD3<Float>]) -> [PlaneAnchor] {
    var planes: [PlaneAnchor] = []
    var remainingPoints = pointCloud

    // Найти до 3 основных плоскостей (потолок + 2 стены)
    for _ in 0..<3 {
        guard let plane = findBestPlane(in: remainingPoints) else { break }

        planes.append(plane)

        // Удалить inliers из point cloud
        remainingPoints = remainingPoints.filter { point in
            distanceToPlane(point, plane) > 0.05 // 5cm threshold
        }
    }

    return planes
}

func findBestPlane(in points: [SIMD3<Float>]) -> PlaneAnchor? {
    let iterations = 1000
    var bestPlane: PlaneAnchor?
    var maxInliers = 0

    for _ in 0..<iterations {
        // Выбрать 3 случайные точки
        let sample = points.randomSample(count: 3)

        // Вычислить плоскость через эти 3 точки
        guard let plane = planeFrom3Points(sample) else { continue }

        // Посчитать inliers (точки близкие к плоскости)
        let inliers = points.filter { point in
            distanceToPlane(point, plane) < 0.05 // 5cm
        }

        if inliers.count > maxInliers {
            maxInliers = inliers.count
            bestPlane = plane
        }
    }

    // Re-fit плоскость используя все inliers (least squares)
    if let plane = bestPlane {
        let inliers = points.filter { distanceToPlane($0, plane) < 0.05 }
        return refinePlane(plane, with: inliers)
    }

    return nil
}
```

### 2. Line-Line Intersection (Corner Vertex Detection)

```swift
func findCornerVertex(
    ceilingLeftEdge: Line3D,
    ceilingRightEdge: Line3D,
    wallsEdge: Line3D
) -> SIMD3<Float>? {
    // Найти точку максимально близкую ко всем 3 линиям
    // Используя least squares minimization

    // Для двух линий L1, L2:
    // Точка P на L1: P1 = origin1 + t1 * direction1
    // Точка Q на L2: P2 = origin2 + t2 * direction2
    // Минимизировать: |P1 - P2|^2

    // Решение для 3 линий → overdetermined system
    // Использовать pseudo-inverse

    let A = matrix_float3x3(rows: [
        ceilingLeftEdge.direction,
        ceilingRightEdge.direction,
        wallsEdge.direction
    ])

    let b = SIMD3<Float>(
        dot(ceilingLeftEdge.origin, ceilingLeftEdge.direction),
        dot(ceilingRightEdge.origin, ceilingRightEdge.direction),
        dot(wallsEdge.origin, wallsEdge.direction)
    )

    // Solve A^T A x = A^T b
    let ATA = A.transpose * A
    let ATb = A.transpose * b

    guard let inverse = ATA.inverse else { return nil }
    let cornerVertex = inverse * ATb

    return cornerVertex
}
```

### 3. Anamorphic Projection (3D → 2D для печати)

```swift
func projectCubeFaceToWall(
    cubeFace: UIImage,
    cubeGeometry: CubeGeometry,
    targetPlane: PlaneAnchor,
    viewingPosition: SIMD3<Float>
) -> UIImage {
    let width = Int(targetPlane.extent.width * 100) // pixels (100 ppi)
    let height = Int(targetPlane.extent.height * 100)

    let outputImage = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        .image { context in

        // Для каждого пикселя output image
        for y in 0..<height {
            for x in 0..<width {
                // 1. Конвертировать pixel coordinates → world position на target plane
                let worldPos = pixelToWorld(x: x, y: y, plane: targetPlane)

                // 2. Луч от viewing position через world position
                let ray = Ray(origin: viewingPosition, direction: normalize(worldPos - viewingPosition))

                // 3. Найти пересечение луча с кубом (с нужной гранью)
                guard let intersection = ray.intersect(cubeFace: cubeGeometry.face) else {
                    continue
                }

                // 4. UV coordinates на грани куба
                let uv = cubeGeometry.worldToUV(intersection)

                // 5. Sample цвет из cube texture
                let color = cubeFace.colorAt(uv: uv)

                // 6. Нарисовать пиксель
                context.cgContext.setFillColor(color.cgColor)
                context.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }

    return outputImage
}
```

---

## Data Models

### CornerGeometry.swift

```swift
import Foundation
import ARKit

struct CornerGeometry: Codable {
    // Основные данные
    let cornerVertex: SIMD3<Float>

    // Плоскости (сохраняем параметры уравнения Ax + By + Cz + D = 0)
    struct PlaneParameters: Codable {
        let normal: SIMD3<Float>  // (A, B, C) normalized
        let distance: Float        // D
        let center: SIMD3<Float>   // Центр плоскости
        let extent: SIMD2<Float>   // Размеры (width, height)
    }

    let ceilingPlane: PlaneParameters
    let leftWallPlane: PlaneParameters
    let rightWallPlane: PlaneParameters

    // Углы между плоскостями (градусы)
    let angleCeilingLeft: Float
    let angleCeilingRight: Float
    let angleWalls: Float

    // Метаданные
    let captureDate: Date
    let confidence: Float
    let cameraPosition: SIMD3<Float>
    let viewingDistance: Float

    // Computed properties
    var isValidCorner: Bool {
        // Все углы должны быть близки к 90°
        let tolerance: Float = 10.0 // градусов
        return abs(angleCeilingLeft - 90) < tolerance &&
               abs(angleCeilingRight - 90) < tolerance &&
               abs(angleWalls - 90) < tolerance
    }

    var averageAngle: Float {
        return (angleCeilingLeft + angleCeilingRight + angleWalls) / 3.0
    }
}
```

### CubeDesign.swift

```swift
import UIKit

struct CubeDesign: Identifiable {
    let id: String
    let name: String
    let description: String
    let thumbnail: UIImage

    // Текстуры для 3 видимых граней
    let topFaceTexture: UIImage      // Грань параллельная потолку
    let leftFaceTexture: UIImage     // Грань параллельная левой стене
    let rightFaceTexture: UIImage    // Грань параллельная правой стене

    // 3D модель (опционально, для preview)
    let modelURL: URL?

    // Метаданные
    let isPremium: Bool
    let category: Category

    enum Category: String {
        case geometric = "Geometric"
        case illusion = "Optical Illusion"
        case artistic = "Artistic"
        case custom = "Custom"
    }
}
```

---

## Оптимизация производительности

### LiDAR Processing

```swift
// Обрабатывать depth map не каждый кадр
var frameCount = 0
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    frameCount += 1

    // Обновлять plane detection каждые 5 кадров (12 FPS вместо 60)
    if frameCount % 5 == 0 {
        processDepthMap(frame.sceneDepth?.depthMap)
    }
}

// Использовать downsampled depth map для plane detection
func processDepthMap(_ depthMap: CVPixelBuffer?) {
    guard let depthMap = depthMap else { return }

    // Downsample 2x для faster processing
    let downsampled = downsample(depthMap, factor: 2)

    // Point cloud generation
    let pointCloud = depthMapToPointCloud(downsampled)

    // Plane detection
    detectPlanes(from: pointCloud)
}
```

### AR Rendering

```swift
// Использовать LOD (Level of Detail) для 3D куба
// Простая геометрия в real-time preview
// Детальная геометрия для final render

class CubeRenderer {
    let simpleCube = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0)
    let detailedCube = loadDetailedCubeModel()

    var currentCube: SCNNode {
        return isPreviewMode ? simpleCube : detailedCube
    }
}
```

---

## Testing Plan

### Unit Tests

```swift
// GeometryTests.swift
func testPlaneIntersection() {
    let plane1 = PlaneParameters(normal: SIMD3(0, 1, 0), distance: 0) // Horizontal
    let plane2 = PlaneParameters(normal: SIMD3(1, 0, 0), distance: 0) // Vertical

    let intersection = calculateIntersectionLine(plane1, plane2)

    XCTAssertNotNil(intersection)
    // Intersection line должна быть вдоль Z axis
    XCTAssertEqual(intersection?.direction, SIMD3(0, 0, 1))
}

func testAngleBetweenPlanes() {
    let ceiling = PlaneParameters(normal: SIMD3(0, 1, 0), distance: 2.7)
    let wall = PlaneParameters(normal: SIMD3(1, 0, 0), distance: 0)

    let angle = angleBetweenPlanes(ceiling, wall)

    XCTAssertEqual(angle, 90.0, accuracy: 0.1)
}
```

### Integration Tests

```swift
// Тестировать с известной 3D сценой
func testCornerDetectionWithSyntheticData() {
    // Создать synthetic point cloud для идеального 90° угла
    let pointCloud = generateSyntheticCorner(angle: 90.0)

    let detector = CornerDetector()
    let result = detector.detectCorner(from: pointCloud)

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.averageAngle, 90.0, accuracy: 1.0)
}
```

### Manual Testing Checklist

- [ ] Тест в разных комнатах (разные размеры, освещение)
- [ ] Тест на разных расстояниях (1m, 2m, 3m, 4m, 5m)
- [ ] Тест с разными углами (не только 90°)
- [ ] Тест с текстурированными стенами (обои, краска)
- [ ] Тест с плохим освещением
- [ ] Тест PDF генерации и печати (проверить масштаб)
- [ ] Тест AR preview из разных позиций
- [ ] Тест сохранения/загрузки проектов

---

## UI/UX Guidelines

### Colors

```swift
extension Color {
    static let primary = Color(hex: "4F46E5")      // Indigo
    static let secondary = Color(hex: "06B6D4")    // Cyan
    static let success = Color(hex: "10B981")      // Green
    static let warning = Color(hex: "F59E0B")      // Amber
    static let error = Color(hex: "EF4444")        // Red

    static let planeColor = Color.cyan.opacity(0.3)
    static let lineColor = Color.green
    static let cornerColor = Color.red
}
```

### Typography

```swift
extension Font {
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title = Font.system(size: 28, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
}
```

### AR Overlay Elements

- **Плоскости:** Полупрозрачные (alpha: 0.3), с wireframe edges
- **Линии:** Толщина 4pt, яркие цвета (зеленый, синий)
- **Corner vertex:** Красный sphere radius 3cm
- **Text overlays:** Черный текст на белом полупрозрачном фоне (alpha: 0.8)
- **Viewing position marker:** Анимированный circle на полу с пульсацией

---

## Error Handling

### Errors to Handle

```swift
enum TRiANGLError: Error {
    // LiDAR scanning errors
    case lidarNotAvailable
    case arSessionFailed
    case planeDetectionFailed
    case cornerNotFound
    case insufficientDepthData

    // Geometry errors
    case invalidCornerAngle(Float)
    case planesNotPerpendicular
    case geometryCalculationFailed

    // PDF generation errors
    case projectionFailed
    case pdfGenerationFailed
    case insufficientResolution

    // User errors
    case tooFarFromCorner(distance: Float)
    case poorLighting
    case cameraMovingTooFast

    var localizedDescription: String {
        switch self {
        case .lidarNotAvailable:
            return "LiDAR scanner not available. This app requires iPhone 12 Pro or newer."
        case .cornerNotFound:
            return "Could not detect corner. Please point camera at ceiling corner where two walls meet."
        case .invalidCornerAngle(let angle):
            return "Corner angle is \(angle)°. Expected ~90°. Try scanning a different corner."
        case .tooFarFromCorner(let distance):
            return "Too far from corner (\(distance)m). Move closer (2-4 meters optimal)."
        default:
            return "An error occurred. Please try again."
        }
    }
}
```

### User-Friendly Error Messages

```swift
struct ErrorView: View {
    let error: TRiANGLError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconForError(error))
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .padding()

            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

---

## Дополнительные функции (Future Features)

### Phase 2 Features

1. **Custom cube designs:**
   - Пользователь загружает свои текстуры
   - Simple texture editor (filters, adjustments)

2. **Multiple corner support:**
   - Scan multiple corners в одной комнате
   - Create coordinated illusions

3. **Professional printing service:**
   - Интеграция с печатными сервисами
   - Прямой заказ печати из приложения

4. **Social sharing:**
   - Share AR preview videos
   - Gallery of user creations

5. **Variable corner angles:**
   - Support для non-90° corners
   - Более сложная математика

### Phase 3 Features

1. **Full room scanning:**
   - Scan entire room geometry
   - Multiple cubes positioned throughout room

2. **Animated illusions:**
   - Patterns that appear to move
   - Time-based animations

3. **Marketplace:**
   - Buy/sell cube designs
   - Premium patterns от artists

---

## Deliverables

### For Developer

1. **Source Code:**
   - Полный Xcode project
   - Все файлы и ресурсы
   - README с инструкциями

2. **Documentation:**
   - API documentation (comments)
   - Architecture overview
   - Math algorithms explained

3. **Assets:**
   - 5-10 готовых cube designs
   - App icons (все размеры)
   - Screenshots для App Store

### For End User

1. **iOS App:**
   - Functional native app
   - TestFlight beta или App Store release

2. **User Guide:**
   - In-app tutorial
   - Video tutorials (optional)
   - FAQ

3. **PDF Templates:**
   - Calibration page
   - Assembly instructions template

---

## Timeline Estimate

### Week 1-2: Core AR Infrastructure
- ✅ ARKit setup
- ✅ LiDAR depth processing
- ✅ Basic plane detection
- ✅ Point cloud generation

### Week 3-4: Corner Detection
- ✅ RANSAC plane detection
- ✅ Line-line intersection
- ✅ Corner vertex detection
- ✅ Real-time visualization

### Week 5-6: Geometry & Math
- ✅ Angle calculations
- ✅ Plane parameters
- ✅ Corner geometry model
- ✅ Validation logic

### Week 7-8: AR Cube Preview
- ✅ Cube 3D models
- ✅ AR placement
- ✅ Viewing position calculation
- ✅ Interactive controls

### Week 9-10: Anamorphic Projection
- ✅ 3D → 2D projection algorithm
- ✅ Texture mapping
- ✅ Pattern generation

### Week 11-12: PDF Generation
- ✅ PDF creation
- ✅ Multi-page layout
- ✅ Calibration page
- ✅ Assembly instructions

### Week 13-14: UI/UX Polish
- ✅ All screens implemented
- ✅ Smooth transitions
- ✅ Error handling
- ✅ User testing

### Week 15-16: Testing & Release
- ✅ Bug fixes
- ✅ Performance optimization
- ✅ App Store submission
- ✅ Documentation

**Total: ~4 months development time**

---

## Success Criteria

### Technical Metrics

- ✅ Corner detection success rate: >90% in standard rooms
- ✅ Plane detection accuracy: ±3° from true angle
- ✅ Frame rate: 30+ FPS during AR scanning
- ✅ PDF generation time: <30 seconds
- ✅ App size: <200 MB

### User Experience Metrics

- ✅ Time to complete full workflow: <10 minutes
- ✅ First-time user success rate: >80%
- ✅ Print-to-install success rate: >85%
- ✅ User satisfaction: 4.5+ stars (App Store)

### Quality Metrics

- ✅ Crash rate: <1%
- ✅ Battery usage: <10% per session
- ✅ Memory usage: <500 MB peak
- ✅ No memory leaks

---

## Contact & Support

**Developer:** [Your Name]
**Email:** support@triangl.app
**GitHub:** https://github.com/yourusername/triangl-native
**TestFlight:** [Beta testing link]

---

## Appendix: Math Reference

### Plane Equation
```
Ax + By + Cz + D = 0

где (A, B, C) = normal vector (normalized)
D = -dot(normal, point_on_plane)
```

### Distance from Point to Plane
```swift
func distance(point: SIMD3<Float>, to plane: PlaneParameters) -> Float {
    return abs(dot(plane.normal, point) + plane.distance)
}
```

### Line-Plane Intersection
```swift
func intersect(line: Line3D, with plane: PlaneParameters) -> SIMD3<Float>? {
    let denom = dot(line.direction, plane.normal)

    // Линия параллельна плоскости
    if abs(denom) < 1e-6 { return nil }

    let t = -(dot(line.origin, plane.normal) + plane.distance) / denom

    return line.origin + t * line.direction
}
```

### Angle Between Planes
```swift
func angle(between plane1: PlaneParameters, and plane2: PlaneParameters) -> Float {
    let cosAngle = abs(dot(plane1.normal, plane2.normal))
    let angleRadians = acos(cosAngle)
    return angleRadians * 180.0 / .pi
}
```

---

**Конец ТЗ**

Это полное техническое задание для native iOS приложения TRiANGL с LiDAR. Все основные функции, алгоритмы, и UI описаны. Готово для начала разработки в новом проекте!
