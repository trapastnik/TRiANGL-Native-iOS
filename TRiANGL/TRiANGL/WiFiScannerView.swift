import SwiftUI

struct WiFiScannerView: View {
    @StateObject private var scanner = WiFiScanner()
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeviceDetails: WiFiDevice?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                // Network info section
                if let networkInfo = scanner.networkInfo {
                    networkInfoSection(networkInfo)
                }

                // Status message
                statusSection

                // Device list
                deviceList

                // Bottom controls
                bottomControls
            }
        }
        .onAppear {
            scanner.startScanning()
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .sheet(item: $showingDeviceDetails) { device in
            DeviceDetailView(device: device)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }

            Spacer()

            Text("WiFi Scanner")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                if scanner.isScanning {
                    scanner.stopScanning()
                } else {
                    scanner.clearDevices()
                    scanner.startScanning()
                }
            }) {
                Image(systemName: scanner.isScanning ? "stop.circle.fill" : "arrow.clockwise.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Network Info Section

    private func networkInfoSection(_ info: NetworkInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ssid = info.ssid {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundColor(.green)
                    Text("Network: \(ssid)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }

            if let ipAddress = info.ipAddress {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                    Text("IP: \(ipAddress)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack {
            if scanner.isScanning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }

            Text(scanner.statusMessage)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Text("\(scanner.deviceCount) devices")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Device List

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if scanner.discoveredDevices.isEmpty && !scanner.isScanning {
                    emptyStateView
                } else {
                    ForEach(scanner.discoveredDevices) { device in
                        DeviceRow(device: device)
                            .onTapGesture {
                                showingDeviceDetails = device
                            }
                    }
                }
            }
            .padding()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))

            Text("No devices found")
                .font(.headline)
                .foregroundColor(.white)

            Text("Tap the refresh button to scan again")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            if let error = scanner.lastError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button(action: {
                    scanner.clearDevices()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(scanner.discoveredDevices.isEmpty)

                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Done")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: WiFiDevice

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconForDevice(device))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(device.serviceDescription)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                Text("\(device.ipAddress):\(device.port)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    private func iconForDevice(_ device: WiFiDevice) -> String {
        switch device.serviceType {
        case "_http._tcp", "_https._tcp":
            return "globe"
        case "_printer._tcp":
            return "printer"
        case "_airplay._tcp":
            return "airplayvideo"
        case "_homekit._tcp":
            return "house"
        case "_ssh._tcp":
            return "terminal"
        case "_smb._tcp", "_afpovertcp._tcp":
            return "externaldrive"
        default:
            return "network"
        }
    }
}

// MARK: - Device Detail View

struct DeviceDetailView: View {
    let device: WiFiDevice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Device Information") {
                    DetailRow(title: "Name", value: device.displayName)
                    DetailRow(title: "IP Address", value: device.ipAddress)
                    DetailRow(title: "Port", value: String(device.port))
                    DetailRow(title: "Service Type", value: device.serviceDescription)
                    DetailRow(title: "Discovered", value: formatDate(device.discoveredAt))
                }

                Section("Actions") {
                    Button(action: {
                        copyToClipboard("\(device.ipAddress):\(device.port)")
                    }) {
                        Label("Copy Address", systemImage: "doc.on.doc")
                    }

                    if device.serviceType == "_http._tcp" || device.serviceType == "_https._tcp" {
                        Link(destination: URL(string: "http://\(device.ipAddress):\(device.port)")!) {
                            Label("Open in Browser", systemImage: "safari")
                        }
                    }
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

// MARK: - Preview

#Preview {
    WiFiScannerView()
}
