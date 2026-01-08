import SwiftUI

struct ScannerView: View {
    @StateObject private var arManager = ARManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(arManager: arManager, settings: arManager.depthSettings)
                .edgesIgnoringSafeArea(.all)

            // UI Overlay
            VStack {
                // Top Status Bar
                HStack {
                    Button(action: {
                        arManager.pauseSession()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()

                    Spacer()

                    // Settings toggle
                    Button(action: {
                        arManager.depthSettings.showSettings.toggle()
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 28))
                            .foregroundColor(arManager.depthSettings.showSettings ? .cyan : .white)
                            .shadow(radius: 4)
                    }
                    .padding(.horizontal, 8)

                    // Depth map toggle with mode indicator
                    VStack(spacing: 2) {
                        Button(action: {
                            arManager.showDepthMap.toggle()
                        }) {
                            Image(systemName: arManager.showDepthMap ? "camera.metering.matrix" : "camera.metering.none")
                                .font(.system(size: 32))
                                .foregroundColor(arManager.showDepthMap ? .cyan : .white)
                                .shadow(radius: 4)
                        }

                        if arManager.showDepthMap {
                            Text(arManager.depthSettings.renderMode == .metal ? "Metal" : "CPU")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(arManager.depthSettings.renderMode == .metal ? .green : .orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 8)

                    Button(action: {
                        arManager.resetSession()
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.horizontal, 8)
                }

                // Status Message
                VStack(spacing: 8) {
                    Text(arManager.statusMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                        )
                        .padding(.horizontal, 20)

                    if arManager.cornerDetected {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Угол найден!")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }

                            // Distance to corner
                            if arManager.distanceToCorner > 0 {
                                Text("Расстояние: \(String(format: "%.2f", arManager.distanceToCorner))м")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.3))
                        )
                    }
                }

                Spacer()

                // Bottom Controls
                VStack(spacing: 16) {
                    // Plane Visibility Toggles
                    HStack(spacing: 12) {
                        Button(action: {
                            arManager.showCeiling.toggle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: arManager.showCeiling ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16))
                                Text("Потолок")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(arManager.showCeiling ? Color.cyan.opacity(0.6) : Color.gray.opacity(0.4))
                            )
                        }

                        Button(action: {
                            arManager.showWalls.toggle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: arManager.showWalls ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16))
                                Text("Стены")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(arManager.showWalls ? Color.yellow.opacity(0.6) : Color.gray.opacity(0.4))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.7))
                    )

                    // Plane Detection Status
                    HStack(spacing: 20) {
                        PlaneStatusIndicator(
                            icon: "square.dashed",
                            label: "Потолок",
                            isDetected: arManager.hasCeiling
                        )

                        PlaneStatusIndicator(
                            icon: "square.split.2x1",
                            label: "Стены \(arManager.wallCount)/2",
                            isDetected: arManager.hasWalls
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.7))
                    )

                    // Continue Button (if corner detected)
                    if arManager.cornerDetected {
                        Button(action: {
                            // TODO: Navigate to next screen
                            arManager.pauseSession()
                            dismiss()
                        }) {
                            HStack {
                                Text("Продолжить")
                                    .font(.headline)
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                            )
                        }
                    }
                }
                .padding(.bottom, 40)
            }

            // Settings Panel (overlay) - bottom left corner, semi-transparent
            if arManager.depthSettings.showSettings {
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Settings")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                // Close button
                                Button(action: {
                                    arManager.depthSettings.showSettings = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                            DepthSettingsView(settings: arManager.depthSettings)
                                .frame(width: 280)
                        }
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .padding(.leading, 16)
                        .padding(.bottom, 180)

                        Spacer()
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: arManager.depthSettings.showSettings)
        .animation(nil, value: arManager.depthSettings.overlayAlpha)
        .animation(nil, value: arManager.depthSettings.minDepth)
        .animation(nil, value: arManager.depthSettings.maxDepth)
        .animation(nil, value: arManager.depthSettings.frameSkip)
        .animation(nil, value: arManager.depthSettings.downsampleFactor)
        .onAppear {
            arManager.startSession()
        }
        .onDisappear {
            arManager.pauseSession()
        }
    }
}

// MARK: - Plane Status Indicator
struct PlaneStatusIndicator: View {
    let icon: String
    let label: String
    let isDetected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isDetected ? .green : .gray)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.white)

            Image(systemName: isDetected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isDetected ? .green : .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDetected ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
        )
    }
}

#Preview {
    ScannerView()
}
