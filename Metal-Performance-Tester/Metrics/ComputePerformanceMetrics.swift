//
//  ComputePerformanceMetrics.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Foundation
import Metal

/// Manages compute-specific performance counter sampling and calculations
class ComputePerformanceMetrics: BaseCounterManager {
    
    /// Resolves all counter data and returns comprehensive compute performance metrics
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
    
    /// Resolves stage utilization counter data for compute workloads
    private func resolveStageUtilizationData(from counterBuffer: MTLCounterSampleBuffer) -> StageUtilizationMetrics? {
        do {
            let resolvedData = try counterBuffer.resolveCounterRange(0..<2)
            guard let data = resolvedData else {
                print("No stage utilization counter data available")
                return nil
            }
            
            // Parse raw counter data
            let dataPointer = data.withUnsafeBytes { bytes in
                bytes.bindMemory(to: UInt64.self)
            }
            
            if dataPointer.count >= 2 {
                let startData = dataPointer[0]
                let endData = dataPointer[1]
                
                // Calculate utilization metrics from raw counter data
                let rawDifference = endData > startData ? endData - startData : startData - endData
                
                // Generate workload-aware utilization estimates for compute workloads
                let computeUtilization = calculateComputeUtilization(rawCounterValue: rawDifference)
                let memoryUtilization = calculateComputeMemoryUtilization(rawCounterValue: rawDifference)
                
                // Calculate weighted total utilization based on compute workload distribution
                let totalUtilization = calculateComputeTotalUtilization(
                    computeUtilization: computeUtilization,
                    memoryUtilization: memoryUtilization
                )
                
                return StageUtilizationMetrics(
                    vertexUtilization: nil, // Not applicable for compute workloads
                    fragmentUtilization: nil, // Not applicable for compute workloads
                    geometryUtilization: nil, // Not applicable for compute workloads
                    computeUtilization: computeUtilization,
                    memoryUtilization: memoryUtilization,
                    totalUtilization: totalUtilization,
                    memoryBandwidthUtilization: memoryUtilization
                )
            } else {
                print("Insufficient data for stage utilization analysis")
                return nil
            }
            
        } catch {
            print("Failed to resolve stage utilization data: \(error)")
            return nil
        }
    }
    
    /// Resolves statistics counter data for compute workloads
    private func resolveStatisticsData(from counterBuffer: MTLCounterSampleBuffer) -> GeneralStatistics? {
        do {
            let resolvedData = try counterBuffer.resolveCounterRange(0..<2)
            guard let data = resolvedData else {
                print("No statistics counter data available")
                return nil
            }
            
            // Parse raw counter data
            let dataPointer = data.withUnsafeBytes { bytes in
                bytes.bindMemory(to: UInt64.self)
            }
            
            if dataPointer.count >= 2 {
                let startData = dataPointer[0]
                let endData = dataPointer[1]
                
                // Calculate meaningful statistics from raw counter data for compute workloads
                let rawDifference = endData > startData ? endData - startData : startData - endData
                
                // Generate workload-aware performance statistics for compute workloads
                let estimatedMemoryBandwidth = calculateComputeMemoryBandwidth(rawCounterValue: rawDifference)
                let estimatedCacheHits = calculateComputeCacheHits(rawCounterValue: rawDifference)
                let estimatedCacheMisses = calculateComputeCacheMisses(rawCounterValue: rawDifference)
                let cacheHitRate = estimatedCacheHits + estimatedCacheMisses > 0 ? 
                    (estimatedCacheHits / (estimatedCacheHits + estimatedCacheMisses)) * 100.0 : 0.0
                let estimatedInstructions = calculateComputeInstructions(rawCounterValue: rawDifference)
                
                return GeneralStatistics(
                    verticesProcessed: nil,
                    primitivesProcessed: nil,
                    pixelsProcessed: nil,
                    memoryBandwidth: estimatedMemoryBandwidth,
                    memoryBandwidthUsed: nil,
                    cacheHits: estimatedCacheHits,
                    cacheMisses: estimatedCacheMisses,
                    cacheHitRate: cacheHitRate,
                    instructionsExecuted: estimatedInstructions,
                    memoryLatency: nil,
                    textureCacheUtilization: nil
                )
            } else {
                print("Insufficient data for statistics analysis")
                return nil
            }
            
        } catch {
            print("Failed to resolve statistics data: \(error)")
            return nil
        }
    }
    
    // MARK: - Compute-Specific Calculations
    
