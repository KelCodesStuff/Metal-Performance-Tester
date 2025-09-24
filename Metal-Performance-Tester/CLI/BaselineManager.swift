//
//  BaselineManager.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/23/25.
//

import Metal
import Foundation

/// Manages baseline update operations
class BaselineManager {
    
    /// Runs the performance test and updates the baseline with multiple iterations
    func runUpdateBaseline(testConfig: TestConfiguration? = nil) -> Int32 {
        // BASELINE UPDATE OUTPUT: Start of baseline update flow
        print("Running performance baseline...")
        print()
        
        // Initialize Metal and renderer
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device.")
            return ExitCode.error.rawValue
        }
        
        let config = testConfig ?? TestPreset.moderate.createConfiguration()
        
        // BASELINE CONFIGURATION OUTPUT
        print("Baseline Configuration:")
        print("- Baseline: \(config.description)")
        print("- Device: \(device.name)")
        print("- Triangle count: \(config.triangleCount)")
        print("- Geometry complexity: \(config.geometryComplexity)/10")
        print("- Resolution: \(config.width)x\(config.height)")
        print("- Resolution scale: \(String(format: "%.1f", config.resolutionScale))x")
        print()
        
        guard let renderer = Renderer(device: device, testConfig: config) else {
            print("Failed to initialize the Renderer.")
            return ExitCode.error.rawValue
        }
        
        // BASELINE UPDATE OUTPUT: Iteration progress and completion
        print("Running 100 iterations to create baseline...")
        guard let measurementSet = renderer.runMultipleIterations(iterations: 100) else {
            print("Performance measurement not available on this GPU.")
            print("Counter sampling is not supported. Cannot establish baseline.")
            return ExitCode.error.rawValue
        }
        
        // PERFORMANCE BASELINE RESULTS OUTPUT
        print("Progress: (100/100)")
        print("============================================================")
        print("PERFORMANCE BASELINE RESULTS")
        print()
        
        // Calculate FPS and range using pre-calculated statistics
        let meanFPS = 1000.0 / measurementSet.statistics.mean
        let minFPS = 1000.0 / measurementSet.statistics.max  // max time = min FPS
        let maxFPS = 1000.0 / measurementSet.statistics.min  // min time = max FPS
        
        // Use pre-calculated time statistics (safer and more efficient)
        let minTime = measurementSet.statistics.min
        let maxTime = measurementSet.statistics.max
        let medianTime = measurementSet.statistics.median
        
        // Calculate quality rating using pre-calculated coefficient of variation
        let coefficientOfVariation = measurementSet.statistics.coefficientOfVariation * 100
        let qualityRating = coefficientOfVariation < 1.0 ? "Excellent" : 
                           coefficientOfVariation < 2.0 ? "Good" : 
                           coefficientOfVariation < 5.0 ? "Fair" : "Poor"
        
        // Display Frequency section
        print("Frequency:")
        print("- FPS: \(String(format: "%.1f", meanFPS)) (\(String(format: "%.1f", minFPS)) - \(String(format: "%.1f", maxFPS)))")
        print()
        
        // Display Time section
        print("Render Time:")
        print("- Average: \(String(format: "%.3f", measurementSet.averageGpuTimeMs)) ms")
        print("- Standard Deviation: \(String(format: "%.3f", measurementSet.statistics.standardDeviation)) ms")
        print("- Range: \(String(format: "%.3f", minTime)) - \(String(format: "%.3f", maxTime)) ms")
        print("- Median: \(String(format: "%.3f", medianTime)) ms")
        print("- Coefficient of Variation: \(String(format: "%.1f", coefficientOfVariation))%")
        print("- Quality: \(qualityRating)")
        print()
        
        // Display Stage Utilization section
        if let lastResult = measurementSet.individualResults.last,
           let stageUtilization = lastResult.stageUtilization {
            print("Stage Utilization:")
            if let vertexUtil = stageUtilization.vertexUtilization {
                print("- Average Vertex Utilization: \(String(format: "%.1f", vertexUtil))%")
            }
            if let fragmentUtil = stageUtilization.fragmentUtilization {
                print("- Average Fragment Utilization: \(String(format: "%.1f", fragmentUtil))%")
            }
            if let totalUtil = stageUtilization.totalUtilization {
                print("- Average Total Utilization: \(String(format: "%.1f", totalUtil))%")
            }
            print()
        }
        
        // Display Performance Statistics section
        if let lastResult = measurementSet.individualResults.last,
           let statistics = lastResult.statistics {
            print("Memory Statistics:")
            if let memoryBandwidth = statistics.memoryBandwidth {
                print("- Memory Bandwidth: \(String(format: "%.1f", memoryBandwidth)) MB/s")
            }
            if let cacheHits = statistics.cacheHits {
                print("- Cache Hits: \(String(format: "%.0f", cacheHits))")
            }
            if let cacheMisses = statistics.cacheMisses {
                print("- Cache Misses: \(String(format: "%.0f", cacheMisses))")
            }
            if let cacheHitRate = statistics.cacheHitRate {
                print("- Cache Hit Rate: \(String(format: "%.1f", cacheHitRate * 100))%")
            }
            if let instructionsExecuted = statistics.instructionsExecuted {
                print("- Instructions Executed: \(String(format: "%.0f", instructionsExecuted))")
            }
            print()
        }
        
        // Calculate and display Performance Impact
        let performanceImpact = TestConfigurationHelper.calculatePerformanceImpactFromResults(
            gpuTimeMs: measurementSet.averageGpuTimeMs,
            totalUtilization: measurementSet.individualResults.last?.stageUtilization?.totalUtilization,
            memoryBandwidth: measurementSet.individualResults.last?.statistics?.memoryBandwidth,
            instructionsExecuted: measurementSet.individualResults.last?.statistics?.instructionsExecuted
        )
        
        print("Performance Impact: \(performanceImpact)")
        print()
        
        // Save as new baseline
        let baselineManager = PerformanceBaselineManager()
        do {
            try baselineManager.saveBaseline(measurementSet)
            print("Baseline created successfully")
            return ExitCode.success.rawValue
        } catch {
            print("Failed to save baseline: \(error)")
            return ExitCode.error.rawValue
        }
    }
}

