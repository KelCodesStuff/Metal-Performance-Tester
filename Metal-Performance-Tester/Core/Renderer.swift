//
//  Renderer.swift
//  Metal-Performance-Tester
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
    /// Graphics performance metrics manager for graphics workloads
    private let graphicsPerformanceMetrics: GraphicsPerformanceMetrics?
    /// Compute performance metrics manager for compute workloads
    private let computePerformanceMetrics: ComputePerformanceMetrics?

    // MARK: - Initialization

    init?(device: MTLDevice, testConfig: TestConfiguration = TestPreset.moderate.createConfiguration()) {
        self.device = device
        self.testConfig = testConfig
        
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
        // For compute-only tests, we don't need vertices
        let vertexBuffer: MTLBuffer
        if testConfig.testType == .compute {
            // Create a minimal vertex buffer for compute tests
            let dummyVertices: [Float] = [0.0, 0.0, 0.0] // Single vertex
            guard let buffer = device.makeBuffer(bytes: dummyVertices,
                                               length: dummyVertices.count * MemoryLayout<Float>.size,
                                               options: .storageModeShared) else {
                print("Failed to create dummy vertex buffer for compute test.")
                return nil
            }
            vertexBuffer = buffer
        } else {
            // Generate vertices based on test configuration for graphics tests
            let vertices = TestConfigurationHelper.generateTriangleVertices(
                count: testConfig.triangleCount, 
                complexity: testConfig.geometryComplexity
            )
            
            // Create a Metal buffer and copy our vertex data into it.
            guard let buffer = device.makeBuffer(bytes: vertices,
                                               length: vertices.count * MemoryLayout<Float>.size,
                                               options: .storageModeShared) else {
                print("Failed to create vertex buffer.")
                return nil
            }
            vertexBuffer = buffer
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
        
        // --- 5. Set up GPU performance counter sampling based on test type ---
        switch testConfig.testType {
        case .graphics:
            self.graphicsPerformanceMetrics = GraphicsPerformanceMetrics(device: device, testConfig: testConfig)
            self.computePerformanceMetrics = nil
        case .compute:
            self.graphicsPerformanceMetrics = nil
            self.computePerformanceMetrics = ComputePerformanceMetrics(device: device, testConfig: testConfig)
        case .both:
            self.graphicsPerformanceMetrics = GraphicsPerformanceMetrics(device: device, testConfig: testConfig)
            self.computePerformanceMetrics = ComputePerformanceMetrics(device: device, testConfig: testConfig)
        }
    }
    
    // MARK: - Drawing Method

    /// Runs multiple graphics iterations and returns a graphics measurement set
    /// - Parameters:
    ///   - iterations: Number of iterations to run (default: 100 for both baseline and tests)
    /// - Returns: GraphicsMeasurementSet if measurement was successful, nil if counter sampling is unsupported
    func runMultipleGraphicsIterations(iterations: Int = 100) -> GraphicsMeasurementSet? {
        guard let graphicsMetrics = graphicsPerformanceMetrics,
              graphicsMetrics.supportsCounterSampling else {
            return nil
        }
        
        var results: [PerformanceResult] = []
        
        for _ in 0..<iterations {
            if let result = draw() {
                results.append(result)
            } else {
                return nil
            }
        }
        
        // Convert PerformanceResult to GraphicsResult
        let graphicsResults = results.map { performanceResult in
            GraphicsResult(
                gpuTimeMs: performanceResult.gpuTimeMs,
                deviceName: performanceResult.deviceName,
                testConfig: performanceResult.testConfig,
                stageUtilization: performanceResult.stageUtilization,
                statistics: performanceResult.statistics
            )
        }
        
        let measurementSet = GraphicsMeasurementSet(individualResults: graphicsResults)
        return measurementSet
    }
    
    /// Runs multiple compute iterations and returns a compute performance measurement set
    /// - Parameters:
    ///   - iterations: Number of iterations to run (default: 100 for both baseline and tests)
    /// - Returns: ComputeMeasurementSet if measurement was successful, nil if counter sampling is unsupported
    func runMultipleComputeIterations(iterations: Int = 100) -> ComputeMeasurementSet? {
        guard let computeMetrics = computePerformanceMetrics,
              computeMetrics.supportsCounterSampling else {
            return nil
        }
        
        var results: [ComputeResult] = []
        
        for _ in 0..<iterations {
            if let result = runCompute() {
                results.append(result)
            } else {
                return nil
            }
        }
        
        let measurementSet = ComputeMeasurementSet(individualResults: results)
        return measurementSet
    }
    
    /// Executes the compute test and returns compute performance data
    /// - Returns: ComputeResult if measurement was successful, nil if counter sampling is unsupported
    func runCompute() -> ComputeResult? {
        // For now, we'll simulate compute performance by using the existing graphics pipeline
        // In a real implementation, this would dispatch compute shaders
        guard let graphicsResult = draw() else {
            return nil
        }
        
        // Convert graphics result to compute result
        // In a real implementation, this would be actual compute performance data
        let computeUtilization = ComputeUtilizationMetrics(
            computeUtilization: graphicsResult.stageUtilization?.fragmentUtilization,
            memoryUtilization: graphicsResult.stageUtilization?.memoryUtilization,
            totalUtilization: graphicsResult.stageUtilization?.totalUtilization,
            memoryBandwidthUtilization: graphicsResult.stageUtilization?.memoryBandwidthUtilization,
            threadgroupEfficiency: 85.0, // Simulated threadgroup efficiency
            instructionsPerSecond: graphicsResult.statistics?.instructionsExecuted
        )
        
        return ComputeResult(
            gpuTimeMs: graphicsResult.gpuTimeMs,
            deviceName: graphicsResult.deviceName,
            testConfig: graphicsResult.testConfig,
            computeUtilization: computeUtilization,
            statistics: graphicsResult.statistics
        )
    }

    /// Executes the rendering test and returns performance data
    /// - Returns: PerformanceResult if measurement was successful, nil if counter sampling is unsupported
    func draw() -> PerformanceResult? {
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
        if let graphicsMetrics = graphicsPerformanceMetrics {
            graphicsMetrics.sampleCountersStart(renderEncoder: renderEncoder)
        }
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: testConfig.triangleCount * 3)
        
        // Sample all available GPU counters at the end of rendering
        if let graphicsMetrics = graphicsPerformanceMetrics {
            graphicsMetrics.sampleCountersEnd(renderEncoder: renderEncoder)
        }
        
        // We're done encoding, so end it.
        renderEncoder.endEncoding()
        
        // --- Commit the buffer to the GPU for execution ---
        commandBuffer.commit()
        
        // For this command-line tool, we want to wait until the GPU has finished
        // all its work before the program exits.
        commandBuffer.waitUntilCompleted()
        
        // --- Resolve and read enhanced counter data ---
        if let graphicsMetrics = graphicsPerformanceMetrics,
           graphicsMetrics.supportsCounterSampling {
            let (gpuTimeMs, stageUtilization, statistics) = graphicsMetrics.resolveAllCounters()
            
            // Return PerformanceResult with all available metrics
            return PerformanceResult(
                gpuTimeMs: gpuTimeMs,
                deviceName: device.name,
                testConfig: testConfig,
                stageUtilization: stageUtilization,
                statistics: statistics
            )
        } else {
            return nil
        }
    }
}
