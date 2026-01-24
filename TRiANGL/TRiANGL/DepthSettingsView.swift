import SwiftUI

struct DepthSettingsView: View {
    @ObservedObject var settings: DepthSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.white)

            // Render Mode - Compact
            Picker("", selection: $settings.renderMode) {
                ForEach(DepthRenderMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider().background(Color.white.opacity(0.3))

            // Frame Skip - Compact
            HStack {
                Text("Skip:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("\(settings.frameSkip)")
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .frame(width: 20)
                Slider(value: Binding(
                    get: { Double(settings.frameSkip) },
                    set: { settings.frameSkip = Int($0) }
                ), in: 0...10, step: 1)
                .accentColor(.cyan)
            }

            // Resolution - Compact
            HStack {
                Text("Res:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text("1/\(settings.downsampleFactor)")
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                Slider(value: Binding(
                    get: { Double(settings.downsampleFactor) },
                    set: { settings.downsampleFactor = Int($0) }
                ), in: 1...8, step: 1)
                .accentColor(.cyan)
            }

            Divider().background(Color.white.opacity(0.3))

            // Smoothed Depth Toggle
            Toggle("Smoothed", isOn: $settings.useSmoothedDepth)
                .font(.caption)
                .foregroundColor(.white)

            // Overlay Alpha
            HStack {
                Text("Alpha:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(String(format: "%.1f", settings.overlayAlpha))
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                Slider(value: $settings.overlayAlpha, in: 0...1, step: 0.1)
                    .accentColor(.cyan)
            }

            // Depth Scale (for alignment with camera)
            HStack {
                Text("Scale:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(String(format: "%.2f", settings.depthScale))
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .frame(width: 40)
                Slider(value: $settings.depthScale, in: 0.5...2.5, step: 0.05)
                    .accentColor(.cyan)
            }

            Divider().background(Color.white.opacity(0.3))

            // Depth Range - Compact
            VStack(spacing: 6) {
                HStack {
                    Text("Min:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(format: "%.1fm", settings.minDepth))
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .frame(width: 40)
                    Slider(value: $settings.minDepth, in: 0.1...5, step: 0.1)
                        .accentColor(.cyan)
                }

                HStack {
                    Text("Max:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(format: "%.1fm", settings.maxDepth))
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .frame(width: 40)
                    Slider(value: $settings.maxDepth, in: 1...10, step: 0.1)
                        .accentColor(.cyan)
                }
            }

            Divider().background(Color.white.opacity(0.3))

            // Performance Stats - Compact
            HStack {
                Text("FPS:")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(String(format: "%.0f", settings.fps))
                    .font(.caption2)
                    .foregroundColor(.green)
                Spacer()
                Text("Render:")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text(String(format: "%.1fms", settings.renderTime))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
    }
}

struct DepthSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DepthSettingsView(settings: DepthSettings())
            .frame(width: 350, height: 600)
    }
}
