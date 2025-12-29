import SwiftUI
import MetalKit
import ARKit

struct MetalDepthView: UIViewRepresentable {
    let depthMap: CVPixelBuffer
    let settings: DepthSettings

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.backgroundColor = .clear
        mtkView.isOpaque = false

        context.coordinator.mtkView = mtkView
        context.coordinator.settings = settings

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.depthMap = depthMap
        uiView.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var mtkView: MTKView?
        var depthMap: CVPixelBuffer?
        var settings: DepthSettings?
        var renderer: DepthRenderer?

        override init() {
            super.init()
            renderer = DepthRenderer()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }

        func draw(in view: MTKView) {
            guard let depthMap = depthMap,
                  let renderer = renderer,
                  let drawable = view.currentDrawable else {
                return
            }

            let startTime = CACurrentMediaTime()
            renderer.render(depthMap: depthMap, to: drawable)
            let renderTime = (CACurrentMediaTime() - startTime) * 1000

            DispatchQueue.main.async {
                self.settings?.renderTime = renderTime
            }
        }
    }
}
