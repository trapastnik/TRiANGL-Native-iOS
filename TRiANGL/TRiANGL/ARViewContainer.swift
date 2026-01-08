import SwiftUI
import RealityKit
import ARKit
import MetalKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arManager: ARManager
    @ObservedObject var settings: DepthSettings

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR view
        arView.session = arManager.session
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arManager.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)

        // Add depth map overlay (UIImage mode)
        let depthOverlay = UIImageView(frame: arView.bounds)
        depthOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        depthOverlay.contentMode = .scaleAspectFill
        depthOverlay.alpha = 0.7
        depthOverlay.isHidden = true
        depthOverlay.tag = 999
        depthOverlay.clipsToBounds = true
        arView.addSubview(depthOverlay)

        // Add Metal depth view (Metal mode)
        let metalView = MTKView(frame: arView.bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.backgroundColor = .clear
        metalView.isOpaque = false
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalView.isHidden = true
        metalView.tag = 998
        arView.addSubview(metalView)

        // Store ARView in context
        context.coordinator.arView = arView
        context.coordinator.depthOverlay = depthOverlay
        context.coordinator.metalView = metalView
        context.coordinator.settings = settings

        // Initialize Metal renderer
        if let renderer = DepthRenderer() {
            context.coordinator.metalRenderer = renderer
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Lightweight: Update alpha for both overlays
        context.coordinator.depthOverlay?.alpha = CGFloat(settings.overlayAlpha)
        context.coordinator.metalView?.layer.opacity = settings.overlayAlpha

        // Only update depth map if showing (expensive operation)
        if arManager.showDepthMap {
            context.coordinator.updateDepthMap(show: true, session: arManager.session)
        } else {
            // Hide both depth overlays when not showing
            context.coordinator.depthOverlay?.isHidden = true
            context.coordinator.metalView?.isHidden = true
        }

        // Visualize detected planes with visibility filters
        context.coordinator.updatePlaneVisualization(
            planes: arManager.detectedPlanes,
            showCeiling: arManager.showCeiling,
            showWalls: arManager.showWalls,
            in: uiView
        )

        // Visualize corner if detected
        if let cornerGeometry = arManager.cornerGeometry {
            context.coordinator.visualizeCorner(cornerGeometry, in: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var arView: ARView?
        weak var depthOverlay: UIImageView?
        weak var metalView: MTKView?
        var metalRenderer: DepthRenderer?
        var settings: DepthSettings?

        var planeEntities: [UUID: (anchor: AnchorEntity, classification: ARPlaneAnchor.Classification)] = [:]
        var cornerAnchor: AnchorEntity?
        var edgeAnchors: [AnchorEntity] = []

        // Performance optimization variables
        private var depthFrameCounter = 0
        private var isProcessingDepth = false
        private let depthProcessingQueue = DispatchQueue(label: "com.triangl.depthProcessing", qos: .userInitiated)
        private var lastFrameTime: CFTimeInterval = 0
        private var frameCount = 0

        // Throttle updateUIView calls for Metal rendering
        private var lastMetalRenderTime: CFTimeInterval = 0
        private let minMetalRenderInterval: CFTimeInterval = 1.0 / 60.0 // Max 60 FPS for Metal updates

        // Cache expensive calculations
        private var cachedDisplayTransform: CGAffineTransform?
        private var cachedInterfaceOrientation: UIInterfaceOrientation = .portrait
        private var cachedViewportSize: CGSize = .zero

        func updatePlaneVisualization(planes: [UUID: PlaneInfo], showCeiling: Bool, showWalls: Bool, in arView: ARView) {
            // Remove planes that no longer exist
            for (id, entityInfo) in planeEntities {
                if planes[id] == nil {
                    arView.scene.removeAnchor(entityInfo.anchor)
                    planeEntities.removeValue(forKey: id)
                }
            }

            // Add new planes or update visibility and size
            for (id, planeInfo) in planes {
                if let entityInfo = planeEntities[id] {
                    // Update visibility based on classification
                    let shouldShow = (entityInfo.classification == .ceiling && showCeiling) ||
                                   (entityInfo.classification == .wall && showWalls)
                    entityInfo.anchor.isEnabled = shouldShow

                    // Update plane size as ARKit refines it
                    if let arPlaneAnchor = planeInfo.anchor,
                       let planeEntity = entityInfo.anchor.children.first as? ModelEntity {
                        let width = arPlaneAnchor.planeExtent.width
                        let height = arPlaneAnchor.planeExtent.height
                        planeEntity.model?.mesh = MeshResource.generatePlane(width: width, depth: height)
                    }
                } else {
                    // Create new plane visualization using actual plane dimensions
                    if let arPlaneAnchor = planeInfo.anchor {
                        // Use the actual plane extent dimensions
                        let width = arPlaneAnchor.planeExtent.width
                        let height = arPlaneAnchor.planeExtent.height
                        let planeMesh = MeshResource.generatePlane(width: width, depth: height)

                        let color: UIColor
                        switch planeInfo.classification {
                        case .ceiling:
                            color = UIColor.cyan.withAlphaComponent(0.3)
                        case .wall:
                            color = UIColor.yellow.withAlphaComponent(0.3)
                        default:
                            color = UIColor.gray.withAlphaComponent(0.3)
                        }

                        var material = SimpleMaterial()
                        material.color = .init(tint: color)
                        material.metallic = 0.0
                        material.roughness = 1.0

                        let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])

                        // Use ARKit anchor for proper world tracking
                        let anchor = AnchorEntity(anchor: arPlaneAnchor)
                        anchor.addChild(planeEntity)
                        arView.scene.addAnchor(anchor)

                        // Store anchor with classification
                        planeEntities[id] = (anchor, planeInfo.classification)

                        // Set initial visibility
                        let shouldShow = (planeInfo.classification == .ceiling && showCeiling) ||
                                       (planeInfo.classification == .wall && showWalls)
                        anchor.isEnabled = shouldShow
                    }
                }
            }
        }

        func visualizeCorner(_ geometry: CornerGeometry, in arView: ARView) {
            // Remove previous corner visualization
            if let oldAnchor = cornerAnchor {
                arView.scene.removeAnchor(oldAnchor)
                cornerAnchor = nil
            }
            edgeAnchors.forEach { arView.scene.removeAnchor($0) }
            edgeAnchors.removeAll()

            // Anchor to the ceiling plane for stability
            guard let ceilingAnchor = geometry.ceilingPlane.anchor else { return }

            // Create main anchor using the ceiling plane
            let mainAnchor = AnchorEntity(anchor: ceilingAnchor)

            // Create corner point (red sphere)
            let cornerMesh = MeshResource.generateSphere(radius: 0.05)
            var cornerMaterial = SimpleMaterial()
            cornerMaterial.color = .init(tint: .red)
            cornerMaterial.metallic = 0.0
            cornerMaterial.roughness = 1.0

            let corner = ModelEntity(mesh: cornerMesh, materials: [cornerMaterial])

            // Convert corner position to ceiling anchor's local space
            let ceilingTransform = ceilingAnchor.transform
            let localCornerPos = simd_mul(simd_inverse(ceilingTransform), simd_float4(geometry.cornerVertex, 1))
            corner.position = SIMD3<Float>(localCornerPos.x, localCornerPos.y, localCornerPos.z)

            mainAnchor.addChild(corner)
            arView.scene.addAnchor(mainAnchor)
            cornerAnchor = mainAnchor

            // Create edge lines (green cylinders) - all anchored to ceiling
            let edgeLength: Float = 0.5
            let edgeRadius: Float = 0.01

            // Edge directions are cross products of plane normals
            // Note: ARKit normals - ceiling normal points DOWN, wall normals point OUTWARD

            // Edge 1: Along ceiling-left wall intersection (horizontal edge 1)
            let edge1Direction = simd_normalize(simd_cross(geometry.ceilingPlane.normal, geometry.leftWallPlane.normal))
            createEdgeLine(
                from: geometry.cornerVertex,
                direction: edge1Direction,
                length: edgeLength,
                radius: edgeRadius,
                anchor: ceilingAnchor,
                in: arView
            )

            // Edge 2: Along ceiling-right wall intersection (horizontal edge 2)
            let edge2Direction = simd_normalize(simd_cross(geometry.ceilingPlane.normal, geometry.rightWallPlane.normal))
            createEdgeLine(
                from: geometry.cornerVertex,
                direction: edge2Direction,
                length: edgeLength,
                radius: edgeRadius,
                anchor: ceilingAnchor,
                in: arView
            )

            // Edge 3: Vertical edge (along left-right walls intersection)
            let edge3Direction = simd_normalize(simd_cross(geometry.leftWallPlane.normal, geometry.rightWallPlane.normal))
            createEdgeLine(
                from: geometry.cornerVertex,
                direction: edge3Direction,
                length: edgeLength,
                radius: edgeRadius,
                anchor: ceilingAnchor,
                in: arView
            )
        }

        private func createEdgeLine(
            from start: SIMD3<Float>,
            direction: SIMD3<Float>,
            length: Float,
            radius: Float,
            anchor planeAnchor: ARPlaneAnchor,
            in arView: ARView
        ) {
            // Use cylinder for clean lines (iOS 18+)
            let lineMesh = MeshResource.generateCylinder(height: length, radius: radius)
            var lineMaterial = SimpleMaterial()
            lineMaterial.color = .init(tint: .green)
            lineMaterial.metallic = 0.0
            lineMaterial.roughness = 1.0

            let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])

            // Convert to local coordinates of the plane anchor
            let anchorTransform = planeAnchor.transform
            let midpoint = start + direction * (length / 2)
            let localMidpoint = simd_mul(simd_inverse(anchorTransform), simd_float4(midpoint, 1))
            lineEntity.position = SIMD3<Float>(localMidpoint.x, localMidpoint.y, localMidpoint.z)

            // Orient the box along the direction
            // Box's default orientation is along Y axis
            let defaultUp = SIMD3<Float>(0, 1, 0)
            let normalizedDirection = simd_normalize(direction)

            // Calculate rotation from Y axis to desired direction
            if simd_length(simd_cross(defaultUp, normalizedDirection)) > 0.001 {
                let rotation = simd_quatf(from: defaultUp, to: normalizedDirection)
                lineEntity.orientation = rotation
            }

            let edgeAnchor = AnchorEntity(anchor: planeAnchor)
            edgeAnchor.addChild(lineEntity)
            arView.scene.addAnchor(edgeAnchor)

            edgeAnchors.append(edgeAnchor)
        }

        func updateDepthMap(show: Bool, session: ARSession) {
            guard let settings = settings else { return }

            // Show/hide appropriate view based on render mode
            if settings.renderMode == .uiImage {
                depthOverlay?.isHidden = !show
                metalView?.isHidden = true
            } else {
                depthOverlay?.isHidden = true
                metalView?.isHidden = !show
            }

            if show {
                // FPS calculation
                let currentTime = CACurrentMediaTime()
                frameCount += 1
                if currentTime - lastFrameTime >= 1.0 {
                    DispatchQueue.main.async {
                        settings.fps = Double(self.frameCount) / (currentTime - self.lastFrameTime)
                    }
                    frameCount = 0
                    lastFrameTime = currentTime
                }

                // Frame skipping: only process every Nth frame (configurable)
                depthFrameCounter += 1
                if depthFrameCounter % (settings.frameSkip + 1) != 0 {
                    return
                }

                // Skip if already processing to avoid backlog
                guard !isProcessingDepth else { return }

                guard let frame = session.currentFrame else { return }

                // Get depth map based on settings
                let depthData: CVPixelBuffer?
                if settings.useSmoothedDepth {
                    depthData = frame.smoothedSceneDepth?.depthMap
                } else {
                    depthData = frame.sceneDepth?.depthMap
                }

                guard let depthMap = depthData, let arView = arView else { return }

                let startTime = CACurrentMediaTime()

                // Get current orientation
                let interfaceOrientation = getInterfaceOrientation()

                // CRITICAL FIX: displayTransform must use actual pixel dimensions
                // drawable.texture size includes device scale factor (e.g. 2x or 3x for Retina)
                let viewportSize: CGSize
                if settings.renderMode == .metal, let metalView = metalView, let drawable = metalView.currentDrawable {
                    // Use actual drawable texture size in pixels
                    viewportSize = CGSize(
                        width: CGFloat(drawable.texture.width),
                        height: CGFloat(drawable.texture.height)
                    )
                } else {
                    // CPU rendering - use view bounds
                    viewportSize = arView.bounds.size
                }

                // Get or calculate displayTransform
                // Only recalculate if orientation or viewport changed
                let displayTransform: CGAffineTransform
                if cachedInterfaceOrientation == interfaceOrientation &&
                   cachedViewportSize == viewportSize,
                   let cached = cachedDisplayTransform {
                    displayTransform = cached
                } else {
                    // displayTransform maps texture coordinates [0,1] to viewport
                    // Handles device orientation, mirroring, and aspect ratio
                    displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewportSize)
                    cachedDisplayTransform = displayTransform
                    cachedInterfaceOrientation = interfaceOrientation
                    cachedViewportSize = viewportSize
                }

                // Route to appropriate renderer
                if settings.renderMode == .metal {
                    // Metal rendering (GPU-only path)
                    renderDepthMapMetal(
                        depthMap: depthMap,
                        frame: frame,
                        displayTransform: displayTransform
                    )

                    let renderTime = (CACurrentMediaTime() - startTime) * 1000
                    DispatchQueue.main.async {
                        settings.renderTime = renderTime
                    }
                } else {
                    // UIImage rendering (CPU path)
                    let cameraImage = frame.capturedImage

                    isProcessingDepth = true

                    depthProcessingQueue.async { [weak self, weak depthOverlay] in
                        guard let self = self else { return }

                        let depthImage = self.depthMapToImage(
                            depthMap,
                            cameraImage: cameraImage,
                            viewportSize: viewportSize,
                            interfaceOrientation: interfaceOrientation,
                            displayTransform: displayTransform
                        )

                        let renderTime = (CACurrentMediaTime() - startTime) * 1000

                        DispatchQueue.main.async {
                            depthOverlay?.image = depthImage
                            self.isProcessingDepth = false
                            settings.renderTime = renderTime
                        }
                    }
                }
            }
        }

        private func renderDepthMapMetal(
            depthMap: CVPixelBuffer,
            frame: ARFrame,
            displayTransform: CGAffineTransform
        ) {
            // Throttle Metal rendering to prevent excessive GPU calls
            let currentTime = CACurrentMediaTime()
            guard currentTime - lastMetalRenderTime >= minMetalRenderInterval else {
                return
            }
            lastMetalRenderTime = currentTime

            guard let metalView = metalView,
                  let metalRenderer = metalRenderer,
                  let drawable = metalView.currentDrawable,
                  let settings = settings else {
                return
            }

            let interfaceOrientation = getInterfaceOrientation()

            metalRenderer.render(
                depthMap: depthMap,
                to: drawable,
                interfaceOrientation: interfaceOrientation,
                minDepth: settings.minDepth,
                maxDepth: settings.maxDepth,
                alpha: settings.overlayAlpha,
                displayTransform: displayTransform
            )
        }

        private func getInterfaceOrientation() -> UIInterfaceOrientation {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return .portrait
            }
            return windowScene.effectiveGeometry.interfaceOrientation
        }

        private func depthMapToImage(
            _ depthMap: CVPixelBuffer,
            cameraImage: CVPixelBuffer,
            viewportSize: CGSize,
            interfaceOrientation: UIInterfaceOrientation,
            displayTransform: CGAffineTransform? = nil
        ) -> UIImage? {
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

            let depthWidth = CVPixelBufferGetWidth(depthMap)
            let depthHeight = CVPixelBufferGetHeight(depthMap)

            guard let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
                return nil
            }

            // Performance optimization: configurable downsampling
            // For best alignment, use downsampleFactor = 1 (no downsampling)
            let downsampleFactor = settings?.downsampleFactor ?? 1
            let outputWidth = depthWidth / downsampleFactor
            let outputHeight = depthHeight / downsampleFactor

            // Get depth range from settings
            let minDepth = settings?.minDepth ?? 1.0
            let maxDepth = settings?.maxDepth ?? 4.0
            let depthRange = maxDepth - minDepth

            // Convert depth data to colored image with gradient (blue = close, red = far)
            let depthData = depthBaseAddress.assumingMemoryBound(to: Float32.self)
            var colorData = [UInt8](repeating: 0, count: outputWidth * outputHeight * 4)

            // Prepare transform for better alignment
            let useTransform = displayTransform != nil
            let transform = displayTransform ?? .identity

            for y in 0..<outputHeight {
                for x in 0..<outputWidth {
                    // Normalized coordinates [0, 1]
                    var texCoordX = Float(x) / Float(outputWidth)
                    var texCoordY = Float(y) / Float(outputHeight)

                    // Apply displayTransform if available for perfect alignment
                    if useTransform {
                        let point = CGPoint(x: CGFloat(texCoordX), y: CGFloat(texCoordY))
                        let transformedPoint = point.applying(transform)
                        texCoordX = Float(transformedPoint.x)
                        texCoordY = Float(transformedPoint.y)
                    }

                    // Clamp to valid range
                    texCoordX = max(0.0, min(1.0, texCoordX))
                    texCoordY = max(0.0, min(1.0, texCoordY))

                    // Sample from original depth map with bilinear interpolation simulation
                    let srcX = Int(texCoordX * Float(depthWidth - 1))
                    let srcY = Int(texCoordY * Float(depthHeight - 1))
                    let srcIndex = srcY * depthWidth + srcX

                    // Bounds check
                    guard srcIndex >= 0 && srcIndex < depthWidth * depthHeight else {
                        continue
                    }

                    let depth = depthData[srcIndex]

                    // Normalize depth to 0-1 range using configurable min/max
                    let normalizedDepth = min(max((depth - minDepth) / depthRange, 0.0), 1.0)

                    // Create color gradient: Blue (close) -> Cyan -> Green -> Yellow -> Red (far)
                    let (r, g, b) = depthToColor(normalizedDepth)

                    let destIndex = y * outputWidth + x
                    let colorIndex = destIndex * 4
                    colorData[colorIndex] = r     // R
                    colorData[colorIndex + 1] = g // G
                    colorData[colorIndex + 2] = b // B
                    colorData[colorIndex + 3] = 255 // A
                }
            }

            // Create CGImage from pixel data (using downsampled dimensions)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

            guard let context = CGContext(
                data: &colorData,
                width: outputWidth,
                height: outputHeight,
                bitsPerComponent: 8,
                bytesPerRow: outputWidth * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ),
            let cgImage = context.makeImage() else {
                return nil
            }

            // Create UIImage and apply proper orientation for camera alignment
            // ARKit depth is in sensor orientation, need to match display orientation
            let imageOrientation: UIImage.Orientation
            switch interfaceOrientation {
            case .portrait:
                imageOrientation = .right
            case .portraitUpsideDown:
                imageOrientation = .left
            case .landscapeLeft:
                imageOrientation = .down
            case .landscapeRight:
                imageOrientation = .up
            default:
                imageOrientation = .right
            }

            return UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
        }

        // Convert normalized depth (0-1) to color gradient
        // 0.0 (1m, close) = Blue, 1.0 (4m, far) = Red
        private func depthToColor(_ depth: Float) -> (UInt8, UInt8, UInt8) {
            // Use a smooth gradient through color spectrum
            // Blue (1m) -> Cyan (1.75m) -> Green (2.5m) -> Yellow (3.25m) -> Red (4m)

            let r: UInt8
            let g: UInt8
            let b: UInt8

            if depth < 0.25 {
                // Blue to Cyan (0.0 - 0.25)
                let t = depth / 0.25
                r = 0
                g = UInt8(t * 255.0)
                b = 255
            } else if depth < 0.5 {
                // Cyan to Green (0.25 - 0.5)
                let t = (depth - 0.25) / 0.25
                r = 0
                g = 255
                b = UInt8((1.0 - t) * 255.0)
            } else if depth < 0.75 {
                // Green to Yellow (0.5 - 0.75)
                let t = (depth - 0.5) / 0.25
                r = UInt8(t * 255.0)
                g = 255
                b = 0
            } else {
                // Yellow to Red (0.75 - 1.0)
                let t = (depth - 0.75) / 0.25
                r = 255
                g = UInt8((1.0 - t) * 255.0)
                b = 0
            }

            return (r, g, b)
        }
    }
}
