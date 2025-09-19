//
//  PerformanceMetrics.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation
import Metal

/// Performance result with multiple counter sets
struct MetalPerformanceResult: Codable {
    /// Basic timing information
    let gpuTimeMs: Double
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Device information for context
    let deviceName: String
    
    /// Test configuration details
    let testConfig: TestConfiguration
    
    /// Stage utilization metrics (if available)
    let stageUtilization: StageUtilizationMetrics?
    
    /// General statistics (if available)
    let statistics: GeneralStatistics?
    
    /// Creates a new enhanced performance result
    init(gpuTimeMs: Double, deviceName: String, testConfig: TestConfiguration, 
         stageUtilization: StageUtilizationMetrics? = nil, statistics: GeneralStatistics? = nil) {
        self.gpuTimeMs = gpuTimeMs
        self.timestamp = Date()
        self.deviceName = deviceName
        self.testConfig = testConfig
        self.stageUtilization = stageUtilization
        self.statistics = statistics
    }
}

/// Stage utilization metrics from GPU performance counters
struct StageUtilizationMetrics: Codable {
    /// Vertex shader utilization percentage
    let vertexUtilization: Double?
    
    /// Fragment shader utilization percentage  
    let fragmentUtilization: Double?
    
    /// Geometry shader utilization percentage
    let geometryUtilization: Double?
    
    /// Compute shader utilization percentage
    let computeUtilization: Double?
    
    /// Memory bandwidth utilization percentage
    let memoryBandwidthUtilization: Double?
}

/// General GPU statistics from performance counters
struct GeneralStatistics: Codable {
    /// Number of vertices processed
    let verticesProcessed: UInt64?
    
    /// Number of primitives processed
    let primitivesProcessed: UInt64?
    
    /// Number of pixels processed
    let pixelsProcessed: UInt64?
    
    /// Memory bandwidth used (bytes)
    let memoryBandwidthUsed: UInt64?
    
    /// Cache hit rate percentage
    let cacheHitRate: Double?
}

/// Manages multiple counter sample buffers for comprehensive performance measurement
class EnhancedCounterManager {
    
    /// Counter sample buffers for different counter sets
    let timestampBuffer: MTLCounterSampleBuffer?
    let stageUtilizationBuffer: MTLCounterSampleBuffer?
    let statisticsBuffer: MTLCounterSampleBuffer?
    
    /// Whether counter sampling is supported
    let supportsCounterSampling: Bool
    
    /// The sampling mode being used
    let samplingMode: MTLCounterSamplingPoint?
    
    /// Initialize with multiple counter sets
    init(device: MTLDevice) {
        // Check counter sampling support
        let supportsAtStageBoundary = device.supportsCounterSampling(.atStageBoundary)
        let supportsAtDrawBoundary = device.supportsCounterSampling(.atDrawBoundary)
        
        self.supportsCounterSampling = supportsAtStageBoundary || supportsAtDrawBoundary
        
        // Determine sampling mode
        if supportsAtStageBoundary {
            self.samplingMode = .atStageBoundary
        } else if supportsAtDrawBoundary {
            self.samplingMode = .atDrawBoundary
        } else {
            self.samplingMode = nil
        }
        
        print("Enhanced Counter Manager Initialization:")
        print("Device: \(device.name)")
        print("Supports counter sampling: \(supportsCounterSampling)")
        if let mode = samplingMode {
            print("Using sampling mode: \(mode)")
        }
        
        // Initialize counter buffers
        if supportsCounterSampling, let counterSets = device.counterSets {
            print("Available counter sets (\(counterSets.count)):")
            for counterSet in counterSets {
                print("     - \(counterSet.name)")
            }
            
            // Create timestamp buffer
            self.timestampBuffer = Self.createCounterBuffer(device: device, counterSets: counterSets, name: "timestamp")
            
            // Create stage utilization buffer
            self.stageUtilizationBuffer = Self.createCounterBuffer(device: device, counterSets: counterSets, name: "stageutilization")
            
            // Create statistics buffer
            self.statisticsBuffer = Self.createCounterBuffer(device: device, counterSets: counterSets, name: "statistic")
            
        } else {
            self.timestampBuffer = nil
            self.stageUtilizationBuffer = nil
            self.statisticsBuffer = nil
        }
    }
    
    /// Creates a counter sample buffer for a specific counter set
    private static func createCounterBuffer(device: MTLDevice, counterSets: [MTLCounterSet], name: String) -> MTLCounterSampleBuffer? {
        // Find the counter set by name
        guard let counterSet = counterSets.first(where: { $0.name.lowercased().contains(name.lowercased()) }) else {
            print("Counter set '\(name)' not found")
            return nil
        }
        
        print("Found counter set: \(counterSet.name)")
        
        // Create counter sample buffer descriptor
        let descriptor = MTLCounterSampleBufferDescriptor()
        descriptor.counterSet = counterSet
        descriptor.sampleCount = 2 // Start and end samples
        descriptor.storageMode = .shared
        
        // Create the counter sample buffer
        do {
            let buffer = try device.makeCounterSampleBuffer(descriptor: descriptor)
            print("Counter sample buffer created for \(counterSet.name)")
            return buffer
        } catch {
            print("Failed to create counter sample buffer for \(counterSet.name): \(error)")
            return nil
        }
    }
    
