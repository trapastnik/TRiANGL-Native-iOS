import Foundation
import Combine

enum DepthRenderMode: String, CaseIterable {
    case uiImage = "UIImage (CPU)"
    case metal = "Metal (GPU)"
}

class DepthSettings: ObservableObject {
    // Render mode (Metal recommended for best alignment)
    @Published var renderMode: DepthRenderMode = .metal

    // Frame skipping (0 = process every frame, 1 = every 2nd, 2 = every 3rd, etc.)
    // Lower values = better alignment but higher CPU/GPU usage
    @Published var frameSkip: Int = 1 {
        didSet {
            frameSkip = max(0, min(frameSkip, 10))
        }
    }

    // Downsampling factor (1 = full res, 2 = half res, 3 = third res, etc.)
    // Use 1 for best alignment, higher values for performance
    @Published var downsampleFactor: Int = 1 {
        didSet {
            downsampleFactor = max(1, min(downsampleFactor, 8))
        }
    }

    // Use smoothed vs raw depth (smoothed = better temporal consistency)
    @Published var useSmoothedDepth: Bool = true

    // Overlay transparency (0.0 - 1.0)
    @Published var overlayAlpha: Float = 0.7 {
        didSet {
            overlayAlpha = max(0.0, min(overlayAlpha, 1.0))
        }
    }

    // Depth range for color mapping
    @Published var minDepth: Float = 1.0 {
        didSet {
            minDepth = max(0.1, min(minDepth, maxDepth - 0.1))
        }
    }

    @Published var maxDepth: Float = 4.0 {
        didSet {
            maxDepth = max(minDepth + 0.1, min(maxDepth, 10.0))
        }
    }

    // Performance stats
    @Published var fps: Double = 0.0
    @Published var renderTime: Double = 0.0

    // Center distance measurement (for crosshair)
    @Published var centerDistance: Float? = nil
    @Published var showCrosshair: Bool = true

    // Show/hide settings panel
    @Published var showSettings: Bool = false
}
