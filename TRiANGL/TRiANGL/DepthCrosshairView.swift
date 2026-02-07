import SwiftUI

/// Crosshair overlay that shows center point and measures distance to that point
struct DepthCrosshairView: View {
    let centerDistance: Float?
    let isEnabled: Bool

    var body: some View {
        if isEnabled {
            ZStack {
                // Crosshair lines
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 2, height: 20)
                    Spacer()
                    Rectangle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 2, height: 20)
                }

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 20, height: 2)
                    Spacer()
                    Rectangle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 20, height: 2)
                }

                // Center dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                    )

                // Distance label
                if let distance = centerDistance, distance > 0 {
                    VStack {
                        Spacer()
                        Text(String(format: "%.2f m", distance))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                            .padding(.bottom, 100)
                    }
                }
            }
        }
    }
}
