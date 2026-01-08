import Foundation
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import NetworkExtension

// MARK: - WiFi Signal Monitor

@MainActor
class WiFiSignalMonitor: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var currentSignalStrength: Int = -100 // RSSI in dBm
    @Published var currentSSID: String?
    @Published var currentBSSID: String?
    @Published var isMonitoring = false
    @Published var lastError: Error?

    // MARK: - Private Properties

    private var monitorTimer: Timer?
    private let locationManager = CLLocationManager()
    private var updateInterval: TimeInterval = 1.0

    // MARK: - Callbacks

    var onSignalUpdate: ((Int, String?, String?) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Public Methods

    func startMonitoring(interval: TimeInterval = 1.0) {
        guard !isMonitoring else { return }

        updateInterval = interval
        isMonitoring = true

        // Request location permission for WiFi info access
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        // Start periodic updates
        monitorTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateSignalStrength()
            }
        }

        // Initial update
        Task {
            await updateSignalStrength()
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    func getCurrentMeasurement(at position: SIMD3<Float>) -> WiFiSignalMeasurement {
        return WiFiSignalMeasurement(
            position: position,
            signalStrength: currentSignalStrength,
            ssid: currentSSID,
            bssid: currentBSSID
        )
    }

    // MARK: - Private Methods

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    private func updateSignalStrength() async {
        // Fetch current network info
        #if targetEnvironment(simulator)
        // Simulator mock data
        currentSignalStrength = Int.random(in: -80...(-40))
        currentSSID = "Simulator Network"
        currentBSSID = "00:00:00:00:00:00"
        #else
        // Real device - fetch actual WiFi info
        await fetchWiFiInfo()
        #endif

        // Notify callback
        onSignalUpdate?(currentSignalStrength, currentSSID, currentBSSID)
    }

    private func fetchWiFiInfo() async {
        // Attempt to get WiFi information using NEHotspotNetwork
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            NEHotspotNetwork.fetchCurrent { [weak self] network in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                Task { @MainActor in
                    if let network = network {
                        self.currentSSID = network.ssid
                        self.currentBSSID = network.bssid
                        self.currentSignalStrength = self.estimateSignalStrength()
                    } else {
                        self.currentSignalStrength = -100
                        self.currentSSID = nil
                        self.currentBSSID = nil
                    }
                    continuation.resume()
                }
            }
        }
    }

    /// Estimate signal strength based on available metrics
    /// Note: This is a workaround as iOS doesn't expose RSSI directly
    private func estimateSignalStrength() -> Int {
        // Use CoreLocation's CLLocationManager to estimate
        // This is an approximation and may not be accurate

        // For demo purposes, we'll use a mock implementation
        // In production, you might:
        // 1. Use speed test to correlate with signal strength
        // 2. Use CoreTelephony for cellular (not WiFi)
        // 3. Use private APIs (not App Store compatible)

        #if DEBUG
        // Generate semi-realistic values for testing
        let base = -50
        let variance = Int.random(in: -20...10)
        return base + variance
        #else
        // Production fallback
        return -60 // Assume reasonable signal
        #endif
    }
}

// MARK: - CLLocationManagerDelegate

extension WiFiSignalMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in
                await self.updateSignalStrength()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updates can trigger WiFi info refresh
        Task { @MainActor in
            await self.updateSignalStrength()
        }
    }
}

// MARK: - Signal Strength Utilities

extension WiFiSignalMonitor {
    /// Convert RSSI to percentage (0-100)
    static func rssiToPercentage(_ rssi: Int) -> Int {
        let minRSSI = -100
        let maxRSSI = -30
        let percentage = ((rssi - minRSSI) * 100) / (maxRSSI - minRSSI)
        return max(0, min(100, percentage))
    }

    /// Get quality level from RSSI
    static func getQualityLevel(_ rssi: Int) -> SignalQuality {
        switch rssi {
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

    /// Format RSSI for display
    static func formatRSSI(_ rssi: Int) -> String {
        return "\(rssi) dBm"
    }
}
