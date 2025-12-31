import Foundation
import Network

// MARK: - WiFi Device Model

/// Represents a discovered device on the local network
struct WiFiDevice: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let ipAddress: String
    let port: UInt16
    let serviceType: String
    let discoveredAt: Date

    var displayName: String {
        if name.isEmpty {
            return ipAddress
        }
        return name
    }

    var serviceDescription: String {
        switch serviceType {
        case "_http._tcp":
            return "HTTP Server"
        case "_https._tcp":
            return "HTTPS Server"
        case "_printer._tcp":
            return "Printer"
        case "_airplay._tcp":
            return "AirPlay Device"
        case "_homekit._tcp":
            return "HomeKit Device"
        case "_ssh._tcp":
            return "SSH Server"
        default:
            return serviceType.replacingOccurrences(of: "_", with: "")
                               .replacingOccurrences(of: "._tcp", with: "")
                               .replacingOccurrences(of: "._udp", with: "")
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ipAddress)
        hasher.combine(port)
        hasher.combine(serviceType)
    }

    static func == (lhs: WiFiDevice, rhs: WiFiDevice) -> Bool {
        return lhs.ipAddress == rhs.ipAddress &&
               lhs.port == rhs.port &&
               lhs.serviceType == rhs.serviceType
    }
}

// MARK: - WiFi Scanner Error

enum WiFiScannerError: Error, LocalizedError {
    case permissionDenied
    case networkUnavailable
    case scanFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Network access permission denied. Please enable local network access in Settings."
        case .networkUnavailable:
            return "No network connection available."
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .timeout:
            return "Scan timeout. Please try again."
        }
    }
}

// MARK: - Network Info

/// Current network information
struct NetworkInfo {
    let ssid: String?
    let bssid: String?
    let ipAddress: String?

    var isConnected: Bool {
        return ssid != nil
    }
}
