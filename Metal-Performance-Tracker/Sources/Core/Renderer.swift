//
//  Renderer.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/17/25.
//

// Import the Metal framework
import Metal

// A class dedicated to handling all Metal rendering logic.
class Renderer {
    
    // MARK: - Properties
    
    // Core Metal device objects
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    // The rendering pipeline state, which holds our compiled shaders
    let pipelineState: MTLRenderPipelineState
    
    // The buffer containing the vertex data for our triangle
    let vertexBuffer: MTLBuffer
    
    // The offscreen texture we will render to
    let renderTexture: MTLTexture
    
    // Test configuration
    let testConfig: TestConfiguration
    
    // Performance measurement objects
    /// Enhanced performance metrics manager for comprehensive GPU performance analysis
    private let performanceMetrics: EnhancedCounterManager

    // MARK: - Initialization

    init?(device: MTLDevice, testConfig: TestConfiguration = TestPreset.moderate.createConfiguration()) {
        self.device = device
        self.testConfig = testConfig
        
        // Print test configuration
        print("\nTest Configuration: \(testConfig.description)")
        print("Parameters:")
        print(testConfig.parametersDescription)
        print("Performance Impact: \(TestConfigurationHelper.estimatePerformanceImpact(testConfig))")
        
        // --- 1. Create a command queue ---
        // The command queue is responsible for managing and executing command buffers.
        guard let commandQueue = device.makeCommandQueue() else {
            print("Could not create command queue.")
            return nil
        }
        self.commandQueue = commandQueue
        
        // --- 2. Create the offscreen texture (our render target) ---
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = testConfig.effectiveWidth
        textureDescriptor.height = testConfig.effectiveHeight
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.usage = .renderTarget
        
        guard let renderTexture = device.makeTexture(descriptor: textureDescriptor) else {
            print("Failed to create the render target texture.")
            return nil
        }
        self.renderTexture = renderTexture
        
        // --- 3. Create the vertex buffer ---
        // Generate vertices based on test configuration
        let vertices = TestConfigurationHelper.generateTriangleVertices(
            count: testConfig.triangleCount, 
            complexity: testConfig.geometryComplexity
        )
        
        // Create a Metal buffer and copy our vertex data into it.
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                   length: vertices.count * MemoryLayout<Float>.size,
                                                   options: .storageModeShared) else {
            print("Failed to create vertex buffer.")
            return nil
        }
        self.vertexBuffer = vertexBuffer
        
        // --- 4. Create the render pipeline state (with shaders) ---
        // First, get a reference to our Metal shader library.
        guard let library = device.makeDefaultLibrary() else {
            print("Could not find the default Metal library.")
            return nil
        }
        
