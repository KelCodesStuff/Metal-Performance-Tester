//
//  SharedPerformanceMetrics.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Foundation
import Metal

// MARK: - Shared Data Structures

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
    
    /// Memory utilization percentage
    let memoryUtilization: Double?
    
    /// Total GPU utilization percentage
    let totalUtilization: Double?
    
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
    
    /// Memory bandwidth used (MB/s)
    let memoryBandwidth: Double?
    
    /// Memory bandwidth used (bytes)
    let memoryBandwidthUsed: UInt64?
    
    /// Cache hits count
    let cacheHits: Double?
    
    /// Cache misses count
    let cacheMisses: Double?
    
    /// Cache hit rate percentage
    let cacheHitRate: Double?
    
    /// Number of instructions executed
    let instructionsExecuted: Double?
    
    /// Memory latency (nanoseconds)
    let memoryLatency: Double?
    
    /// Texture cache utilization percentage
    let textureCacheUtilization: Double?
}

// MARK: - Base Counter Manager

/// Base class for managing GPU performance counter sampling
class BaseCounterManager {
    
    /// Counter sample buffers for different counter sets
    let timestampBuffer: MTLCounterSampleBuffer?
    let stageUtilizationBuffer: MTLCounterSampleBuffer?
    let statisticsBuffer: MTLCounterSampleBuffer?
    
    /// Whether counter sampling is supported
    let supportsCounterSampling: Bool
    
    /// The sampling mode being used
    let samplingMode: MTLCounterSamplingPoint?
    
    /// Test configuration for workload-aware calculations
    let testConfig: TestConfiguration
    
    /// Initialize with multiple counter sets
    init(device: MTLDevice, testConfig: TestConfiguration) {
        // Store test configuration for workload-aware calculations
        self.testConfig = testConfig
        
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
        
        // Initialize counter buffers
        if supportsCounterSampling, let counterSets = device.counterSets {
            // Available counter sets: timestamp, stageutilization, statistic
            
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
            return nil
        }
        
        // Create counter sample buffer descriptor
        let descriptor = MTLCounterSampleBufferDescriptor()
        descriptor.counterSet = counterSet
        descriptor.sampleCount = 2 // Start and end samples
        descriptor.storageMode = .shared
        
        // Create the counter sample buffer
        do {
            let buffer = try device.makeCounterSampleBuffer(descriptor: descriptor)
            return buffer
        } catch {
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
    
    /// Resolves timestamp counter data
    func resolveTimestampData(from counterBuffer: MTLCounterSampleBuffer) -> Double {
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
            
            return gpuTimeMs
        } catch {
            print("Failed to resolve timestamp data: \(error)")
            return 0.0
        }
    }
}