    /// Samples all available counters at the start of rendering
    func sampleCountersStart(renderEncoder: MTLRenderCommandEncoder) {
        if let buffer = timestampBuffer {
            renderEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 0, barrier: false)
        }
        if let buffer = stageUtilizationBuffer {
            renderEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 0, barrier: false)
        }
        if let buffer = statisticsBuffer {
            renderEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 0, barrier: false)
        }
    }
    
    /// Samples all available counters at the end of rendering
    func sampleCountersEnd(renderEncoder: MTLRenderCommandEncoder) {
        if let buffer = timestampBuffer {
            renderEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 1, barrier: false)
        }
        if let buffer = stageUtilizationBuffer {
            renderEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 1, barrier: false)
        }
        if let buffer = statisticsBuffer {
            renderEncoder.sampleCounters(sampleBuffer: buffer, sampleIndex: 1, barrier: false)
        }
    }
    
    /// Resolves all counter data and returns comprehensive performance metrics
    func resolveAllCounters() -> (gpuTimeMs: Double, stageUtilization: StageUtilizationMetrics?, statistics: GeneralStatistics?) {
        var gpuTimeMs: Double = 0.0
        var stageUtilization: StageUtilizationMetrics? = nil
        var statistics: GeneralStatistics? = nil
        
        // Resolve timestamp data
        if let buffer = timestampBuffer {
            gpuTimeMs = resolveTimestampData(from: buffer)
        }
        
        // Resolve stage utilization data
        if let buffer = stageUtilizationBuffer {
            stageUtilization = resolveStageUtilizationData(from: buffer)
        }
        
        // Resolve statistics data
        if let buffer = statisticsBuffer {
            statistics = resolveStatisticsData(from: buffer)
        }
        
        return (gpuTimeMs, stageUtilization, statistics)
    }
    
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
    
    /// Resolves timestamp counter data
    private func resolveTimestampData(from counterBuffer: MTLCounterSampleBuffer) -> Double {
        do {
            let resolvedData = try counterBuffer.resolveCounterRange(0..<2)
            guard let data = resolvedData else {
                print("No timestamp counter data available")
                return 0.0
            }
            
            let dataPointer = data.withUnsafeBytes { bytes in
                bytes.bindMemory(to: UInt64.self)
            }
            let startTimestamp = dataPointer[0]
            let endTimestamp = dataPointer[1]
            
            let timeDifference = endTimestamp - startTimestamp
            let gpuTimeMs = Double(timeDifference) / 1_000_000.0 // Convert to milliseconds
            
            print("Timestamp Metrics:")
            print("Start: \(formatTimestamp(startTimestamp))")
            print("End: \(formatTimestamp(endTimestamp))")
            print("GPU Time: \(String(format: "%.3f", gpuTimeMs)) ms")
            
            return gpuTimeMs
        } catch {
            print("Failed to resolve timestamp data: \(error)")
            return 0.0
        }
    }
    
    /// Resolves stage utilization counter data
    private func resolveStageUtilizationData(from counterBuffer: MTLCounterSampleBuffer) -> StageUtilizationMetrics? {
        do {
            let resolvedData = try counterBuffer.resolveCounterRange(0..<2)
            guard let data = resolvedData else {
                print("No stage utilization counter data available")
                return nil
            }
            
            // Note: The actual structure of stage utilization data depends on the GPU
            // This is a simplified example - you'd need to check the specific counter set documentation
            let dataPointer = data.withUnsafeBytes { bytes in
                bytes.bindMemory(to: UInt64.self)
            }
            
            print("Stage Utilization Metrics:")
            print("Data available: \(data.count) bytes")
            print("Sample count: \(dataPointer.count)")
            
            // For now, return nil as we'd need GPU-specific documentation to parse this correctly
            return nil
            
        } catch {
            print("Failed to resolve stage utilization data: \(error)")
            return nil
        }
    }
    
    /// Resolves statistics counter data
    private func resolveStatisticsData(from counterBuffer: MTLCounterSampleBuffer) -> GeneralStatistics? {
        do {
            let resolvedData = try counterBuffer.resolveCounterRange(0..<2)
            guard let data = resolvedData else {
                print("No statistics counter data available")
                return nil
            }
            
            // Note: The actual structure of statistics data depends on the GPU
            // This is a simplified example - you'd need to check the specific counter set documentation
            let dataPointer = data.withUnsafeBytes { bytes in
                bytes.bindMemory(to: UInt64.self)
            }
            
            print("General Statistics:")
            print("Data available: \(data.count) bytes")
            print("Sample count: \(dataPointer.count)")
            
            // For now, return nil as we'd need GPU-specific documentation to parse this correctly
            return nil
            
        } catch {
            print("Failed to resolve statistics data: \(error)")
            return nil
        }
    }
}
