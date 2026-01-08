import Foundation
import Network
import SystemConfiguration.CaptiveNetwork
import NetworkExtension

// MARK: - WiFi Scanner

@MainActor
class WiFiScanner: ObservableObject {
    // MARK: - Published Properties

    @Published var discoveredDevices: [WiFiDevice] = []
    @Published var isScanning = false
    @Published var statusMessage = "Ready to scan"
    @Published var lastError: WiFiScannerError?
    @Published var networkInfo: NetworkInfo?
    @Published var deviceCount: Int = 0

    // MARK: - Private Properties

    private var browsers: [NWBrowser] = []
    private let servicesToScan = [
        "_http._tcp",
        "_https._tcp",
        "_printer._tcp",
        "_airplay._tcp",
        "_homekit._tcp",
        "_ssh._tcp",
        "_smb._tcp",
        "_afpovertcp._tcp",
        "_raop._tcp"
    ]

    private var discoveredEndpoints: Set<String> = []

    // MARK: - Public Methods

    func startScanning() {
        guard !isScanning else { return }

        isScanning = true
        statusMessage = "Scanning for devices..."
        lastError = nil
        discoveredDevices.removeAll()
        discoveredEndpoints.removeAll()
        deviceCount = 0

        // Get current network info
        fetchNetworkInfo()

        // Start browsing for each service type
        for serviceType in servicesToScan {
            startBrowsing(for: serviceType)
        }

        // Auto-stop after 30 seconds
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if isScanning {
                stopScanning()
            }
        }
    }

    func stopScanning() {
        isScanning = false

        // Cancel all browsers
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()

        if discoveredDevices.isEmpty {
            statusMessage = "No devices found"
        } else {
            statusMessage = "Found \(discoveredDevices.count) device(s)"
        }
    }

    func clearDevices() {
        discoveredDevices.removeAll()
        discoveredEndpoints.removeAll()
        deviceCount = 0
        statusMessage = "Ready to scan"
    }

    // MARK: - Private Methods

    private func startBrowsing(for serviceType: String) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                self?.handleBrowserState(newState, serviceType: serviceType)
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleBrowseResults(results, serviceType: serviceType)
            }
        }

        browser.start(queue: .global(qos: .userInitiated))
        browsers.append(browser)
    }

    private func handleBrowserState(_ state: NWBrowser.State, serviceType: String) {
        switch state {
        case .ready:
            print("Browser ready for \(serviceType)")
        case .failed(let error):
            print("Browser failed for \(serviceType): \(error)")
            if browsers.allSatisfy({ $0.state == .failed }) {
                lastError = .scanFailed(error.localizedDescription)
                statusMessage = "Scan failed"
            }
        case .cancelled:
            print("Browser cancelled for \(serviceType)")
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, serviceType: String) {
        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, _):
                resolveEndpoint(result.endpoint, name: name, serviceType: type, domain: domain)
            default:
                break
            }
        }

        deviceCount = discoveredDevices.count
        if deviceCount > 0 {
            statusMessage = "Found \(deviceCount) device(s)..."
        }
    }

    private func resolveEndpoint(_ endpoint: Network.NWEndpoint, name: String, serviceType: String, domain: String) {
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                if case .ready = state {
                    self?.extractDeviceInfo(from: connection, name: name, serviceType: serviceType)
                }
                connection.cancel()
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    private func extractDeviceInfo(from connection: NWConnection, name: String, serviceType: String) {
        guard case .hostPort(let host, let port) = connection.endpoint else {
            return
        }

        let ipAddress: String
        switch host {
        case .ipv4(let address):
            ipAddress = address.debugDescription
        case .ipv6(let address):
            ipAddress = address.debugDescription
        case .name(let hostname, _):
            ipAddress = hostname
        @unknown default:
            ipAddress = "Unknown"
        }

        let endpointKey = "\(ipAddress):\(port):\(serviceType)"
        guard !discoveredEndpoints.contains(endpointKey) else {
            return
        }

        discoveredEndpoints.insert(endpointKey)

        let device = WiFiDevice(
            name: name,
            ipAddress: ipAddress,
            port: port.rawValue,
            serviceType: serviceType,
            discoveredAt: Date()
        )

        if !discoveredDevices.contains(device) {
            discoveredDevices.append(device)
            discoveredDevices.sort { $0.discoveredAt > $1.discoveredAt }
        }
    }

    private func fetchNetworkInfo() {
        // Try to get current WiFi network information
        // Note: This requires Location permissions and WiFi entitlement
        #if targetEnvironment(simulator)
        networkInfo = NetworkInfo(ssid: "Simulator Network", bssid: nil, ipAddress: getIPAddress())
        #else
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            Task { @MainActor [weak self] in
                if let network = network {
                    self?.networkInfo = NetworkInfo(
                        ssid: network.ssid,
                        bssid: network.bssid,
                        ipAddress: self?.getIPAddress()
                    )
                } else {
                    self?.networkInfo = NetworkInfo(
                        ssid: nil,
                        bssid: nil,
                        ipAddress: self?.getIPAddress()
                    )
                }
            }
        }
        #endif
    }

    private func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr,
                                  socklen_t(interface.ifa_addr.pointee.sa_len),
                                  &hostname,
                                  socklen_t(hostname.count),
                                  nil,
                                  socklen_t(0),
                                  NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }
}
