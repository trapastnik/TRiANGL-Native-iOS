import ARKit
import RealityKit
import Combine

class ARManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var detectedPlanes: [UUID: PlaneInfo] = [:]
    @Published var cornerDetected = false
    @Published var cornerGeometry: CornerGeometry?
    @Published var statusMessage = "Направьте камеру на угол потолка"

    // Status indicators for UI
    @Published var hasCeiling = false
    @Published var hasWalls = false
    @Published var wallCount = 0

    // Plane visibility toggles
    @Published var showCeiling = true
    @Published var showWalls = true

    // Depth map visualization
    @Published var showDepthMap = false
    @Published var distanceToCorner: Float = 0.0

    // Depth settings
    let depthSettings = DepthSettings()

    // MARK: - AR Session
    let session = ARSession()

    private var settingsCancellable: AnyCancellable?

    // MARK: - Plane Detection
    var planeAnchors: [UUID: ARPlaneAnchor] = [:]
    private let minimumPlaneConfidence: Float = 0.8

    // MARK: - Initialization
    override init() {
        super.init()
        session.delegate = self

        // Listen to depth settings changes to reconfigure session
        settingsCancellable = depthSettings.$useSmoothedDepth.sink { [weak self] _ in
            self?.reconfigureDepthSemantics()
        }
    }

    // MARK: - Session Control
    func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            statusMessage = "ARKit не поддерживается на этом устройстве"
            return
        }

        let config = ARWorldTrackingConfiguration()

        // LiDAR configuration
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }

        // Enable depth data from LiDAR (configurable smoothing)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            if depthSettings.useSmoothedDepth {
                config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
            } else {
                config.frameSemantics = .sceneDepth
            }
        }

        // Plane detection
        config.planeDetection = [.horizontal, .vertical]

        // World tracking
        config.worldAlignment = .gravity

        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isScanning = true
        statusMessage = "Сканирование... Направьте камеру на угол"
    }

    func pauseSession() {
        session.pause()
        isScanning = false
    }

    func resetSession() {
        detectedPlanes.removeAll()
        planeAnchors.removeAll()
        cornerDetected = false
        cornerGeometry = nil
        statusMessage = "Направьте камеру на угол потолка"

        let config = session.configuration as? ARWorldTrackingConfiguration
        session.run(config ?? ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }

    private func reconfigureDepthSemantics() {
        guard let config = session.configuration as? ARWorldTrackingConfiguration else { return }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            if depthSettings.useSmoothedDepth {
                config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
            } else {
                config.frameSemantics = .sceneDepth
            }
        }

        session.run(config)
    }

    // MARK: - Plane Analysis
    private func analyzePlanes() {
        // Нужно найти 3 плоскости: потолок + 2 стены
        let horizontalPlanes = planeAnchors.values.filter { $0.classification == .ceiling }
        let verticalPlanes = planeAnchors.values.filter { $0.classification == .wall }

        guard horizontalPlanes.count >= 1, verticalPlanes.count >= 2 else {
            updateStatus()
            return
        }

        // Берем первый потолок и две ближайшие стены
        guard let ceiling = horizontalPlanes.first else { return }
        let walls = Array(verticalPlanes.prefix(2))

        // Проверяем что у нас есть 2 стены
        guard walls.count == 2 else {
            updateStatus()
            return
        }

        // Вычисляем углы между плоскостями
        let ceilingNormal = simd_make_float3(ceiling.transform.columns.1)
        let wall1Normal = simd_make_float3(walls[0].transform.columns.1)
        let wall2Normal = simd_make_float3(walls[1].transform.columns.1)

        let angleCeilingWall1 = angleBetweenVectors(ceilingNormal, wall1Normal)
        let angleCeilingWall2 = angleBetweenVectors(ceilingNormal, wall2Normal)
        let angleWalls = angleBetweenVectors(wall1Normal, wall2Normal)

        // Проверяем что углы близки к 90 градусам (с допуском ±15°)
        let tolerance: Float = 15.0
        let isValidCorner = abs(angleCeilingWall1 - 90.0) < tolerance &&
                           abs(angleCeilingWall2 - 90.0) < tolerance &&
                           abs(angleWalls - 90.0) < tolerance

        if isValidCorner {
            // Создаем геометрию угла
            createCornerGeometry(ceiling: ceiling, walls: walls)
            cornerDetected = true
            statusMessage = "✓ Угол найден! Углы: \(Int(angleCeilingWall1))°, \(Int(angleCeilingWall2))°, \(Int(angleWalls))°"
        } else {
            updateStatus()
        }
    }

    private func createCornerGeometry(ceiling: ARPlaneAnchor, walls: [ARPlaneAnchor]) {
        // Находим точку пересечения трех плоскостей (угол)
        let ceilingPlane = planeFromAnchor(ceiling)
        let wall1Plane = planeFromAnchor(walls[0])
        let wall2Plane = planeFromAnchor(walls[1])

        if let cornerVertex = findPlaneIntersection(ceilingPlane, wall1Plane, wall2Plane) {
            let geometry = CornerGeometry(
                cornerVertex: cornerVertex,
                ceilingPlane: ceilingPlane,
                leftWallPlane: wall1Plane,
                rightWallPlane: wall2Plane,
                angleCeilingLeft: angleBetweenPlanes(ceilingPlane, wall1Plane),
                angleCeilingRight: angleBetweenPlanes(ceilingPlane, wall2Plane),
                angleWalls: angleBetweenPlanes(wall1Plane, wall2Plane)
            )

            self.cornerGeometry = geometry

            // Calculate distance to corner from camera
            if let cameraTransform = session.currentFrame?.camera.transform {
                let cameraPosition = simd_make_float3(cameraTransform.columns.3)
                self.distanceToCorner = simd_distance(cameraPosition, cornerVertex)
            }
        }
    }

    private func updateStatus() {
        let horizontalCount = planeAnchors.values.filter { $0.classification == .ceiling }.count
        let verticalCount = planeAnchors.values.filter { $0.classification == .wall }.count

        // Update published properties for UI indicators
        hasCeiling = horizontalCount > 0
        hasWalls = verticalCount >= 2
        wallCount = verticalCount

        var status = "Найдено: "
        status += "Потолок: \(horizontalCount > 0 ? "✓" : "✗") | "
        status += "Стены: \(verticalCount)/2"

        if horizontalCount == 0 {
            status += "\nНаправьте камеру на потолок"
        } else if verticalCount < 2 {
            status += "\nМедленно поверните к углу стен"
        }

        statusMessage = status
    }

    // MARK: - Geometry Helpers
    private func angleBetweenVectors(_ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> Float {
        let dot = simd_dot(simd_normalize(v1), simd_normalize(v2))
        let angle = acos(min(max(dot, -1.0), 1.0))
        return angle * 180.0 / .pi
    }

    private func angleBetweenPlanes(_ p1: Plane, _ p2: Plane) -> Float {
        return angleBetweenVectors(p1.normal, p2.normal)
    }

    private func planeFromAnchor(_ anchor: ARPlaneAnchor) -> Plane {
        let normal = simd_make_float3(anchor.transform.columns.1)
        let position = simd_make_float3(anchor.transform.columns.3)
        let d = -simd_dot(normal, position)
        return Plane(normal: normal, d: d, anchor: anchor)
    }

    private func findPlaneIntersection(_ p1: Plane, _ p2: Plane, _ p3: Plane) -> SIMD3<Float>? {
        // Решаем систему линейных уравнений для нахождения точки пересечения трех плоскостей
        // p1: n1·x + d1 = 0
        // p2: n2·x + d2 = 0
        // p3: n3·x + d3 = 0

        let n1 = p1.normal
        let n2 = p2.normal
        let n3 = p3.normal

        let det = simd_dot(n1, simd_cross(n2, n3))

        guard abs(det) > 1e-6 else { return nil } // Planes are parallel or don't intersect at a point

        let intersection = (
            simd_cross(n2, n3) * (-p1.d) +
            simd_cross(n3, n1) * (-p2.d) +
            simd_cross(n1, n2) * (-p3.d)
        ) / det

        return intersection
    }
}

