// QuickStart.swift
// Пример базовой структуры приложения TRiANGL

import SwiftUI
import ARKit
import RealityKit

// MARK: - Main App
@main
struct TRiANGLApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @State private var currentScreen: Screen = .welcome

    enum Screen {
        case welcome
        case scanner
        case review
        case preview
        case export
    }

    var body: some View {
        NavigationView {
            Group {
                switch currentScreen {
                case .welcome:
                    WelcomeView(onStart: {
                        currentScreen = .scanner
                    })
                case .scanner:
                    ScannerView(onComplete: { geometry in
                        currentScreen = .review
                    })
                case .review:
                    Text("Review Screen - TODO")
                case .preview:
                    Text("AR Preview Screen - TODO")
                case .export:
                    Text("Export Screen - TODO")
                }
            }
            .navigationTitle("TRiANGL")
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("TRiANGL")
                .font(.system(size: 48, weight: .bold))

            Text("Create 3D Corner Illusions")
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: 20) {
                FeatureCard(icon: "camera.fill", title: "Scan", description: "LiDAR corner scanning")
                FeatureCard(icon: "cube.fill", title: "Design", description: "Choose cube pattern")
                FeatureCard(icon: "printer.fill", title: "Print", description: "Generate patterns")
            }

            Spacer()

            Button(action: onStart) {
                Text("Start Scanning")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
                .frame(width: 50)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Scanner View
struct ScannerView: View {
    @StateObject private var arManager = ARManager()
    let onComplete: (CornerGeometry) -> Void

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(arManager: arManager)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                // Status card
                StatusCard(arManager: arManager)
                    .padding()

                Spacer()

                // Instructions
                InstructionView(arManager: arManager)
                    .padding()

                // Capture button
                if arManager.isReadyToCapture {
                    Button(action: {
                        arManager.captureCorner()
                    }) {
                        Text("Capture Corner")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            arManager.startSession()
        }
        .onDisappear {
            arManager.stopSession()
        }
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    let arManager: ARManager

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arManager.arView = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates if needed
    }
}

// MARK: - Status Card
struct StatusCard: View {
    @ObservedObject var arManager: ARManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Planes:")
                .font(.headline)

            HStack {
                PlaneStatus(name: "Ceiling", detected: arManager.ceilingPlane != nil)
                PlaneStatus(name: "Left Wall", detected: arManager.leftWallPlane != nil)
                PlaneStatus(name: "Right Wall", detected: arManager.rightWallPlane != nil)
            }

            if let angle = arManager.currentAngle {
                Text("Angle: \(angle, specifier: "%.1f")°")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .foregroundColor(.white)
    }
}

struct PlaneStatus: View {
    let name: String
    let detected: Bool

    var body: some View {
        HStack {
            Image(systemName: detected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(detected ? .green : .gray)
            Text(name)
                .font(.caption)
        }
    }
}

// MARK: - Instruction View
struct InstructionView: View {
    @ObservedObject var arManager: ARManager

    var body: some View {
        Text(arManager.currentInstruction)
            .font(.body)
            .multilineTextAlignment(.center)
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

// MARK: - AR Manager
class ARManager: NSObject, ObservableObject {
    var arView: ARView?
    private var session = ARSession()

    // Published state
    @Published var ceilingPlane: PlaneParameters?
    @Published var leftWallPlane: PlaneParameters?
    @Published var rightWallPlane: PlaneParameters?
    @Published var currentAngle: Float?
    @Published var isReadyToCapture = false
    @Published var currentInstruction = "Point camera at ceiling corner"

    override init() {
        super.init()
        session.delegate = self
    }

    func startSession() {
        let configuration = ARWorldTrackingConfiguration()

        // Enable LiDAR
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        }

        // Enable plane detection
        configuration.planeDetection = [.horizontal, .vertical]

        // Enable scene reconstruction
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }

        session.run(configuration)
        print("✅ AR Session started with LiDAR")
    }

    func stopSession() {
        session.pause()
    }

    func captureCorner() {
        // TODO: Implement corner capture logic
        print("📸 Capturing corner...")
    }
}

// MARK: - ARSession Delegate
extension ARManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process depth map
        if let depthMap = frame.sceneDepth?.depthMap {
            processDepthMap(depthMap)
        }
    }

    private func processDepthMap(_ depthMap: CVPixelBuffer) {
        // TODO: Implement depth processing
        // 1. Convert to point cloud
        // 2. Detect planes
        // 3. Find corner
        // 4. Update published state
    }
}

// MARK: - Data Models

struct CornerGeometry {
    let cornerVertex: SIMD3<Float>
    let ceilingPlane: PlaneParameters
    let leftWallPlane: PlaneParameters
    let rightWallPlane: PlaneParameters
    let angleCeilingLeft: Float
    let angleCeilingRight: Float
    let angleWalls: Float
    let captureDate: Date
    let confidence: Float
}

struct PlaneParameters {
    let normal: SIMD3<Float>  // Unit normal vector
    let distance: Float        // Distance from origin
    let center: SIMD3<Float>   // Center point
    let extent: SIMD2<Float>   // Width, height
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
