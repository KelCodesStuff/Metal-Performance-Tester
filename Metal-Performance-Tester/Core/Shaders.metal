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

// --- COMPUTE SHADERS ---
// Compute shaders for performance testing

// Simple compute shader for basic compute workload testing
kernel void compute_simple(const device float* input [[buffer(0)]],
                          device float* output [[buffer(1)]],
                          uint index [[thread_position_in_grid]]) {
    // Simple mathematical operations to create compute workload
    float x = input[index];
    float result = 0.0;
    
    // Perform multiple iterations of computation
    for (int i = 0; i < 100; i++) {
        result += sin(x) * cos(x) * tan(x);
        x = result * 0.1;
    }
    
    output[index] = result;
}

// Memory-intensive compute shader for memory bandwidth testing
kernel void compute_memory_intensive(const device float* input [[buffer(0)]],
                                    device float* output [[buffer(1)]],
                                    constant uint& data_size [[buffer(2)]],
                                    uint index [[thread_position_in_grid]]) {
    // Memory-intensive operations
    float sum = 0.0;
    uint stride = max(1u, data_size / 1024u); // Access every nth element
    
    for (uint i = 0; i < data_size; i += stride) {
        if (i + index < data_size) {
            sum += input[i + index];
        }
    }
    
    output[index] = sum;
}

// Arithmetic-intensive compute shader for ALU testing
kernel void compute_arithmetic_intensive(const device float* input [[buffer(0)]],
                                        device float* output [[buffer(1)]],
                                        uint index [[thread_position_in_grid]]) {
    // Arithmetic-intensive operations
    float x = input[index];
    float result = x;
    
    // Perform many arithmetic operations
    for (int i = 0; i < 1000; i++) {
        result = result * 1.1 + sin(result) + cos(result);
        result = sqrt(abs(result)) + log(abs(result) + 1.0);
        result = pow(result, 1.1) + tan(result);
    }
    
    output[index] = result;
}

// Matrix multiplication compute shader for complex workload
kernel void compute_matrix_multiply(const device float* matrix_a [[buffer(0)]],
                                   const device float* matrix_b [[buffer(1)]],
                                   device float* matrix_c [[buffer(2)]],
                                   constant uint& matrix_size [[buffer(3)]],
                                   uint2 index [[thread_position_in_grid]]) {
    if (index.x >= matrix_size || index.y >= matrix_size) return;
    
    float sum = 0.0;
    for (uint k = 0; k < matrix_size; k++) {
        sum += matrix_a[index.y * matrix_size + k] * matrix_b[k * matrix_size + index.x];
    }
    
    matrix_c[index.y * matrix_size + index.x] = sum;
}
