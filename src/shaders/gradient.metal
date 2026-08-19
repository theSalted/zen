
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

kernel void gradient_kernel(
    texture2d<float, access::write> image [[texture(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = image.get_width();
    uint height = image.get_height();

    if (gid.x >= width || gid.y >= height) {
        return;
    }

    float r = float(gid.x) / float(width - 1);
    float g = float(gid.y) / float(height - 1);

    image.write(metal::float4(r, g, 0.0, 1.0), gid);
}

vertex VertexOut vertex_main(uint vertex_id [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0),
    };

    float2 uvs[3] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0),
    };
    VertexOut out;
    out.position = float4(positions[vertex_id], 0.0, 1.0);
    out.uv = uvs[vertex_id];

    return out;
}

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> image [[texture(0)]]
) {
    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    return image.sample(s, in.uv);
}
