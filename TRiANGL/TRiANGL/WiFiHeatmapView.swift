import SwiftUI

// MARK: - WiFi Heatmap View

struct WiFiHeatmapView: View {
    @StateObject private var heatmapManager = WiFiHeatmapManager()
    @Environment(\.dismiss) private var dismiss

    @State private var showGrid = true
    @State private var showDeadZones = true
    @State private var showLegend = true
    @State private var showSettings = false
    @State private var showStatistics = false

    var body: some View {
        ZStack {
            // AR View
            WiFiHeatmapARContainer(
                heatmapManager: heatmapManager,
                showGrid: showGrid,
                showDeadZones: showDeadZones
            )
            .edgesIgnoringSafeArea(.all)

            // UI Overlay
            VStack {
                // Top Bar
                topBar

                Spacer()

                // Legend
                if showLegend {
                    HStack {
                        Spacer()
                        SignalStrengthLegend()
                            .padding()
                    }
                }

                // Status and Controls
                VStack(spacing: 12) {
                    statusBar
                    controlPanel
                }
                .padding(.bottom, 20)
            }

            // Settings Panel
            if showSettings {
                settingsPanel
            }

            // Statistics Panel
            if showStatistics {
                statisticsPanel
            }
        }
        .onAppear {
            // AR session will be created by ARContainer
            // Check if we need to initialize anything
            if heatmapManager.arSession == nil {
                // Session will be set up by WiFiHeatmapARContainer
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }

            Spacer()

            Text("WiFi Heatmap")
                .font(.headline)
                .foregroundColor(.white)
                .shadow(radius: 2)

            Spacer()

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        VStack(spacing: 8) {
            // Status message
            HStack {
                if heatmapManager.isRecording {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                Text(heatmapManager.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(heatmapManager.measurements.count) points")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }

            // Current signal strength
            if let position = heatmapManager.currentCameraPosition {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundColor(signalColor(heatmapManager.signalMonitor.currentSignalStrength))

                    Text(WiFiSignalMonitor.formatRSSI(heatmapManager.signalMonitor.currentSignalStrength))
                        .font(.caption)
                        .foregroundColor(.white)

                    Text("•")
                        .foregroundColor(.white.opacity(0.5))

                    if let ssid = heatmapManager.signalMonitor.currentSSID {
                        Text(ssid)
                            .font(.caption)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: { showStatistics.toggle() }) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        HStack(spacing: 12) {
            // Grid toggle
            Button(action: { showGrid.toggle() }) {
                VStack {
                    Image(systemName: showGrid ? "square.grid.3x3.fill" : "square.grid.3x3")
                        .font(.title3)
                    Text("Grid")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
            }

            // Dead zones toggle
            Button(action: { showDeadZones.toggle() }) {
                VStack {
                    Image(systemName: showDeadZones ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .font(.title3)
                    Text("Dead Zones")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
            }

            // Legend toggle
            Button(action: { showLegend.toggle() }) {
                VStack {
                    Image(systemName: showLegend ? "chart.bar.fill" : "chart.bar")
                        .font(.title3)
                    Text("Legend")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.4))
                .cornerRadius(10)
            }

            // Record/Stop button
            Button(action: {
                if heatmapManager.isRecording {
                    heatmapManager.stopRecording()
                } else {
                    if let session = heatmapManager.arSession {
                        heatmapManager.startRecording(with: session)
                    }
                }
            }) {
                VStack {
                    Image(systemName: heatmapManager.isRecording ? "stop.fill" : "record.circle")
                        .font(.title3)
                    Text(heatmapManager.isRecording ? "Stop" : "Record")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(heatmapManager.isRecording ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showSettings = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }

            Divider()
                .background(Color.white)

            // Grid size
            VStack(alignment: .leading) {
                Text("Grid Size: \(String(format: "%.2f", heatmapManager.configuration.gridSize))m")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Slider(value: $heatmapManager.configuration.gridSize, in: 0.1...1.0)
                    .accentColor(.blue)
            }

            // Opacity
            VStack(alignment: .leading) {
                Text("Opacity: \(String(format: "%.0f", heatmapManager.configuration.opacity * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Slider(value: $heatmapManager.configuration.opacity, in: 0.1...1.0)
                    .accentColor(.blue)
            }

            // Smoothing
            VStack(alignment: .leading) {
                Text("Smoothing: \(String(format: "%.0f", heatmapManager.configuration.smoothingFactor * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Slider(value: $heatmapManager.configuration.smoothingFactor, in: 0.0...1.0)
                    .accentColor(.blue)
            }

            // Interpolation toggle
            Toggle(isOn: $heatmapManager.configuration.interpolationEnabled) {
                Text("Interpolation")
                    .foregroundColor(.white)
            }
            .tint(.blue)

            // Clear data button
            Button(action: {
                heatmapManager.clearData()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.8))
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
        .frame(width: 300)
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
    }

    // MARK: - Statistics Panel

    private var statisticsPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showStatistics = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }

            Divider()
                .background(Color.white)

            if let stats = heatmapManager.statistics {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(title: "Total Measurements", value: "\(stats.totalMeasurements)")
                        StatRow(title: "Average Signal", value: "\(stats.averageSignalStrength) dBm")
                        StatRow(title: "Min Signal", value: "\(stats.minSignalStrength) dBm")
                        StatRow(title: "Max Signal", value: "\(stats.maxSignalStrength) dBm")
                        StatRow(title: "Coverage Area", value: String(format: "%.1f m²", stats.coverageArea))
                        StatRow(title: "Dead Zones", value: "\(stats.deadZones.count)")
                        StatRow(title: "Duration", value: String(format: "%.1f sec", stats.measurementDuration))
                    }
                }
            } else {
                Text("No statistics available")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            }

            Spacer()
        }
        .padding()
        .frame(width: 300, height: 400)
        .background(Color.black.opacity(0.8))
        .cornerRadius(15)
    }

    // MARK: - Helper Methods

    private func signalColor(_ rssi: Int) -> Color {
        let quality = WiFiSignalMonitor.getQualityLevel(rssi)
        let rgb = quality.color
        return Color(red: Double(rgb.red), green: Double(rgb.green), blue: Double(rgb.blue))
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    WiFiHeatmapView()
}
