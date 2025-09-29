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

    init?(device: MTLDevice, testConfig: TestConfiguration = TestPreset.graphicsModerate.createConfiguration()) {
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
    ///   - iterations: Number of iterations to run (default: 50 for both baseline and tests)
    /// - Returns: UnifiedPerformanceMeasurementSet if measurement was successful, nil if counter sampling is unsupported
    func runMultipleComputeIterations(iterations: Int = 50) -> UnifiedPerformanceMeasurementSet? {
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
            
            // Dispatch compute shaders based on test configuration with performance counter sampling
            try dispatchComputeShadersWithCounters(commandBuffer: commandBuffer, testConfig: testConfig)
            
            // Commit and wait for completion
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // End performance measurement
            let endTime = CFAbsoluteTimeGetCurrent()
            let gpuTimeMs = (endTime - startTime) * 1000.0
            
            // Get compute performance metrics from actual Metal performance counters
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
    
    /// Dispatches compute shaders with performance counter sampling
    private func dispatchComputeShadersWithCounters(commandBuffer: MTLCommandBuffer, testConfig: TestConfiguration) throws {
        // Create compute pipeline state
        let computePipelineState = try createComputePipelineState()
        
        // Create compute encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RendererError.encoderCreationFailed
        }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        
        // Sample performance counters at the start
        if let computeMetrics = computePerformanceMetrics {
            sampleComputeCountersStart(computeEncoder: computeEncoder, metrics: computeMetrics)
        }
        
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
                try dispatchMaxComputeWorkload(encoder: computeEncoder, device: device)
            default:
                try dispatchModerateComputeWorkload(encoder: computeEncoder, device: device)
            }
        } else {
            // Default to moderate compute workload
            try dispatchModerateComputeWorkload(encoder: computeEncoder, device: device)
        }
        
        // Sample performance counters at the end
        if let computeMetrics = computePerformanceMetrics {
            sampleComputeCountersEnd(computeEncoder: computeEncoder, metrics: computeMetrics)
        }
        
        computeEncoder.endEncoding()
    }
    
    /// Samples compute performance counters at the start of execution
    private func sampleComputeCountersStart(computeEncoder: MTLComputeCommandEncoder, metrics: ComputePerformanceMetrics) {
        if let buffer = metrics.timestampBuffer {
            computeEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 0, barrier: false)
        }
        if let buffer = metrics.stageUtilizationBuffer {
            computeEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 0, barrier: false)
        }
        if let buffer = metrics.statisticsBuffer {
            computeEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 0, barrier: false)
        }
    }
    
    /// Samples compute performance counters at the end of execution
    private func sampleComputeCountersEnd(computeEncoder: MTLComputeCommandEncoder, metrics: ComputePerformanceMetrics) {
        if let buffer = metrics.timestampBuffer {
            computeEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 1, barrier: false)
        }
        if let buffer = metrics.stageUtilizationBuffer {
            computeEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 1, barrier: false)
        }
        if let buffer = metrics.statisticsBuffer {
            computeEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 1, barrier: false)
        }
    }
    
    /// Dispatches compute shaders based on test configuration (legacy method for compatibility)
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
                try dispatchMaxComputeWorkload(encoder: computeEncoder, device: device)
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
        let threadgroupCount = MTLSize(width: 8, height: 8, depth: 1) // 128/16 = 8 threadgroups
        let gridWidth = 128
        
        let inputBuffer = try createInputBuffer(device: device, size: gridWidth * gridWidth)
        let outputBuffer = try createOutputBuffer(device: device, size: gridWidth * gridWidth)
        let gridWidthBuffer = try createGridWidthBuffer(device: device, width: gridWidth)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(gridWidthBuffer, offset: 0, index: 2)
        
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches moderate compute workload (256x256)
    private func dispatchModerateComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(width: 16, height: 16, depth: 1) // 256/16 = 16 threadgroups
        let gridWidth = 256
        
        let inputBuffer = try createInputBuffer(device: device, size: gridWidth * gridWidth)
        let outputBuffer = try createOutputBuffer(device: device, size: gridWidth * gridWidth)
        let gridWidthBuffer = try createGridWidthBuffer(device: device, width: gridWidth)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(gridWidthBuffer, offset: 0, index: 2)
        
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches complex compute workload (384x384)
    private func dispatchComplexComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(width: 24, height: 24, depth: 1) // 384/16 = 24 threadgroups
        let gridWidth = 384
        
        let inputBuffer = try createInputBuffer(device: device, size: gridWidth * gridWidth)
        let outputBuffer = try createOutputBuffer(device: device, size: gridWidth * gridWidth)
        let gridWidthBuffer = try createGridWidthBuffer(device: device, width: gridWidth)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(gridWidthBuffer, offset: 0, index: 2)
        
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches high compute workload (512x512)
    private func dispatchHighComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(width: 32, height: 32, depth: 1) // 512/16 = 32 threadgroups
        let gridWidth = 512
        
        let inputBuffer = try createInputBuffer(device: device, size: gridWidth * gridWidth)
        let outputBuffer = try createOutputBuffer(device: device, size: gridWidth * gridWidth)
        let gridWidthBuffer = try createGridWidthBuffer(device: device, width: gridWidth)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(gridWidthBuffer, offset: 0, index: 2)
        
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Dispatches max compute workload (1024x1024)
    private func dispatchMaxComputeWorkload(encoder: MTLComputeCommandEncoder, device: MTLDevice) throws {
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(width: 64, height: 64, depth: 1) // 1024/16 = 64 threadgroups
        let gridWidth = 1024
        
        let inputBuffer = try createInputBuffer(device: device, size: gridWidth * gridWidth)
        let outputBuffer = try createOutputBuffer(device: device, size: gridWidth * gridWidth)
        let gridWidthBuffer = try createGridWidthBuffer(device: device, width: gridWidth)
        
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(gridWidthBuffer, offset: 0, index: 2)
        
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
    }
    
    /// Creates input buffer for compute shaders
    private func createInputBuffer(device: MTLDevice, size: Int) throws -> MTLBuffer {
        let bufferSize = size * MemoryLayout<Float>.size
        guard let buffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared]) else {
            throw RendererError.bufferCreationFailed
        }
        
        // Initialize with deterministic test data for consistent performance measurement
        let pointer = buffer.contents().bindMemory(to: Float.self, capacity: size)
        for i in 0..<size {
            // Use deterministic pattern based on index for consistent performance results
            // This ensures reproducible compute workloads across test runs
            let normalizedIndex = Float(i) / Float(size)
            pointer[i] = sin(normalizedIndex * Float.pi * 4.0) * 0.5 + 0.5
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
    
    /// Creates grid width buffer for compute shaders
    private func createGridWidthBuffer(device: MTLDevice, width: Int) throws -> MTLBuffer {
        let bufferSize = MemoryLayout<UInt32>.size
        guard let buffer = device.makeBuffer(length: bufferSize, options: [.storageModeShared]) else {
            throw RendererError.bufferCreationFailed
        }
        
        // Set the grid width value
        let pointer = buffer.contents().bindMemory(to: UInt32.self, capacity: 1)
        pointer[0] = UInt32(width)
        
        return buffer
    }
    
    /// Gets compute utilization metrics from actual Metal performance counters
    private func getComputeUtilizationMetrics() throws -> ComputeUtilizationMetrics {
        guard let computeMetrics = computePerformanceMetrics,
              computeMetrics.supportsCounterSampling else {
            throw RendererError.deviceNotAvailable
        }
        
        // Get actual performance counter data
        let (_, stageUtilization, statistics) = computeMetrics.resolveAllCounters()
        
        // Extract utilization values from actual counter data
        let computeUtilization = stageUtilization?.computeUtilization ?? 0.0
        let memoryUtilization = stageUtilization?.memoryUtilization ?? 0.0
        let totalUtilization = stageUtilization?.totalUtilization ?? 0.0
        let memoryBandwidthUtilization = stageUtilization?.memoryBandwidthUtilization ?? 0.0
        
        // Calculate threadgroup efficiency based on actual performance data
        let threadgroupEfficiency = calculateThreadgroupEfficiency(from: statistics)
        
        // Calculate instructions per second from actual instruction count
        let instructionsPerSecond = calculateInstructionsPerSecond(from: statistics)
        
        return ComputeUtilizationMetrics(
            computeUtilization: computeUtilization,
            memoryUtilization: memoryUtilization,
            totalUtilization: totalUtilization,
            memoryBandwidthUtilization: memoryBandwidthUtilization,
            threadgroupEfficiency: threadgroupEfficiency,
            instructionsPerSecond: instructionsPerSecond
        )
    }
    
    /// Gets compute performance statistics from actual Metal performance counters
    private func getComputePerformanceStatistics() throws -> GeneralStatistics {
        guard let computeMetrics = computePerformanceMetrics,
              computeMetrics.supportsCounterSampling else {
            throw RendererError.deviceNotAvailable
        }
        
        // Get actual performance counter data
        let (_, _, statistics) = computeMetrics.resolveAllCounters()
        
        // Return actual statistics from Metal performance counters
        return statistics ?? GeneralStatistics(
            verticesProcessed: nil,
            primitivesProcessed: nil,
            pixelsProcessed: nil,
            memoryBandwidth: 0.0,
            memoryBandwidthUsed: nil,
            cacheHits: 0.0,
            cacheMisses: 0.0,
            cacheHitRate: 0.0,
            instructionsExecuted: 0.0,
            memoryLatency: nil,
            textureCacheUtilization: nil
        )
    }
    
    /// Calculates threadgroup efficiency based on actual performance statistics
    private func calculateThreadgroupEfficiency(from statistics: GeneralStatistics?) -> Double {
        guard let stats = statistics else { return 0.0 }
        
        // Calculate efficiency based on cache performance and memory bandwidth utilization
        let cacheHitRate = stats.cacheHitRate ?? 0.0
        let memoryBandwidth = stats.memoryBandwidth ?? 0.0
        
        // Threadgroup efficiency is influenced by:
        // 1. Cache hit rate (higher is better)
        // 2. Memory bandwidth utilization (optimal range is 70-90%)
        // 3. Overall memory performance
        
        // Safe division to prevent NaN values
        let cacheEfficiency = cacheHitRate.isFinite ? cacheHitRate / 100.0 : 0.0 // Convert percentage to 0-1 range
        let bandwidthEfficiency = memoryBandwidth.isFinite ? min(max(memoryBandwidth / 1000000.0, 0.0), 1.0) : 0.0 // Normalize to 0-1 range
        
        // Weighted average with cache performance being more important for threadgroup efficiency
        let efficiency = (cacheEfficiency * 0.7) + (bandwidthEfficiency * 0.3)
        
        // Convert back to percentage and ensure reasonable bounds with NaN protection
        let result = efficiency * 100.0
        let finalResult = min(max(result, 0.0), 100.0)
        
        // Return 0.0 if result is NaN or infinite
        return finalResult.isFinite ? finalResult : 0.0
    }
    
    /// Calculates instructions per second from actual performance statistics
    private func calculateInstructionsPerSecond(from statistics: GeneralStatistics?) -> Double {
        guard let stats = statistics,
              let instructionsExecuted = stats.instructionsExecuted,
              instructionsExecuted > 0,
              instructionsExecuted.isFinite,
              let computeMetrics = computePerformanceMetrics,
              computeMetrics.supportsCounterSampling else { return 0.0 }
        
        // Get the actual GPU time from Metal performance counters
        let (gpuTimeMs, _, _) = computeMetrics.resolveAllCounters()
        
        // Ensure GPU time is valid and finite
        guard gpuTimeMs > 0 && gpuTimeMs.isFinite else { return 0.0 }
        
        let gpuTimeSeconds = max(gpuTimeMs / 1000.0, 0.000001) // Convert to seconds, avoid division by zero
        
        // Calculate instructions per second from actual performance data
        let instructionsPerSecond = instructionsExecuted / gpuTimeSeconds
        
        // Ensure result is finite before proceeding
        guard instructionsPerSecond.isFinite else { return 0.0 }
        
        // Apply workload scaling based on test configuration
        let complexity = Double(testConfig.computeWorkloadComplexity ?? 1)
        let threadgroupCount = Double(testConfig.threadgroupCount?.width ?? 1) * Double(testConfig.threadgroupCount?.height ?? 1)
        
        // Scale based on actual workload complexity and threadgroup count
        let workloadScale = (complexity / 10.0) * (threadgroupCount / (256.0 * 256.0))
        let scaledInstructionsPerSecond = instructionsPerSecond * (1.0 + workloadScale)
        
        // Return 0.0 if result is NaN or infinite
        return scaledInstructionsPerSecond.isFinite ? scaledInstructionsPerSecond : 0.0
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
