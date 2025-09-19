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
    /// MTLCounterSampleBuffer: A buffer that captures GPU performance counters during rendering.
    /// This allows us to measure precise GPU execution times by sampling timestamp counters
    /// at specific points in the rendering pipeline. The buffer stores raw counter data that
    /// must be resolved after GPU execution completes to extract meaningful performance metrics.
    let counterSampleBuffer: MTLCounterSampleBuffer?
    let supportsCounterSampling: Bool
    let counterSamplingMode: MTLCounterSamplingPoint?

    // MARK: - Initialization

    init?(device: MTLDevice, testConfig: TestConfiguration = TestPreset.simple.createConfiguration()) {
        self.device = device
        self.testConfig = testConfig
        
        // Print test configuration
        print("Test Configuration: \(testConfig.description)")
        print("Parameters: \(testConfig.parametersDescription)")
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
        
        // --- 5. Check for counter sampling support ---
        // Query the device to see if it supports performance counter sampling
        // Try different sampling modes to find one that works
        let supportsAtStageBoundary = device.supportsCounterSampling(.atStageBoundary)
        let supportsAtDrawBoundary = device.supportsCounterSampling(.atDrawBoundary)
        
        print("Supports counter sampling at stage boundary: \(supportsAtStageBoundary)")
        print("Supports counter sampling at draw boundary: \(supportsAtDrawBoundary)")
        
        self.supportsCounterSampling = supportsAtStageBoundary || supportsAtDrawBoundary
        
        // Determine which sampling mode to use
        if supportsAtStageBoundary {
            self.counterSamplingMode = .atStageBoundary
        } else if supportsAtDrawBoundary {
            self.counterSamplingMode = .atDrawBoundary
        } else {
            self.counterSamplingMode = nil
        }
        
        print("\nChecking counter sampling support...")
        print("Device: \(device.name)")
        print("Supports counter sampling: \(supportsCounterSampling)")
        if let mode = counterSamplingMode {
            print("Using sampling mode: \(mode)")
        }
        
        if let counterSets = device.counterSets {
            print("\nAvailable counter sets (\(counterSets.count)):")
            for counterSet in counterSets {
                print("     - \(counterSet.name)")
            }
        } else {
            print("No counter sets available")
        }
        
        if supportsCounterSampling {
            print("\nDevice supports counter sampling")
            
            // Find the timestamp counter set
            var timestampCounterSet: MTLCounterSet? = nil
            if let counterSets = device.counterSets {
                for counterSet in counterSets {
                    print("\nChecking counter set: \(counterSet.name)...")
                    if counterSet.name.lowercased().contains("timestamp") {
                        timestampCounterSet = counterSet
                        break
                    }
                }
            }
            
            if let counterSet = timestampCounterSet {
                print("Found timestamp counter set: \(counterSet.name)")
                
                // Create counter sample buffer descriptor
                let counterSampleBufferDescriptor = MTLCounterSampleBufferDescriptor()
                counterSampleBufferDescriptor.counterSet = counterSet
                counterSampleBufferDescriptor.sampleCount = 2 // Start and end timestamps
                counterSampleBufferDescriptor.storageMode = .shared
                
                // Create the counter sample buffer
                do {
                    self.counterSampleBuffer = try device.makeCounterSampleBuffer(descriptor: counterSampleBufferDescriptor)
                } catch {
                    print("Failed to create counter sample buffer: \(error)")
                    self.counterSampleBuffer = nil
                }
                if counterSampleBuffer != nil {
                    print("Counter sample buffer created successfully")
                }
            } else {
                print("No timestamp counter set found")
                self.counterSampleBuffer = nil
            }
        } else {
            print("Device does not support counter sampling")
            self.counterSampleBuffer = nil
        }
    }
    
    // MARK: - Drawing Method

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
        
        // Sample GPU timestamp at the start of rendering
        if let counterBuffer = counterSampleBuffer, let _ = counterSamplingMode {
            renderEncoder.sampleCounters(sampleBuffer: counterBuffer, sampleIndex: 0, barrier: false)
        }
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: testConfig.triangleCount * 3)
        
        // Sample GPU timestamp at the end of rendering
        if let counterBuffer = counterSampleBuffer, let _ = counterSamplingMode {
            renderEncoder.sampleCounters(sampleBuffer: counterBuffer, sampleIndex: 1, barrier: false)
        }
        
        // We're done encoding, so end it.
        renderEncoder.endEncoding()
        
        // --- Commit the buffer to the GPU for execution ---
        commandBuffer.commit()
        
        // For this command-line tool, we want to wait until the GPU has finished
        // all its work before the program exits.
        commandBuffer.waitUntilCompleted()
        
        print("GPU has finished rendering the frame")
        
        // --- Resolve and read counter data ---
        if let counterBuffer = counterSampleBuffer {
            print("\nAttempting to resolve GPU performance counters...")
            let gpuTimeMs = resolveCounterData(from: counterBuffer)
            
            // Use the existing test configuration
            
            // Return performance result
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
    
    /// Resolves counter data from the sample buffer and calculates GPU execution time
    /// - Parameter counterBuffer: The counter sample buffer containing timestamp data
    /// - Returns: GPU execution time in milliseconds
    private func resolveCounterData(from counterBuffer: MTLCounterSampleBuffer) -> Double {
        do {
            // Resolve the counter data from the sample buffer
            // This converts raw GPU counter data into a readable format
            let resolvedData = try counterBuffer.resolveCounterRange(0..<2)
            
            // Extract the raw data as bytes
            guard let data = resolvedData else {
                print("No counter data available")
                return 0.0
            }
            
            let dataPointer = data.withUnsafeBytes { bytes in
                bytes.bindMemory(to: UInt64.self)
            }
            let startTimestamp = dataPointer[0]
            let endTimestamp = dataPointer[1]
            
            // Calculate the time difference
            // GPU timestamps are typically in nanoseconds
            let timeDifference = endTimestamp - startTimestamp
            let gpuTimeMs = Double(timeDifference) / 1_000_000.0 // Convert to milliseconds
            
            print("GPU Performance Metrics:")
            print("Start timestamp: \(formatTimestamp(startTimestamp))")
            print("End timestamp: \(formatTimestamp(endTimestamp))")
            print("GPU execution time: \(String(format: "%.3f", gpuTimeMs)) ms")
            
            return gpuTimeMs
        } catch {
            print("Failed to resolve counter data: \(error)")
            return 0.0
        }
    }
}
