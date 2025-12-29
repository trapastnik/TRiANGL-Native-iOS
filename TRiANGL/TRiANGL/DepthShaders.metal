#include <metal_stdlib>
using namespace metal;

// Vertex structure for full-screen quad
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Simple vertex shader for full-screen quad
vertex VertexOut depthVertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// Fragment shader to convert depth to color gradient
fragment float4 depthFragmentShader(VertexOut in [[stage_in]],
                                   texture2d<float, access::sample> depthTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    // Sample depth value
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;

    // Normalize depth to 0-1 range (1-4 meters)
    float normalizedDepth = clamp((depth - 1.0) / 3.0, 0.0, 1.0);

    // Create color gradient: Blue (close) -> Cyan -> Green -> Yellow -> Red (far)
    float3 color;

    if (normalizedDepth < 0.25) {
        // Blue to Cyan (0.0 - 0.25)
        float t = normalizedDepth / 0.25;
        color = float3(0.0, t, 1.0);
    } else if (normalizedDepth < 0.5) {
        // Cyan to Green (0.25 - 0.5)
        float t = (normalizedDepth - 0.25) / 0.25;
        color = float3(0.0, 1.0, 1.0 - t);
    } else if (normalizedDepth < 0.75) {
        // Green to Yellow (0.5 - 0.75)
        float t = (normalizedDepth - 0.5) / 0.25;
        color = float3(t, 1.0, 0.0);
    } else {
        // Yellow to Red (0.75 - 1.0)
        float t = (normalizedDepth - 0.75) / 0.25;
        color = float3(1.0, 1.0 - t, 0.0);
    }

    return float4(color, 0.7);  // 0.7 alpha for transparency
}
