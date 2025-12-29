# TRiANGL Architecture

## High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│                    TRiANGL App                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Views      │  │   Models     │  │   Services   │ │
│  │  (SwiftUI)   │  │   (Data)     │  │   (Logic)    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│         │                  │                  │         │
│         └──────────────────┴──────────────────┘         │
│                         │                               │
│                  ┌──────▼──────┐                        │
│                  │  AR Manager │                        │
│                  └──────┬──────┘                        │
│                         │                               │
│  ┌──────────────────────┴──────────────────────┐       │
│  │                 ARKit                        │       │
│  │  - LiDAR Scanner                             │       │
│  │  - Plane Detection                           │       │
│  │  - Scene Reconstruction                      │       │
│  └──────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

## Layers

### 1. Presentation Layer (Views)
- SwiftUI views
- AR view containers
- UI controls
- Navigation

### 2. Business Logic Layer (Services)
- Geometry calculations
- Corner detection
- PDF generation
- Anamorphic projection

### 3. Data Layer (Models)
- CornerGeometry
- CubeDesign
- PlaneParameters
- Project data

### 4. AR Layer (ARKit)
- ARSession management
- LiDAR depth processing
- Plane detection
- 3D rendering

## Data Flow

```
User Action (SwiftUI)
    ↓
View updates State
    ↓
ARManager receives command
    ↓
ARKit processes LiDAR data
    ↓
Service processes geometry
    ↓
Model updated
    ↓
View re-renders
```

## Key Components

### ARManager
- Singleton managing AR session
- Handles LiDAR depth capture
- Publishes AR state updates

### CornerDetector
- Processes point cloud
- RANSAC plane detection
- Corner vertex calculation

### GeometryCalculator
- Angle calculations
- Plane intersections
- 3D math utilities

### AnamorphicProjector
- 3D → 2D projection
- Texture mapping
- Pattern generation

### PDFGenerator
- Multi-page PDF creation
- Calibration page
- Assembly instructions

## State Management

Using SwiftUI @StateObject and @ObservedObject:

```swift
// ARManager is @StateObject (owns lifecycle)
@StateObject var arManager = ARManager()

// Models are @Published in ARManager
@Published var cornerGeometry: CornerGeometry?
@Published var currentPlanes: [PlaneParameters] = []
```

## Threading

- **Main Thread:** UI updates, SwiftUI
- **AR Thread:** ARSession delegate callbacks
- **Background Thread:** Heavy processing (projection, PDF)

```swift
// Heavy work on background
DispatchQueue.global(qos: .userInitiated).async {
    let pattern = projectCubeFaceToWall(...)

    // UI update on main
    DispatchQueue.main.async {
        self.generatedPattern = pattern
    }
}
```

## Error Handling

Centralized error handling:

```swift
enum TRiANGLError: Error {
    case lidarNotAvailable
    case cornerNotFound
    // ...
}

// Propagate to UI
@Published var currentError: TRiANGLError?
```

## Dependencies

- **ARKit** - AR capabilities
- **RealityKit** - 3D rendering
- **SceneKit** - 3D geometry
- **PDFKit** - PDF generation
- **Accelerate** - Math operations

## Design Patterns

- **MVVM** - Model-View-ViewModel (SwiftUI)
- **Singleton** - ARManager
- **Observer** - Combine publishers
- **Factory** - Cube design creation
- **Strategy** - Different projection algorithms

## Testing Strategy

- **Unit Tests** - Models, math utilities
- **Integration Tests** - ARManager, services
- **UI Tests** - User workflows
- **Manual Tests** - Real-world AR scanning

## Performance Considerations

- Downsample LiDAR depth for faster processing
- Use LOD (Level of Detail) for 3D models
- Process heavy tasks on background threads
- Cache computed results
- Limit AR updates to 12-30 FPS

## Security & Privacy

- Camera/Motion permissions required
- No data sent to servers (fully local)
- Optional project save (local only)
- No analytics/tracking

---

See `TZ.md` for detailed implementation specs.
