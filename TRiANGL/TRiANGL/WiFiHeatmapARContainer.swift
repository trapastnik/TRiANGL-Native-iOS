import SwiftUI
import RealityKit
import ARKit

// MARK: - WiFi Heatmap AR Container

struct WiFiHeatmapARContainer: UIViewRepresentable {
    @ObservedObject var heatmapManager: WiFiHeatmapManager
    let showGrid: Bool
    let showDeadZones: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        arView.session.run(config)

        // Set coordinator
        context.coordinator.arView = arView
        context.coordinator.heatmapManager = heatmapManager

        // Pass session to manager
        Task { @MainActor in
            heatmapManager.arSession = arView.session
        }

        // Start camera position updates
        arView.session.delegate = context.coordinator

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.updateVisualization(
            showGrid: showGrid,
            showDeadZones: showDeadZones
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(heatmapManager: heatmapManager)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, ARSessionDelegate {
        var arView: ARView?
        var heatmapManager: WiFiHeatmapManager

        private var heatmapAnchor: AnchorEntity?
        private var cellEntities: [UUID: ModelEntity] = [:]
        private var deadZoneEntities: [UUID: ModelEntity] = [:]

        init(heatmapManager: WiFiHeatmapManager) {
            self.heatmapManager = heatmapManager
            super.init()
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Update camera position
            let transform = frame.camera.transform
            let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            Task { @MainActor in
                heatmapManager.updateCameraPosition(position)
            }
        }

        @MainActor
        func updateVisualization(showGrid: Bool, showDeadZones: Bool) {
            guard let arView = arView else { return }

            // Create or get anchor
            if heatmapAnchor == nil {
                heatmapAnchor = AnchorEntity(world: .zero)
                arView.scene.addAnchor(heatmapAnchor!)
            }

            // Update heatmap cells
            updateHeatmapCells(showGrid: showGrid)

            // Update dead zones
            if showDeadZones {
                updateDeadZones()
            } else {
                clearDeadZones()
            }
        }

        @MainActor
        private func updateHeatmapCells(showGrid: Bool) {
            guard let anchor = heatmapAnchor else { return }

            // Remove outdated cells
            let currentCellIDs = Set(heatmapManager.heatmapCells.map { $0.id })
            let entitiesToRemove = cellEntities.keys.filter { !currentCellIDs.contains($0) }
            for id in entitiesToRemove {
                if let entity = cellEntities[id] {
                    entity.removeFromParent()
                }
                cellEntities.removeValue(forKey: id)
            }

            // Add or update cells
            let config = heatmapManager.configuration
            for cell in heatmapManager.heatmapCells {
                if let entity = cellEntities[cell.id] {
                    // Update existing entity
                    updateCellEntity(entity, for: cell, config: config)
                } else {
                    // Create new entity
                    let entity = createCellEntity(for: cell, config: config)
                    anchor.addChild(entity)
                    cellEntities[cell.id] = entity
                }
            }

            // Update grid visibility
            for entity in cellEntities.values {
                entity.isEnabled = showGrid
            }
        }

        private func createCellEntity(for cell: HeatmapCell, config: HeatmapConfiguration) -> ModelEntity {
            let size = config.gridSize * 0.8 // Slightly smaller for visual separation

            // Create mesh
            let mesh = MeshResource.generateBox(
                width: size,
                height: config.gridSize * 0.1,
                depth: size,
                cornerRadius: 0,
                splitFaces: false
            )

            // Create material with color based on signal strength
            let strength = cell.averageNormalizedStrength
            let color = signalStrengthToColor(strength)

            var material = UnlitMaterial()
            material.color = .init(tint: color.withAlphaComponent(CGFloat(config.opacity)))

            // Create entity
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = cell.position
            entity.position.y = config.visualizationHeight

            return entity
        }

        private func updateCellEntity(_ entity: ModelEntity, for cell: HeatmapCell, config: HeatmapConfiguration) {
            // Update color based on signal strength
            let strength = cell.averageNormalizedStrength
            let color = signalStrengthToColor(strength)

            var material = UnlitMaterial()
            material.color = .init(tint: color.withAlphaComponent(CGFloat(config.opacity)))

            entity.model?.materials = [material]
        }

        @MainActor
        private func updateDeadZones() {
            guard let anchor = heatmapAnchor else { return }

            // Remove outdated dead zones
            let currentZoneIDs = Set(heatmapManager.deadZones.map { $0.id })
            let zonesToRemove = deadZoneEntities.keys.filter { !currentZoneIDs.contains($0) }
            for id in zonesToRemove {
                if let entity = deadZoneEntities[id] {
                    entity.removeFromParent()
                }
                deadZoneEntities.removeValue(forKey: id)
            }

            // Add or update dead zones
            let config = heatmapManager.configuration
            for zone in heatmapManager.deadZones {
                if deadZoneEntities[zone.id] == nil {
                    let entity = createDeadZoneEntity(for: zone, config: config)
                    anchor.addChild(entity)
                    deadZoneEntities[zone.id] = entity
                }
            }
        }

        private func createDeadZoneEntity(for zone: DeadZone, config: HeatmapConfiguration) -> ModelEntity {
            // Create sphere mesh
            let mesh = MeshResource.generateSphere(radius: zone.radius)

            // Red transparent material for dead zones
            var material = UnlitMaterial()
            material.color = .init(tint: UIColor.red.withAlphaComponent(0.3))

            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = zone.center
            entity.position.y = config.visualizationHeight

            return entity
        }

        @MainActor
        private func clearDeadZones() {
            for entity in deadZoneEntities.values {
                entity.removeFromParent()
            }
            deadZoneEntities.removeAll()
        }

        private func signalStrengthToColor(_ normalizedStrength: Float) -> UIColor {
            // Gradient: Red (0.0) -> Yellow (0.5) -> Green (1.0)
            if normalizedStrength < 0.5 {
                // Red to Yellow
                let factor = normalizedStrength * 2
                return UIColor(
                    red: 1.0,
                    green: CGFloat(factor),
                    blue: 0.0,
                    alpha: 1.0
                )
            } else {
                // Yellow to Green
                let factor = (normalizedStrength - 0.5) * 2
                return UIColor(
                    red: CGFloat(1.0 - factor),
                    green: 1.0,
                    blue: 0.0,
                    alpha: 1.0
                )
            }
        }
    }
}

// MARK: - Signal Strength Legend

struct SignalStrengthLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal Strength")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)

            HStack(spacing: 4) {
                ForEach(0..<10) { index in
                    let strength = Float(index) / 9.0
                    Rectangle()
                        .fill(strengthToColor(strength))
                        .frame(width: 20, height: 30)
                }
            }

            HStack {
                Text("Weak")
                    .font(.caption2)
                    .foregroundColor(.white)
                Spacer()
                Text("Strong")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }

    private func strengthToColor(_ normalizedStrength: Float) -> Color {
        if normalizedStrength < 0.5 {
            let factor = normalizedStrength * 2
            return Color(
                red: 1.0,
                green: Double(factor),
                blue: 0.0
            )
        } else {
            let factor = (normalizedStrength - 0.5) * 2
            return Color(
                red: Double(1.0 - factor),
                green: 1.0,
                blue: 0.0
            )
        }
    }
}
