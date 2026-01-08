import Foundation
import ARKit
import Combine
import simd

// MARK: - WiFi Heatmap Manager

@MainActor
class WiFiHeatmapManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var measurements: [WiFiSignalMeasurement] = []
    @Published var heatmapCells: [HeatmapCell] = []
    @Published var isRecording = false
    @Published var statusMessage = "Ready to map"
    @Published var configuration = HeatmapConfiguration()
    @Published var statistics: HeatmapStatistics?
    @Published var deadZones: [DeadZone] = []

    // MARK: - AR Properties

    @Published var arSession: ARSession?
    @Published var currentCameraPosition: SIMD3<Float>?

    // MARK: - Private Properties

    let signalMonitor = WiFiSignalMonitor()
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()

    private var gridCells: [SIMD3<Int>: HeatmapCell] = [:]

    // MARK: - Initialization

    override init() {
        super.init()
        setupSignalMonitor()
    }

    // MARK: - Public Methods

    func startRecording(with session: ARSession) {
        guard !isRecording else { return }

        isRecording = true
        recordingStartTime = Date()
        arSession = session
        measurements.removeAll()
        heatmapCells.removeAll()
        gridCells.removeAll()
        deadZones.removeAll()
        statusMessage = "Recording WiFi signal..."

        // Start monitoring WiFi signal
        signalMonitor.startMonitoring(interval: configuration.updateInterval)
    }

    func stopRecording() {
        isRecording = false
        signalMonitor.stopMonitoring()

        // Generate heatmap
        generateHeatmap()

        // Calculate statistics
        calculateStatistics()

        // Detect dead zones
        detectDeadZones()

        let count = measurements.count
        statusMessage = "Recorded \(count) measurement\(count == 1 ? "" : "s")"
    }

    func recordMeasurement(at position: SIMD3<Float>) {
        let measurement = signalMonitor.getCurrentMeasurement(at: position)
        measurements.append(measurement)

        // Add to grid
        let gridPos = worldToGrid(position)
        if var cell = gridCells[gridPos] {
            cell.measurements.append(measurement)
            gridCells[gridPos] = cell
        } else {
            let newCell = HeatmapCell(
                position: gridToWorld(gridPos),
                measurements: [measurement]
            )
            gridCells[gridPos] = newCell
        }

        // Update heatmap cells array
        heatmapCells = Array(gridCells.values)
    }

    func updateCameraPosition(_ position: SIMD3<Float>) {
        currentCameraPosition = position

        if isRecording {
            // Auto-record at current position
            recordMeasurement(at: position)
        }
    }

    func clearData() {
        measurements.removeAll()
        heatmapCells.removeAll()
        gridCells.removeAll()
        deadZones.removeAll()
        statistics = nil
        statusMessage = "Ready to map"
    }

    func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(measurements)
    }

    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        measurements = try decoder.decode([WiFiSignalMeasurement].self, from: data)
        generateHeatmap()
        calculateStatistics()
        detectDeadZones()
    }

    // MARK: - Private Methods

    private func setupSignalMonitor() {
        signalMonitor.onSignalUpdate = { [weak self] strength, ssid, bssid in
            Task { @MainActor [weak self] in
                guard let self = self, self.isRecording else { return }

                if let position = self.currentCameraPosition {
                    self.recordMeasurement(at: position)
                }
            }
        }
    }

    private func generateHeatmap() {
        // Heatmap cells are already generated during recording
        // Here we can apply smoothing or interpolation if needed

        if configuration.interpolationEnabled {
            interpolateMissingCells()
        }

        if configuration.smoothingFactor > 0 {
            smoothHeatmap()
        }
    }

    private func interpolateMissingCells() {
        // Fill in gaps using nearby measurements
        let maxGridDistance = 2

        var newCells: [SIMD3<Int>: HeatmapCell] = gridCells

        for (pos, cell) in gridCells {
            // Check neighboring cells
            for dx in -maxGridDistance...maxGridDistance {
                for dy in -maxGridDistance...maxGridDistance {
                    for dz in -maxGridDistance...maxGridDistance {
                        let neighborPos = SIMD3<Int>(pos.x + dx, pos.y + dy, pos.z + dz)

                        // Skip if cell already exists
                        if gridCells[neighborPos] != nil {
                            continue
                        }

                        // Calculate interpolated value
                        let worldPos = gridToWorld(neighborPos)
                        if let interpolated = interpolateSignalAt(worldPos) {
                            let newCell = HeatmapCell(
                                position: worldPos,
                                measurements: [interpolated]
                            )
                            newCells[neighborPos] = newCell
                        }
                    }
                }
            }
        }

        gridCells = newCells
        heatmapCells = Array(gridCells.values)
    }

    private func interpolateSignalAt(_ position: SIMD3<Float>) -> WiFiSignalMeasurement? {
        // Find nearby measurements and interpolate
        let nearbyMeasurements = measurements.filter { measurement in
            let distance = simd_distance(measurement.position, position)
            return distance < configuration.gridSize * 3
        }

        guard !nearbyMeasurements.isEmpty else { return nil }

        // Weighted average based on distance
        var totalWeight: Float = 0
        var weightedSum: Float = 0

        for measurement in nearbyMeasurements {
            let distance = simd_distance(measurement.position, position)
            let weight = 1.0 / max(distance, 0.01)
            totalWeight += weight
            weightedSum += weight * Float(measurement.signalStrength)
        }

        let interpolatedStrength = Int(weightedSum / totalWeight)

        return WiFiSignalMeasurement(
            position: position,
            signalStrength: interpolatedStrength,
            ssid: nearbyMeasurements.first?.ssid,
            bssid: nearbyMeasurements.first?.bssid
        )
    }

    private func smoothHeatmap() {
        // Apply Gaussian smoothing to reduce noise
        var smoothedCells: [SIMD3<Int>: HeatmapCell] = [:]

        for (pos, cell) in gridCells {
            var neighborStrengths: [Int] = []

            // Collect neighbor values
            for dx in -1...1 {
                for dy in -1...1 {
                    for dz in -1...1 {
                        let neighborPos = SIMD3<Int>(pos.x + dx, pos.y + dy, pos.z + dz)
                        if let neighbor = gridCells[neighborPos] {
                            neighborStrengths.append(neighbor.averageSignalStrength)
                        }
                    }
                }
            }

            if !neighborStrengths.isEmpty {
                let average = neighborStrengths.reduce(0, +) / neighborStrengths.count
                let smoothedStrength = Int(Float(cell.averageSignalStrength) * (1 - configuration.smoothingFactor) +
                                          Float(average) * configuration.smoothingFactor)

                let smoothedMeasurement = WiFiSignalMeasurement(
                    position: cell.position,
                    signalStrength: smoothedStrength,
                    ssid: cell.latestMeasurement?.ssid,
                    bssid: cell.latestMeasurement?.bssid
                )

                smoothedCells[pos] = HeatmapCell(
                    position: cell.position,
                    measurements: [smoothedMeasurement]
                )
            } else {
                smoothedCells[pos] = cell
            }
        }

        gridCells = smoothedCells
        heatmapCells = Array(gridCells.values)
    }

    private func calculateStatistics() {
        guard !measurements.isEmpty else {
            statistics = nil
            return
        }

        let strengths = measurements.map { $0.signalStrength }
        let minStrength = strengths.min() ?? -100
        let maxStrength = strengths.max() ?? -30
        let avgStrength = strengths.reduce(0, +) / strengths.count

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Estimate coverage area (rough approximation)
        let uniqueGridCells = Set(measurements.map { worldToGrid($0.position) })
        let coverageArea = Float(uniqueGridCells.count) * (configuration.gridSize * configuration.gridSize)

        statistics = HeatmapStatistics(
            totalMeasurements: measurements.count,
            averageSignalStrength: avgStrength,
            minSignalStrength: minStrength,
            maxSignalStrength: maxStrength,
            coverageArea: coverageArea,
            deadZones: deadZones,
            measurementStartTime: recordingStartTime ?? Date(),
            measurementDuration: duration
        )
    }

    private func detectDeadZones() {
        deadZones.removeAll()

        // Group cells by signal quality
        let weakCells = heatmapCells.filter { $0.averageSignalStrength < -75 }

        // Cluster weak cells into dead zones
        var processed = Set<UUID>()

        for cell in weakCells {
            guard !processed.contains(cell.id) else { continue }

            var cluster: [HeatmapCell] = [cell]
            processed.insert(cell.id)

            // Find connected weak cells
            for otherCell in weakCells {
                guard !processed.contains(otherCell.id) else { continue }

                let distance = simd_distance(cell.position, otherCell.position)
                if distance < configuration.gridSize * 2 {
                    cluster.append(otherCell)
                    processed.insert(otherCell.id)
                }
            }

            // Create dead zone from cluster
            if cluster.count >= 3 {
                let centerPos = cluster.reduce(SIMD3<Float>.zero) { $0 + $1.position } / Float(cluster.count)
                let avgStrength = cluster.reduce(0) { $0 + $1.averageSignalStrength } / cluster.count
                let allMeasurements = cluster.flatMap { $0.measurements }

                let deadZone = DeadZone(
                    center: centerPos,
                    radius: configuration.gridSize * Float(cluster.count).squareRoot(),
                    averageSignalStrength: avgStrength,
                    measurements: allMeasurements
                )
                deadZones.append(deadZone)
            }
        }
    }

    // MARK: - Grid Conversion

    private func worldToGrid(_ position: SIMD3<Float>) -> SIMD3<Int> {
        let gridSize = configuration.gridSize
        return SIMD3<Int>(
            Int(round(position.x / gridSize)),
            Int(round(position.y / gridSize)),
            Int(round(position.z / gridSize))
        )
    }

    private func gridToWorld(_ gridPos: SIMD3<Int>) -> SIMD3<Float> {
        let gridSize = configuration.gridSize
        return SIMD3<Float>(
            Float(gridPos.x) * gridSize,
            Float(gridPos.y) * gridSize,
            Float(gridPos.z) * gridSize
        )
    }
}
