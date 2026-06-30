#include <metal_stdlib>
using namespace metal;

struct PCVertex {
    float3 position;
    float3 color;
};

struct PCUniforms {
    float4x4 mvp;
    float pointSize;
};

struct PCOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float3 color;
};

vertex PCOut pc_vertex(uint vid [[vertex_id]],
                       const device PCVertex* verts [[buffer(0)]],
                       constant PCUniforms& u [[buffer(1)]]) {
    PCOut out;
    out.position = u.mvp * float4(verts[vid].position, 1.0);
    out.pointSize = u.pointSize;
    out.color = verts[vid].color;
    return out;
}

fragment float4 pc_fragment(PCOut in [[stage_in]],
                            float2 coord [[point_coord]]) {
    // Round the square point sprite into a disc.
    float2 d = coord - float2(0.5, 0.5);
    if (dot(d, d) > 0.25) {
        discard_fragment();
    }
    return float4(in.color, 1.0);
}
