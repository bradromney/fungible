#include <metal_stdlib>
using namespace metal;

// GPU mirror of FungibleCapture.Unprojection (the CPU path is the spec/oracle).
// One thread per depth pixel: back-project to camera space, then to world via
// the camera→world matrix (which already includes the ARKit axis flip), writing
// confident, in-range points into an append buffer. This is the throughput path
// the live capture loop will switch to after the CPU path is verified on device.

struct Intrinsics {
    float fx, fy, cx, cy;
};

struct OutPoint {
    float3 position;
    uint   rgbaConfidence; // packed: r,g,b,confidence
};

kernel void unproject(
    device const float*        depth        [[buffer(0)]],
    device const uchar*        confidence   [[buffer(1)]],
    constant Intrinsics&       k            [[buffer(2)]],
    constant float4x4&         cameraToWorld[[buffer(3)]],
    constant uint&             width        [[buffer(4)]],
    constant uint&             height       [[buffer(5)]],
    constant uchar&            minConfidence[[buffer(6)]],
    constant float&            maxRange     [[buffer(7)]],
    device atomic_uint*        outCount     [[buffer(8)]],
    device OutPoint*           outPoints    [[buffer(9)]],
    constant uint&             outCapacity  [[buffer(10)]],
    uint2                      gid          [[thread_position_in_grid]])
{
    if (gid.x >= width || gid.y >= height) { return; }
    uint i = gid.y * width + gid.x;

    float d = depth[i];
    uchar c = confidence[i];
    if (c < minConfidence || d <= 0.0f || d > maxRange) { return; }

    // Pinhole back-projection (matches Unprojection.cameraPoint: +Z forward).
    float x = (float(gid.x) - k.cx) * d / k.fx;
    float y = (float(gid.y) - k.cy) * d / k.fy;
    float4 cam = float4(x, y, d, 1.0f);
    float4 world = cameraToWorld * cam;

    uint slot = atomic_fetch_add_explicit(outCount, 1u, memory_order_relaxed);
    if (slot >= outCapacity) { return; } // bounded buffer

    uchar shade = uchar(min(255, 85 * (int(c) + 1)));
    OutPoint p;
    p.position = world.xyz;
    p.rgbaConfidence = (uint(shade) << 24) | (uint(shade) << 16) | (uint(shade) << 8) | uint(c);
    outPoints[slot] = p;
}