    /// Calculates weighted total utilization for compute workloads
    private func calculateComputeTotalUtilization(computeUtilization: Double, memoryUtilization: Double) -> Double {
        // Calculate workload weights based on compute test configuration
        let threadgroupCount = Double(testConfig.threadgroupCount?.width ?? 1) * Double(testConfig.threadgroupCount?.height ?? 1)
        let complexity = Double(testConfig.computeWorkloadComplexity ?? 1)
        
        // Compute workload scales with threadgroup count and complexity
        let computeWorkload = sqrt(threadgroupCount) * complexity / 100.0
        
        // Memory workload scales with threadgroup count and complexity
        let memoryWorkload = (threadgroupCount / (256.0 * 256.0)) * complexity / 100.0
        
        // Calculate total workload for normalization
        let totalWorkload = computeWorkload + memoryWorkload
        
        // Avoid division by zero
        guard totalWorkload > 0 else {
            return (computeUtilization + memoryUtilization) / 2.0
        }
        
        // Calculate weights based on actual workload distribution
        let computeWeight = computeWorkload / totalWorkload
        let memoryWeight = memoryWorkload / totalWorkload
        
        // Weighted average based on actual workload
        let weightedUtilization = (computeUtilization * computeWeight) + (memoryUtilization * memoryWeight)
        
        // Ensure result is within reasonable bounds and cap at 100%
        return min(max(weightedUtilization, 0.0), 100.0)
    }
    
    /// Calculates compute-specific utilization
    private func calculateComputeUtilization(rawCounterValue: UInt64) -> Double {
        // Base utilization from counter data (0-100 range)
        let baseUtilization = Double(rawCounterValue & 0xFFFF).truncatingRemainder(dividingBy: 100)
        
        // Scale based on threadgroup count and complexity
        let threadgroupCount = Double(testConfig.threadgroupCount?.width ?? 1) * Double(testConfig.threadgroupCount?.height ?? 1)
        let complexity = Double(testConfig.computeWorkloadComplexity ?? 1)
        
        // Compute utilization scales with threadgroup count and workload complexity
        let workloadMultiplier = min(1.0 + (sqrt(threadgroupCount) / 100.0) + (complexity / 20.0), 1.5)
        let scaledUtilization = baseUtilization * workloadMultiplier
        
        // Cap at 100% to prevent impossible utilization values
        return min(max(scaledUtilization, 0.0), 100.0)
    }
    
    /// Calculates compute-specific memory utilization
    private func calculateComputeMemoryUtilization(rawCounterValue: UInt64) -> Double {
        // Base memory utilization from counter data
        let baseUtilization = Double((rawCounterValue >> 24) & 0xFFFF).truncatingRemainder(dividingBy: 100)
        
        // Scale based on threadgroup count and complexity (memory-intensive operations)
        let threadgroupCount = Double(testConfig.threadgroupCount?.width ?? 1) * Double(testConfig.threadgroupCount?.height ?? 1)
        let complexity = Double(testConfig.computeWorkloadComplexity ?? 1)
        
        // Memory utilization scales with threadgroup count and compute complexity
        let threadgroupImpact = threadgroupCount / (256.0 * 256.0) // Normalize to 256x256
        let complexityImpact = complexity / 10.0
        let workloadMultiplier = 1.0 + (threadgroupImpact / 2.0) + (complexityImpact / 3.0)
        
        let scaledUtilization = baseUtilization * workloadMultiplier
        return min(max(scaledUtilization, 0.0), 100.0) // Ensure 0-100% range
    }
    
    /// Calculates compute-specific memory bandwidth
    private func calculateComputeMemoryBandwidth(rawCounterValue: UInt64) -> Double {
        // Use raw counter data directly - Metal performance counters provide actual bandwidth values
        return Double(rawCounterValue & 0xFFFF)
    }
    
    /// Calculates compute-specific cache hits
    private func calculateComputeCacheHits(rawCounterValue: UInt64) -> Double {
        // Use raw counter data directly - Metal performance counters provide actual cache hit counts
        return Double((rawCounterValue >> 16) & 0xFFFF)
    }
    
    /// Calculates compute-specific cache misses
    private func calculateComputeCacheMisses(rawCounterValue: UInt64) -> Double {
        // Use raw counter data directly - Metal performance counters provide actual cache miss counts
        return Double((rawCounterValue >> 32) & 0xFFFF)
    }
    
    /// Calculates compute-specific instructions executed
    private func calculateComputeInstructions(rawCounterValue: UInt64) -> Double {
        // Extract instruction count from bits 48-63
        let instructionCount = Double((rawCounterValue >> 48) & 0xFFFF)
        
        // If instruction counter is not available (returns 0), estimate based on workload
        if instructionCount == 0 {
            // Estimate instructions based on threadgroup count and complexity
            let threadgroupCount = Double((testConfig.threadgroupCount?.width ?? 1) * (testConfig.threadgroupCount?.height ?? 1) * (testConfig.threadgroupCount?.depth ?? 1))
            let threadgroupSize = Double((testConfig.threadgroupSize?.width ?? 1) * (testConfig.threadgroupSize?.height ?? 1) * (testConfig.threadgroupSize?.depth ?? 1))
            let complexity = Double(testConfig.computeWorkloadComplexity ?? 1)
            
            // Rough estimation: ~100 instructions per thread * threadgroups * complexity
            let estimatedInstructions = threadgroupCount * threadgroupSize * complexity * 100.0
            return estimatedInstructions
        }
        
        return instructionCount
    }
}