        // Get the vertex and fragment shader functions from the library.
        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            print("Could not find shader functions.")
            return nil
        }
        
        // Create a pipeline descriptor to configure the pipeline state.
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = renderTexture.pixelFormat
        
        // Try to build the pipeline state. This is a heavy operation, so it's done once at init.
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
            return nil
        }
        
        // --- 5. Set up enhanced GPU performance counter sampling ---
        self.performanceMetrics = EnhancedCounterManager(device: device)
    }
    
    // MARK: - Drawing Method

    /// Executes the rendering test and returns performance data
    /// - Parameter showDetailedAnalysis: Whether to display the detailed GPU performance analysis
    /// - Returns: PerformanceResult if measurement was successful, nil if counter sampling is unsupported
    func draw(showDetailedAnalysis: Bool = true) -> PerformanceResult? {
        // --- Create a render pass descriptor for this frame ---
        // This is the same as before, but we do it here since it's needed for each draw call.
        let renderPassDescriptor = MTLRenderPassDescriptor()
        let colorAttachment = renderPassDescriptor.colorAttachments[0]
        colorAttachment?.texture = self.renderTexture
        colorAttachment?.loadAction = .clear
        colorAttachment?.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0) // A dark blue
        colorAttachment?.storeAction = .store
        
        // --- Create a command buffer and encoder ---
        // A command buffer stores a sequence of encoded rendering commands.
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              // A command encoder writes commands into a command buffer.
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        // --- Encode the drawing commands ---
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Sample all available GPU counters at the start of rendering
        performanceMetrics.sampleCountersStart(renderEncoder: renderEncoder)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: testConfig.triangleCount * 3)
        
        // Sample all available GPU counters at the end of rendering
        performanceMetrics.sampleCountersEnd(renderEncoder: renderEncoder)
        
        // We're done encoding, so end it.
        renderEncoder.endEncoding()
        
        // --- Commit the buffer to the GPU for execution ---
        commandBuffer.commit()
        
        // For this command-line tool, we want to wait until the GPU has finished
        // all its work before the program exits.
        commandBuffer.waitUntilCompleted()
        
        // --- Resolve and read enhanced counter data ---
        if performanceMetrics.supportsCounterSampling {
            let (gpuTimeMs, stageUtilization, statistics) = performanceMetrics.resolveAllCounters()
            
            // Display enhanced performance metrics only if requested
            if showDetailedAnalysis {
                print("\n" + String(repeating: "=", count: 50))
                print("GPU PERFORMANCE ANALYSIS")
                print(String(repeating: "=", count: 50))
                print("GPU Time: \(String(format: "%.3f", gpuTimeMs)) ms")
                print("Device: \(device.name)")
                
                // Display stage utilization metrics
                if let stageUtil = stageUtilization {
                    print("\nSTAGE UTILIZATION:")
                    if let vertexUtil = stageUtil.vertexUtilization {
                        print("   Vertex Shader: \(String(format: "%.1f", vertexUtil))%")
                    }
                    if let fragmentUtil = stageUtil.fragmentUtilization {
                        print("   Fragment Shader: \(String(format: "%.1f", fragmentUtil))%")
                    }
                    if let totalUtil = stageUtil.totalUtilization {
                        print("   Total Utilization: \(String(format: "%.1f", totalUtil))%")
                    }
                }
                
                // Display statistics metrics
                if let stats = statistics {
                    print("\nPERFORMANCE STATISTICS:")
                    if let bandwidth = stats.memoryBandwidth {
                        print("   Memory Bandwidth: \(String(format: "%.1f", bandwidth)) MB/s")
                    }
                    if let cacheHits = stats.cacheHits {
                        print("   Cache Hits: \(String(format: "%.0f", cacheHits))")
                    }
                    if let cacheMisses = stats.cacheMisses {
                        print("   Cache Misses: \(String(format: "%.0f", cacheMisses))")
                    }
                    if let hitRate = stats.cacheHitRate {
                        print("   Cache Hit Rate: \(String(format: "%.1f", hitRate * 100))%")
                    }
                    if let instructions = stats.instructionsExecuted {
                        print("   Instructions Executed: \(String(format: "%.0f", instructions))")
                    }
                }
                
                print("\n" + String(repeating: "=", count: 50))
            }
            
            // Create enhanced performance result with all available metrics (for future use)
            let _ = MetalPerformanceResult(
                gpuTimeMs: gpuTimeMs,
                deviceName: device.name,
                testConfig: testConfig,
                stageUtilization: stageUtilization,
                statistics: statistics
            )
            
            // Convert to legacy PerformanceResult for compatibility
            return PerformanceResult(
                gpuTimeMs: gpuTimeMs,
                deviceName: device.name,
                testConfig: testConfig
            )
        } else {
            print("GPU performance measurement not available (counter sampling unsupported)")
            print("This is common on older GPUs. The rendering completed successfully.")
            return nil
        }
    }
    
    // MARK: - Performance Measurement
    
    /// Formats a GPU timestamp for better readability
    /// - Parameter timestamp: Raw GPU timestamp in nanoseconds
    /// - Returns: Formatted string showing both raw and readable format
    private func formatTimestamp(_ timestamp: UInt64) -> String {
        let nanoseconds = timestamp
        let microseconds = Double(nanoseconds) / 1_000.0
        let milliseconds = Double(nanoseconds) / 1_000_000.0
        
        // Show raw timestamp and converted value for context
        if milliseconds >= 1.0 {
            return "\(nanoseconds) ns (\(String(format: "%.3f", milliseconds)) ms)"
        } else if microseconds >= 1.0 {
            return "\(nanoseconds) ns (\(String(format: "%.1f", microseconds)) μs)"
        } else {
            return "\(nanoseconds) ns"
        }
    }
    
}