// MARK: - ARSessionDelegate
extension ARManager: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                planeAnchors[anchor.identifier] = planeAnchor

                let planeInfo = PlaneInfo(
                    id: anchor.identifier,
                    classification: planeAnchor.classification,
                    center: simd_make_float3(planeAnchor.transform.columns.3),
                    extent: planeAnchor.planeExtent.width,
                    normal: simd_make_float3(planeAnchor.transform.columns.1),
                    anchor: planeAnchor
                )

                DispatchQueue.main.async {
                    self.detectedPlanes[anchor.identifier] = planeInfo
                    self.analyzePlanes()
                }
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                planeAnchors[anchor.identifier] = planeAnchor

                let planeInfo = PlaneInfo(
                    id: anchor.identifier,
                    classification: planeAnchor.classification,
                    center: simd_make_float3(planeAnchor.transform.columns.3),
                    extent: planeAnchor.planeExtent.width,
                    normal: simd_make_float3(planeAnchor.transform.columns.1),
                    anchor: planeAnchor
                )

                DispatchQueue.main.async {
                    self.detectedPlanes[anchor.identifier] = planeInfo
                    self.analyzePlanes()
                }
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            planeAnchors.removeValue(forKey: anchor.identifier)

            DispatchQueue.main.async {
                self.detectedPlanes.removeValue(forKey: anchor.identifier)
                self.analyzePlanes()
            }
        }
    }
}

// MARK: - Supporting Types
struct PlaneInfo: Identifiable {
    let id: UUID
    let classification: ARPlaneAnchor.Classification
    let center: SIMD3<Float>
    let extent: Float
    let normal: SIMD3<Float>
    let anchor: ARPlaneAnchor?
}

struct Plane {
    let normal: SIMD3<Float>
    let d: Float
    let anchor: ARPlaneAnchor?
}

struct CornerGeometry {
    let cornerVertex: SIMD3<Float>
    let ceilingPlane: Plane
    let leftWallPlane: Plane
    let rightWallPlane: Plane
    let angleCeilingLeft: Float
    let angleCeilingRight: Float
    let angleWalls: Float
}
