//
//  Renderer.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/17/25.
//

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

    init?(device: MTLDevice, testConfig: TestConfiguration = TestPreset.moderate.createConfiguration(), showConfiguration: Bool = true) {
        self.device = device
        self.testConfig = testConfig
        
        // Print test configuration if requested
        if showConfiguration {
            print("\nTest Configuration: \(testConfig.description)")
            print("Parameters:")
            print(testConfig.parametersDescription)
        }
        
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
        self.performanceMetrics = EnhancedCounterManager(device: device, testConfig: testConfig)
    }
    
    // MARK: - Drawing Method

    /// Runs multiple iterations and returns a performance measurement set
    /// - Parameters:
    ///   - iterations: Number of iterations to run (default: 50 for baseline, 100 for tests)
    ///   - showProgress: Whether to show progress during iterations
    ///   - showDetailedResults: Whether to display the full baseline results output
    /// - Returns: PerformanceMeasurementSet if measurement was successful, nil if counter sampling is unsupported
    func runMultipleIterations(iterations: Int = 50, showProgress: Bool = true, showDetailedResults: Bool = true) -> PerformanceMeasurementSet? {
        guard performanceMetrics.supportsCounterSampling else {
            print("GPU performance measurement not available (counter sampling unsupported)")
            return nil
        }
        
        var results: [PerformanceResult] = []
        
        if showProgress {
            print("\nRunning \(iterations) iterations for statistical analysis...")
        }
        
        for i in 0..<iterations {
            if let result = draw(showDetailedAnalysis: false) {
                results.append(result)
                
                // Only show progress at completion
                if showProgress && i == iterations - 1 {
                    let progress = ((i + 1) * 100) / iterations
                    print("Progress: \(progress)% (\(i + 1)/\(iterations))")
                }
            } else {
                print("Failed to get performance result for iteration \(i + 1)")
                return nil
            }
        }
        
        let measurementSet = PerformanceMeasurementSet(individualResults: results)
        
        if showDetailedResults {
            print("\n" + String(repeating: "=", count: 60))
            print("PERFORMANCE BASELINE COMPLETE")
            print(String(repeating: "=", count: 60))
            print(measurementSet.summary)
            
            // Display performance impact based on average results
            let performanceImpact = TestConfigurationHelper.calculatePerformanceImpactFromResults(
                gpuTimeMs: measurementSet.averageGpuTimeMs,
                totalUtilization: measurementSet.individualResults.last?.stageUtilization?.totalUtilization,
                memoryBandwidth: measurementSet.individualResults.last?.statistics?.memoryBandwidth,
                instructionsExecuted: measurementSet.individualResults.last?.statistics?.instructionsExecuted
            )
            print("\nPerformance Impact: \(performanceImpact)")
            
            print("\n" + String(repeating: "=", count: 60))
        }
        
        return measurementSet
    }

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
                    print("\nStage Utilization:")
                    if let vertexUtil = stageUtil.vertexUtilization {
                        print("  Vertex Shader: \(String(format: "%.1f", vertexUtil))%")
                    }
                    if let fragmentUtil = stageUtil.fragmentUtilization {
                        print("  Fragment Shader: \(String(format: "%.1f", fragmentUtil))%")
                    }
                    if let totalUtil = stageUtil.totalUtilization {
                        print("  Total Utilization: \(String(format: "%.1f", totalUtil))%")
                    }
                }
                
                // Display statistics metrics
                if let stats = statistics {
                    print("\nPerformance Statistics:")
                    if let bandwidth = stats.memoryBandwidth {
                        print("  Memory Bandwidth: \(String(format: "%.1f", bandwidth)) MB/s")
                    }
                    if let cacheHits = stats.cacheHits {
                        print("  Cache Hits: \(String(format: "%.0f", cacheHits))")
                    }
                    if let cacheMisses = stats.cacheMisses {
                        print("  Cache Misses: \(String(format: "%.0f", cacheMisses))")
                    }
                    if let hitRate = stats.cacheHitRate {
                        print("  Cache Hit Rate: \(String(format: "%.1f", hitRate * 100))%")
                    }
                    if let instructions = stats.instructionsExecuted {
                        print("  Instructions Executed: \(String(format: "%.0f", instructions))")
                    }
                }
                
                // Calculate and display performance impact based on actual results
                let performanceImpact = TestConfigurationHelper.calculatePerformanceImpactFromResults(
                    gpuTimeMs: gpuTimeMs,
                    totalUtilization: stageUtilization?.totalUtilization,
                    memoryBandwidth: statistics?.memoryBandwidth,
                    instructionsExecuted: statistics?.instructionsExecuted
                )
                print("\nPerformance Impact: \(performanceImpact)")
                
                print("\n" + String(repeating: "=", count: 50))
            }
            
            // Return PerformanceResult with all available metrics
            return PerformanceResult(
                gpuTimeMs: gpuTimeMs,
                deviceName: device.name,
                testConfig: testConfig,
                stageUtilization: stageUtilization,
                statistics: statistics
            )
        } else {
            print("GPU performance measurement not available (counter sampling unsupported)")
            print("This is common on older GPUs. The rendering completed successfully.")
            return nil
        }
    }
}
