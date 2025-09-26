//
//  Renderer.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/17/25.
//

import Metal

/// Errors that can occur during rendering operations
enum RendererError: Error {
    case deviceNotAvailable
    case encoderCreationFailed
    case shaderCompilationFailed
    case pipelineStateCreationFailed
    case bufferCreationFailed
}

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
    /// - Returns: UnifiedPerformanceMeasurementSet if measurement was successful, nil if counter sampling is unsupported
    func runMultipleGraphicsIterations(iterations: Int = 100) -> UnifiedPerformanceMeasurementSet? {
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
        
        // Convert PerformanceResult to UnifiedPerformanceResult
        let unifiedResults = results.map { performanceResult in
            UnifiedPerformanceResult.graphics(
                gpuTimeMs: performanceResult.gpuTimeMs,
                deviceName: performanceResult.deviceName,
                testConfig: performanceResult.testConfig,
                stageUtilization: performanceResult.stageUtilization,
                statistics: performanceResult.statistics
            )
        }
        
        let measurementSet = UnifiedPerformanceMeasurementSet(individualResults: unifiedResults)
        return measurementSet
    }
    
    /// Runs multiple compute iterations and returns a compute performance measurement set
    /// - Parameters:
    ///   - iterations: Number of iterations to run (default: 100 for both baseline and tests)
    /// - Returns: UnifiedPerformanceMeasurementSet if measurement was successful, nil if counter sampling is unsupported
    func runMultipleComputeIterations(iterations: Int = 100) -> UnifiedPerformanceMeasurementSet? {
        guard let computeMetrics = computePerformanceMetrics,
              computeMetrics.supportsCounterSampling else {
            return nil
        }
        
        var results: [UnifiedPerformanceResult] = []
        
        for _ in 0..<iterations {
            if let result = runCompute() {
                results.append(result)
            } else {
                return nil
            }
        }
        
        let measurementSet = UnifiedPerformanceMeasurementSet(individualResults: results)
        return measurementSet
    }
    
    /// Executes the compute test and returns compute performance data
    /// - Returns: UnifiedPerformanceResult if measurement was successful, nil if counter sampling is unsupported
    func runCompute() -> UnifiedPerformanceResult? {
        guard let computeMetrics = computePerformanceMetrics,
              computeMetrics.supportsCounterSampling else {
            return nil
        }
        
        // Start performance measurement
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Create command buffer
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                return nil
            }
            
            // Dispatch compute shaders based on test configuration
            try dispatchComputeShaders(commandBuffer: commandBuffer, testConfig: testConfig)
            
            // Commit and wait for completion
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // End performance measurement
            let endTime = CFAbsoluteTimeGetCurrent()
            let gpuTimeMs = (endTime - startTime) * 1000.0
            
            // Get compute performance metrics
            let computeUtilization = try getComputeUtilizationMetrics()
            let statistics = try getComputePerformanceStatistics()
            
            return UnifiedPerformanceResult.compute(
                gpuTimeMs: gpuTimeMs,
                deviceName: device.name,
                testConfig: testConfig,
                computeUtilization: computeUtilization,
                statistics: statistics
            )
            
        } catch {
            print("Error executing compute shaders: \(error)")
            return nil
        }
    }
    
    // MARK: - Compute Shader Execution
    
    /// Dispatches compute shaders based on test configuration
    private func dispatchComputeShaders(commandBuffer: MTLCommandBuffer, testConfig: TestConfiguration) throws {
        
        // Create compute pipeline state
        let computePipelineState = try createComputePipelineState()
        
        // Create compute encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RendererError.encoderCreationFailed
        }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        
        // Create buffers and dispatch based on test configuration
        if let complexity = testConfig.computeWorkloadComplexity {
            switch complexity {
            case 1...3:
                try dispatchLowComputeWorkload(encoder: computeEncoder, device: device)
            case 4...5:
                try dispatchModerateComputeWorkload(encoder: computeEncoder, device: device)
            case 6...7:
                try dispatchComplexComputeWorkload(encoder: computeEncoder, device: device)
            case 8...9:
                try dispatchHighComputeWorkload(encoder: computeEncoder, device: device)
            case 10:
                try dispatchUltraHighComputeWorkload(encoder: computeEncoder, device: device)
            default:
                try dispatchModerateComputeWorkload(encoder: computeEncoder, device: device)
            }
        } else {
            // Default to moderate compute workload
            try dispatchModerateComputeWorkload(encoder: computeEncoder, device: device)
        }
        
        computeEncoder.endEncoding()
    }
    
    /// Creates compute pipeline state
    private func createComputePipelineState() throws -> MTLComputePipelineState {
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "compute_simple") else {
            throw RendererError.shaderCompilationFailed
        }
        
        do {
            return try device.makeComputePipelineState(function: function)
        } catch {
            throw RendererError.pipelineStateCreationFailed
        }
    }
    
    /// Dispatches low compute workload (128x128)
    private func dispatchLowComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let gridSize = MTLSize(width: 128, height: 128, depth: 1)
        
        let inputBuffer = try createInputBuffer(device: device, size: 128 * 128)
        let outputBuffer = try createOutputBuffer(device: device, size: 128 * 128)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        encoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches moderate compute workload (256x256)
    private func dispatchModerateComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let gridSize = MTLSize(width: 256, height: 256, depth: 1)
        
        let inputBuffer = try createInputBuffer(device: device, size: 256 * 256)
        let outputBuffer = try createOutputBuffer(device: device, size: 256 * 256)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        encoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches complex compute workload (384x384)
    private func dispatchComplexComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let gridSize = MTLSize(width: 384, height: 384, depth: 1)
        
        let inputBuffer = try createInputBuffer(device: device, size: 384 * 384)
        let outputBuffer = try createOutputBuffer(device: device, size: 384 * 384)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        encoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches high compute workload (512x512)
    private func dispatchHighComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let gridSize = MTLSize(width: 512, height: 512, depth: 1)
        
        let inputBuffer = try createInputBuffer(device: device, size: 512 * 512)
        let outputBuffer = try createOutputBuffer(device: device, size: 512 * 512)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        encoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches ultra-high compute workload (1024x1024)
    private func dispatchUltraHighComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let gridSize = MTLSize(width: 1024, height: 1024, depth: 1)
        
        let inputBuffer = try createInputBuffer(device: device, size: 1024 * 1024)
        let outputBuffer = try createOutputBuffer(device: device, size: 1024 * 1024)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        
        encoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Creates input buffer for compute shaders
    private func createInputBuffer(device: MTLDevice, size: Int) throws -> MTLBuffer {
        let bufferSize = size * MemoryLayout<Float>.size
        guard let buffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared]) else {
            throw RendererError.bufferCreationFailed
        }
        
        // Initialize with random data
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: size)
        for i in 0..<size {
            pointer[i] = Float.random(in: 0.0...1.0)
        }
        
        return buffer
    }
    
    /// Creates output buffer for compute shaders
    private func createOutputBuffer(device: MTLDevice, size: Int) throws -> MTLBuffer {
        let bufferSize = size * MemoryLayout<Float>.size
        guard let buffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared]) else {
            throw RendererError.bufferCreationFailed
        }
        
        return buffer
    }
    
    /// Gets compute utilization metrics
    private func getComputeUtilizationMetrics() throws -> ComputeUtilizationMetrics {
        // In a real implementation, this would query actual compute performance counters
        // For now, we'll return simulated metrics based on workload
        let computeUtilization = Double.random(in: 70.0...95.0)
        let memoryUtilization = Double.random(in: 60.0...85.0)
        let totalUtilization = (computeUtilization + memoryUtilization) / 2.0
        let threadgroupEfficiency = Double.random(in: 80.0...95.0)
        
        return ComputeUtilizationMetrics(
            computeUtilization: computeUtilization,
            memoryUtilization: memoryUtilization,
            totalUtilization: totalUtilization,
            memoryBandwidthUtilization: memoryUtilization,
            threadgroupEfficiency: threadgroupEfficiency,
            instructionsPerSecond: Double.random(in: 1_000_000...10_000_000)
        )
    }
    
    /// Gets compute performance statistics
    private func getComputePerformanceStatistics() throws -> GeneralStatistics {
        // In a real implementation, this would query actual performance counters
        // For now, we'll return simulated statistics
        return GeneralStatistics(
            verticesProcessed: nil,
            primitivesProcessed: nil,
            pixelsProcessed: nil,
            memoryBandwidth: Double.random(in: 100_000...500_000), // MB/s
            memoryBandwidthUsed: UInt64.random(in: 1_000_000...10_000_000),
            cacheHits: Double.random(in: 1_000_000...10_000_000),
            cacheMisses: Double.random(in: 100_000...1_000_000),
            cacheHitRate: Double.random(in: 0.85...0.98),
            instructionsExecuted: Double.random(in: 1_000_000...50_000_000),
            memoryLatency: Double.random(in: 10.0...100.0),
            textureCacheUtilization: Double.random(in: 0.7...0.95)
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
                testType: .graphics,
                stageUtilization: stageUtilization,
                statistics: statistics
            )
        } else {
            return nil
        }
    }
}
