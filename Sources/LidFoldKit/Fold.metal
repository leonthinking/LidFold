#include <metal_stdlib>
using namespace metal;

struct VertexOut { float4 position [[position]]; float2 uv; };
struct Uniforms { float progress; float blur; float shadow; float padding; };

vertex VertexOut foldVertex(uint id [[vertex_id]]) {
    const float2 vertices[] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
    float2 p = vertices[id];
    return {float4(p,0,1), float2((p.x + 1) * 0.5, (1 - p.y) * 0.5)};
}

fragment float4 foldFragment(VertexOut in [[stage_in]], texture2d<float> desktop [[texture(0)]],
                             constant Uniforms &u [[buffer(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float p = clamp(u.progress, 0.0f, 1.0f);
    float theta = p * 1.34;
    float c = cos(theta), k = sin(theta) * 0.65;
    float d = 1.0 - in.uv.y;
    float denominator = c - d * k;
    if (denominator <= 0.0001) return float4(0,0,0,1);
    float height = d / denominator;
    float2 uv = float2((in.uv.x - 0.5) * (1.0 + height * k) + 0.5, 1.0 - height);
    if (any(uv < 0.0) || any(uv > 1.0)) return float4(0,0,0,1);

    float2 texel = 1.0 / float2(desktop.get_width(), desktop.get_height());
    float radius = u.blur * p * p * (0.3 + 0.7 * height);
    float3 color = desktop.sample(s, uv).rgb * 0.20;
    const float2 offsets[] = {float2(1,0), float2(-1,0), float2(0,1), float2(0,-1),
                             float2(.707,.707), float2(-.707,.707), float2(.707,-.707), float2(-.707,-.707)};
    for (uint i = 0; i < 8; ++i) color += desktop.sample(s, uv + offsets[i] * texel * radius).rgb * 0.10;
    color *= 1.0 - u.shadow * p * (0.25 + 0.75 * height);
    // Fade fully into the hinge near closure; never interfere with macOS sleep.
    color *= 1.0 - smoothstep(0.90, 1.0, p);
    return float4(color, 1);
}
