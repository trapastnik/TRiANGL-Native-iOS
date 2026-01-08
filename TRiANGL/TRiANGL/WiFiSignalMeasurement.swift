import Foundation
import simd

// MARK: - WiFi Signal Measurement

/// Represents a single Wi-Fi signal strength measurement at a specific location
struct WiFiSignalMeasurement: Identifiable, Codable {
    let id: UUID
    let position: SIMD3<Float>
    let signalStrength: Int // RSSI in dBm
    let ssid: String?
    let bssid: String?
    let timestamp: Date
    let frequency: Double? // GHz (2.4 or 5.0)

    init(position: SIMD3<Float>,
         signalStrength: Int,
         ssid: String? = nil,
         bssid: String? = nil,
         frequency: Double? = nil) {
        self.id = UUID()
        self.position = position
        self.signalStrength = signalStrength
        self.ssid = ssid
        self.bssid = bssid
        self.frequency = frequency
        self.timestamp = Date()
    }

    /// Signal quality from 0.0 (worst) to 1.0 (best)
    var normalizedStrength: Float {
        // RSSI typically ranges from -100 dBm (worst) to -30 dBm (best)
        let minRSSI: Float = -100
        let maxRSSI: Float = -30
        let normalized = (Float(signalStrength) - minRSSI) / (maxRSSI - minRSSI)
        return max(0, min(1, normalized))
    }

    /// Signal quality category
    var qualityLevel: SignalQuality {
        switch signalStrength {
        case -30...0:
            return .excellent
        case -50..<(-30):
            return .good
        case -70..<(-50):
            return .fair
        case -80..<(-70):
            return .weak
        default:
            return .poor
        }
    }

    /// Color representation for visualization
    var color: (red: Float, green: Float, blue: Float, alpha: Float) {
        let strength = normalizedStrength

        // Gradient: Red (weak) -> Yellow -> Green (strong)
        if strength < 0.5 {
            // Red to Yellow
            let factor = strength * 2
            return (
                red: 1.0,
                green: factor,
                blue: 0.0,
                alpha: 0.7
            )
        } else {
            // Yellow to Green
            let factor = (strength - 0.5) * 2
            return (
                red: 1.0 - factor,
                green: 1.0,
                blue: 0.0,
                alpha: 0.7
            )
        }
    }
}

// MARK: - Signal Quality

enum SignalQuality: String, Codable {
    case excellent = "Отличный"
    case good = "Хороший"
    case fair = "Средний"
    case weak = "Слабый"
    case poor = "Очень слабый"

    var icon: String {
        switch self {
        case .excellent:
            return "wifi"
        case .good:
            return "wifi"
        case .fair:
            return "wifi.exclamationmark"
        case .weak:
            return "wifi.slash"
        case .poor:
            return "wifi.slash"
        }
    }

    var color: (red: Float, green: Float, blue: Float) {
        switch self {
        case .excellent:
            return (0.0, 1.0, 0.0) // Green
        case .good:
            return (0.5, 1.0, 0.0) // Light Green
        case .fair:
            return (1.0, 1.0, 0.0) // Yellow
        case .weak:
            return (1.0, 0.5, 0.0) // Orange
        case .poor:
            return (1.0, 0.0, 0.0) // Red
        }
    }
}

// MARK: - Heatmap Grid

/// Represents a grid cell in the heatmap
struct HeatmapCell: Identifiable {
    let id = UUID()
    let position: SIMD3<Float>
    var measurements: [WiFiSignalMeasurement]

    /// Average signal strength in this cell
    var averageSignalStrength: Int {
        guard !measurements.isEmpty else { return -100 }
        let sum = measurements.reduce(0) { $0 + $1.signalStrength }
        return sum / measurements.count
    }

    /// Average normalized strength
    var averageNormalizedStrength: Float {
        guard !measurements.isEmpty else { return 0 }
        let sum = measurements.reduce(Float(0)) { $0 + $1.normalizedStrength }
        return sum / Float(measurements.count)
    }

    /// Most recent measurement
    var latestMeasurement: WiFiSignalMeasurement? {
        measurements.max(by: { $0.timestamp < $1.timestamp })
    }
}

// MARK: - Heatmap Configuration

struct HeatmapConfiguration {
    var gridSize: Float = 0.3 // Cell size in meters
    var maxDistance: Float = 10.0 // Maximum distance from origin
    var interpolationEnabled: Bool = true
    var smoothingFactor: Float = 0.5
    var visualizationHeight: Float = 1.5 // Height at which to display heatmap
    var showGrid: Bool = true
    var particleCount: Int = 1000
    var updateInterval: TimeInterval = 1.0 // Seconds between measurements

    /// Minimum signal strength to display
    var minimumDisplayStrength: Int = -100

    /// Opacity for heatmap visualization
    var opacity: Float = 0.7
}

// MARK: - Dead Zone

/// Represents an area with poor Wi-Fi coverage
struct DeadZone: Identifiable {
    let id = UUID()
    let center: SIMD3<Float>
    let radius: Float
    let averageSignalStrength: Int
    let measurements: [WiFiSignalMeasurement]

    var description: String {
        return "Dead zone: \(averageSignalStrength) dBm"
    }
}

// MARK: - Heatmap Statistics

struct HeatmapStatistics {
    let totalMeasurements: Int
    let averageSignalStrength: Int
    let minSignalStrength: Int
    let maxSignalStrength: Int
    let coverageArea: Float // in square meters
    let deadZones: [DeadZone]
    let measurementStartTime: Date
    let measurementDuration: TimeInterval

    var signalQualityDistribution: [SignalQuality: Int] {
        // Return empty distribution for now
        // This would be calculated from actual measurements
        return [:]
    }
}
