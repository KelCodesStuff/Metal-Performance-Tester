//
//  PerformanceTestManager.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/23/25.
//

import Metal
import Foundation

/// Manages performance test operations
class PerformanceTestManager {
    
    /// Runs the performance test and compares against baseline using statistical analysis
    func runPerformanceTest(threshold: Double, testConfig: TestConfiguration? = nil) -> Int32 {
        // PERFORMANCE TEST RESULTS OUTPUT
        print("Running performance test...")
        print()
        
        // Check if baseline exists
        let baselineManager = PerformanceBaselineManager()
        guard baselineManager.baselineExists() else {
            print("\nError: No baseline found.")
            print("Run with --update-baseline first to establish a performance baseline.")
            return ExitCode.error.rawValue
        }
        
        // Initialize Metal and renderer
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("\nError: Metal is not supported on this device.")
            return ExitCode.error.rawValue
        }
        
        let config = testConfig ?? TestPreset.moderate.createConfiguration()
        
        // PERFORMANCE TEST OUTPUT: Test configuration section
        print("Test Configuration:")
        print("- Baseline: \(config.description)")
        print("- Device: \(device.name)")
        print("- Triangle count: \(config.triangleCount)")
        print("- Geometry complexity: \(config.geometryComplexity)/10")
        print("- Resolution: \(config.width)x\(config.height)")
        print("- Resolution scale: \(String(format: "%.1f", config.resolutionScale))x")
        print()
        
        guard let renderer = Renderer(device: device, testConfig: config) else {
            print("\nError: Failed to initialize the Renderer.")
            return ExitCode.error.rawValue
        }
        
        // PERFORMANCE TEST OUTPUT: Iteration progress and completion
        print("Running 100 iterations for statistical analysis...")
        guard let currentMeasurementSet = renderer.runMultipleIterations(iterations: 100) else {
            print("\nError: Performance measurement not available on this GPU.")
            print("Counter sampling is not supported.")
            return ExitCode.error.rawValue
        }
        
        // PERFORMANCE TEST OUTPUT: Progress completion and main results header
        print("Progress: (100/100)")
        print("============================================================")
        print("PERFORMANCE TEST RESULTS")
        print()
        
        // Load baseline and compare statistically
        do {
            let baselineMeasurementSet = try baselineManager.loadBaseline()
            let comparisonResult = RegressionChecker.compareStatistical(
                current: currentMeasurementSet,
                baseline: baselineMeasurementSet,
                significanceLevel: 0.05
            )
            
            // Create and save test result
            let testResult = PerformanceTestResult(
                current: currentMeasurementSet,
                baseline: baselineMeasurementSet,
                comparison: comparisonResult
            )
            
            // Generate and print statistical report
            generateAndPrintStatisticalReport(
                current: currentMeasurementSet,
                baseline: baselineMeasurementSet,
                result: comparisonResult
            )
            
            // Save test result to JSON file
            do {
                try baselineManager.saveTestResult(testResult)
            } catch {
                print("\nWarning: Failed to save test result: \(error)")
                // Continue execution even if saving fails
            }
            
            // Return appropriate exit code based on statistical significance
            if comparisonResult.isRegression {
                return ExitCode.failure.rawValue
            } else {
                return ExitCode.success.rawValue
            }
            
        } catch {
            print("\nError: Failed to load baseline: \(error)")
            return ExitCode.error.rawValue
        }
    }
    
    /// Generates and prints a detailed statistical comparison report
    /// - Parameters:
    ///   - current: Current performance measurement set
    ///   - baseline: Baseline performance measurement set
    ///   - result: Statistical comparison result
    private func generateAndPrintStatisticalReport(current: PerformanceMeasurementSet, baseline: PerformanceMeasurementSet, result: StatisticalAnalysis.ComparisonResult) {
        // Calculate FPS from GPU time
        let meanFPS = 1000.0 / current.statistics.mean
        let minFPS = 1000.0 / (current.statistics.mean + current.statistics.standardDeviation)
        let maxFPS = 1000.0 / (current.statistics.mean - current.statistics.standardDeviation)
        
        print("Frequency:")
        print("- FPS: \(String(format: "%.1f", meanFPS)) (\(String(format: "%.1f", minFPS)) - \(String(format: "%.1f", maxFPS)))")
        print()
        
        // Add time comparison section first
        print("Render Time Comparison:")
        print("- Average:   \(String(format: "%+.3f", result.meanDifference)) ms  (\(String(format: "%+.1f", result.meanDifferencePercent))%)")
        print("- Standard Deviation: \(String(format: "%.3f", current.statistics.standardDeviation)) ms")
        print("- Coefficient of Variation: \(String(format: "%.1f", current.statistics.coefficientOfVariation * 100))%")
        
        // Add stage utilization comparison
        print()
        print("Stage Utilization Comparison:")
        
        if let vertex = result.stageUtilizationComparison?.vertexUtilization {
            print("- Vertex Utilization: \(String(format: "%.1f", vertex.current))%  (\(String(format: "%+.1f", vertex.change))%)")
        }
        
        if let fragment = result.stageUtilizationComparison?.fragmentUtilization {
            print("- Fragment Utilization: \(String(format: "%.1f", fragment.current))%  (\(String(format: "%+.1f", fragment.change))%)")
        }
        
        if let total = result.stageUtilizationComparison?.totalUtilization {
            print("- Total Utilization: \(String(format: "%.1f", total.current))%  (\(String(format: "%+.1f", total.change))%)")
        }
        
        // Add performance statistics comparison
        print()
        print("Memory Statistics Comparison:")
        
        // Get actual cache hits and misses from current test data
        if let lastResult = current.individualResults.last,
           let statistics = lastResult.statistics {
            if let cacheHits = statistics.cacheHits {
                print("- Cache Hits: \(String(format: "%.0f", cacheHits))")
            }
            if let cacheMisses = statistics.cacheMisses {
                print("- Cache Misses: \(String(format: "%.0f", cacheMisses))")
            }
        }
        
        if let cache = result.performanceStatsComparison?.cacheHitRate {
            print("- Cache Hit Rate: \(String(format: "%.1f", cache.current * 100))%  (\(String(format: "%+.1f", cache.changePercent))%)")
        }
        
        if let memory = result.performanceStatsComparison?.memoryBandwidth {
            print("- Memory Bandwidth: \(String(format: "%.1f", memory.current)) MB/s  (\(String(format: "%+.1f", memory.changePercent))%)")
        }
        
        if let instructions = result.performanceStatsComparison?.instructionsExecuted {
            print("- Instructions Executed: \(String(format: "%.0f", instructions.current))  (\(String(format: "%+.1f", instructions.changePercent))%)")
        }
        
        // Add statistical analysis section
        print()
        print("Statistical Analysis:")
        print("- Confidence Range: \(String(format: "%.3f", abs(result.confidenceInterval.lower))) to \(String(format: "%.3f", abs(result.confidenceInterval.upper))) ms faster  (95% confidence)")
        print("- Reliability: \(result.isSignificant ? "Statistically significant (real change, not random)" : "Not statistically significant (could be random variation)")")
        
        // Add result at the bottom
        if result.isRegression {
            print()
            print("Result: PERFORMANCE REGRESSION DETECTED")
            print()
        } else if result.isImprovement {
            print()
            print("Result: PERFORMANCE IMPROVEMENT DETECTED")
            print()
        } else {
            print()
            print("Result: NO SIGNIFICANT CHANGE DETECTED")
            print()
        }
    }
}

