import SwiftUI

struct DepthSettingsView: View {
    @ObservedObject var settings: DepthSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Depth Map Settings")
                .font(.headline)
                .padding(.bottom, 8)

            // Render Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Render Mode")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Render Mode", selection: $settings.renderMode) {
                    ForEach(DepthRenderMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Frame Skip
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Frame Skip")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(settings.frameSkip) (every \(settings.frameSkip + 1) frame)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("0")
                        .font(.caption2)
                    Slider(value: Binding(
                        get: { Double(settings.frameSkip) },
                        set: { settings.frameSkip = Int($0) }
                    ), in: 0...10, step: 1)
                    Text("10")
                        .font(.caption2)
                }
            }

            // Downsample Factor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Resolution")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("1/\(settings.downsampleFactor)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Full")
                        .font(.caption2)
                    Slider(value: Binding(
                        get: { Double(settings.downsampleFactor) },
                        set: { settings.downsampleFactor = Int($0) }
                    ), in: 1...8, step: 1)
                    Text("1/8")
                        .font(.caption2)
                }
            }

            Divider()

            // Depth Source
            Toggle("Use Smoothed Depth", isOn: $settings.useSmoothedDepth)
                .font(.subheadline)

            // Overlay Alpha
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overlay Transparency")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", settings.overlayAlpha))
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Slider(value: $settings.overlayAlpha, in: 0...1, step: 0.1)
            }

            Divider()

            // Depth Range
            VStack(alignment: .leading, spacing: 8) {
                Text("Depth Range (meters)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Min:")
                    Slider(value: $settings.minDepth, in: 0.1...5, step: 0.1)
                    Text(String(format: "%.1fm", settings.minDepth))
                        .font(.caption)
                        .frame(width: 50)
                }

                HStack {
                    Text("Max:")
                    Slider(value: $settings.maxDepth, in: 1...10, step: 0.1)
                    Text(String(format: "%.1fm", settings.maxDepth))
                        .font(.caption)
                        .frame(width: 50)
                }
            }

            Divider()

            // Performance Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("FPS:")
                    Text(String(format: "%.1f", settings.fps))
                        .foregroundColor(.green)
                    Spacer()
                    Text("Render Time:")
                    Text(String(format: "%.1fms", settings.renderTime))
                        .foregroundColor(.orange)
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

struct DepthSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DepthSettingsView(settings: DepthSettings())
            .frame(width: 350, height: 600)
    }
}
