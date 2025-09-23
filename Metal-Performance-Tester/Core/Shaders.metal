//
//  Shaders.metal
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/17/25.
//

// Import the Metal standard library.
#include <metal_stdlib>
using namespace metal;

// This struct defines the data we will pass for each vertex.
// The [[position]] attribute is a special keyword that tells Metal this is the
// final clip-space position of the vertex.
struct VertexOut {
    float4 position [[position]];
    float4 color;
};

// --- VERTEX SHADER ---
// A vertex shader is a program that runs once for every vertex you draw.
// Its primary job is to calculate the final position of the vertex.
vertex VertexOut vertex_main(const device packed_float3 *vertex_array [[buffer(0)]],
                           uint vertex_id [[vertex_id]]) {
    VertexOut out;
    // For this simple example, we'll just read the position directly.
    // The vertex_id tells us which vertex we're currently processing.
    out.position = float4(vertex_array[vertex_id], 1.0);
    
    // Assign a unique color to each vertex.
    if (vertex_id == 0) {
        out.color = float4(1, 0, 0, 1); // Red
    } else if (vertex_id == 1) {
        out.color = float4(0, 1, 0, 1); // Green
    } else {
        out.color = float4(0, 0, 1, 1); // Blue
    }
    
    return out;
}

// --- FRAGMENT SHADER ---
// A fragment shader runs once for every pixel that's part of your shape.
// Its job is to determine the final color of that pixel.
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // Metal automatically interpolates the color between the vertices,
    // creating a smooth gradient. We just return that interpolated color.
    return in.color;
}
