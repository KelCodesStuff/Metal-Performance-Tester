//
//  ComputeTestManager.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Metal
import Foundation

/// Manages compute performance testing operations
class ComputeTestManager {
    
    /// Runs the compute performance test and compares against compute baseline using statistical analysis
    func runPerformanceTest(threshold: Double, testConfig: TestConfiguration? = nil) -> Int32 {
        // COMPUTE PERFORMANCE TEST RESULTS OUTPUT
        print("Running compute performance test...")
        print()
        
        // Initialize Metal and renderer
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("\nError: Metal is not supported on this device.")
            return ExitCode.error.rawValue
        }
        
        let config = testConfig ?? TestPreset.computeModerate.createConfiguration()
        
        // Check if compute baseline exists for this specific test configuration
        let computeBaselineManager = ComputeBaselineManager()
        guard computeBaselineManager.baselineExists(for: config) else {
            print("\nError: No compute baseline found for test configuration '\(config.testMode)'.")
            print("Run with --update-compute-baseline --\(config.testMode) first to establish a compute performance baseline.")
            return ExitCode.error.rawValue
        }
        
        // COMPUTE PERFORMANCE TEST OUTPUT: Test configuration section
        print("Compute Test Configuration:")
        print("- Baseline: \(config.description)")
        print("- Device: \(device.name)")
        if let threadgroupSize = config.threadgroupSize {
            print("- Threadgroup size: \(threadgroupSize.width)x\(threadgroupSize.height)x\(threadgroupSize.depth)")
        }
        if let threadgroupCount = config.threadgroupCount {
            print("- Threadgroup count: \(threadgroupCount.width)x\(threadgroupCount.height)x\(threadgroupCount.depth)")
        }
        if let complexity = config.computeWorkloadComplexity {
            print("- Compute workload complexity: \(complexity)/10")
        }
        print()
        
        guard let renderer = Renderer(device: device, testConfig: config) else {
            print("\nError: Failed to initialize the Renderer.")
            return ExitCode.error.rawValue
        }
        
        // COMPUTE PERFORMANCE TEST OUTPUT: Iteration progress and completion
        print("Running 50 iterations for statistical analysis...")
        guard let currentMeasurementSet = renderer.runMultipleComputeIterations(iterations: 50) else {
            print("\nError: Compute performance measurement not available on this GPU.")
            print("Counter sampling is not supported.")
            return ExitCode.error.rawValue
        }
        
        // COMPUTE PERFORMANCE TEST OUTPUT: Progress completion and main results header
        print("Progress: (50/50)")
        let separator = String(repeating: "-", count: 60)
        print(separator)
        print("COMPUTE PERFORMANCE TEST RESULTS")
        print()
        
            // Load compute baseline and compare statistically
            do {
                let baselineMeasurementSet = try computeBaselineManager.loadBaseline(for: config)
            
            // Use unified comparison method
            let comparisonResult = RegressionChecker.compareUnifiedStatistical(
                current: currentMeasurementSet,
                baseline: baselineMeasurementSet,
                significanceLevel: 0.05
            )
            
            // Create and save test result
            let testResult = UnifiedPerformanceTestResult(
                current: currentMeasurementSet,
                baseline: baselineMeasurementSet,
                comparison: comparisonResult
            )
            
            // Generate and print statistical report
            generateAndPrintComputeStatisticalReport(
                current: currentMeasurementSet,
                baseline: baselineMeasurementSet,
                result: comparisonResult
            )
            
            // Save test result to JSON file
            do {
                try computeBaselineManager.saveTestResult(testResult)
            } catch {
                print("\nWarning: Failed to save compute test result: \(error)")
                // Continue execution even if saving fails
            }
            
            // Return appropriate exit code based on statistical significance
            if comparisonResult.isRegression {
                return ExitCode.failure.rawValue
            } else {
                return ExitCode.success.rawValue
            }
            
        } catch {
            print("\nError: Failed to load compute baseline: \(error)")
            return ExitCode.error.rawValue
        }
    }
    
    
    /// Generates and prints a comprehensive compute statistical report
    private func generateAndPrintComputeStatisticalReport(
        current: UnifiedPerformanceMeasurementSet,
        baseline: UnifiedPerformanceMeasurementSet,
        result: StatisticalAnalysis.ComparisonResult
    ) {
        // Calculate compute throughput for both current and baseline
        let currentThroughput = 1000.0 / current.statistics.mean
        let baselineThroughput = 1000.0 / baseline.statistics.mean
        
        // Performance comparison section
        print("Performance Comparison:")
        print("- Current Throughput: \(String(format: "%.1f", currentThroughput)) ops/sec")
        print("- Baseline Throughput: \(String(format: "%.1f", baselineThroughput)) ops/sec")
        
        let throughputChange = ((currentThroughput - baselineThroughput) / baselineThroughput) * 100
        let throughputChangeString = throughputChange >= 0 ? "+\(String(format: "%.1f", throughputChange))%" : "\(String(format: "%.1f", throughputChange))%"
        print("- Throughput Change: \(throughputChangeString)")
        print()
        
        // Statistical analysis section
        print("Statistical Analysis:")
        print("- Mean Difference: \(String(format: "%.3f", result.meanDifference)) ms")
        print("- 95% Confidence Interval: [\(String(format: "%.3f", result.confidenceInterval.lower)), \(String(format: "%.3f", result.confidenceInterval.upper))] ms")
        if let pValue = result.pValue {
            print("- P-value: \(String(format: "%.6f", pValue))")
        } else {
            print("- P-value: N/A")
        }
        print("- Statistical Significance: \(result.isSignificant ? "Yes" : "No")")
        print("- Regression Detected: \(result.isRegression ? "Yes" : "No")")
        print()
        
        // Quality comparison section
        print("Quality Comparison:")
        print("- Current Quality: \(current.statistics.qualityRating.rawValue)")
        print("- Baseline Quality: \(baseline.statistics.qualityRating.rawValue)")
        print()
        
        // Compute utilization comparison (if available)
        if let currentComputeUtil = current.computeUtilizationStatistics,
           let baselineComputeUtil = baseline.computeUtilizationStatistics {
            print("Compute Utilization Comparison:")
            
            if let currentCompute = currentComputeUtil.computeUtilization,
               let baselineCompute = baselineComputeUtil.computeUtilization {
                let computeChange = ((currentCompute.mean - baselineCompute.mean) / baselineCompute.mean) * 100
                let computeChangeString = computeChange >= 0 ? "+\(String(format: "%.1f", computeChange))%" : "\(String(format: "%.1f", computeChange))%"
                print("- Compute Utilization: \(String(format: "%.1f", currentCompute.mean))% (baseline: \(String(format: "%.1f", baselineCompute.mean))%, change: \(computeChangeString))")
            }
            
            if let currentMemory = currentComputeUtil.memoryUtilization,
               let baselineMemory = baselineComputeUtil.memoryUtilization {
                let memoryChange = ((currentMemory.mean - baselineMemory.mean) / baselineMemory.mean) * 100
                let memoryChangeString = memoryChange >= 0 ? "+\(String(format: "%.1f", memoryChange))%" : "\(String(format: "%.1f", memoryChange))%"
                print("- Memory Utilization: \(String(format: "%.1f", currentMemory.mean))% (baseline: \(String(format: "%.1f", baselineMemory.mean))%, change: \(memoryChangeString))")
            }
            
            if let currentTotal = currentComputeUtil.totalUtilization,
               let baselineTotal = baselineComputeUtil.totalUtilization {
                let totalChange = ((currentTotal.mean - baselineTotal.mean) / baselineTotal.mean) * 100
                let totalChangeString = totalChange >= 0 ? "+\(String(format: "%.1f", totalChange))%" : "\(String(format: "%.1f", totalChange))%"
                print("- Total Utilization: \(String(format: "%.1f", currentTotal.mean))% (baseline: \(String(format: "%.1f", baselineTotal.mean))%, change: \(totalChangeString))")
            }
            print()
        }
        
        // Test conclusion
        if result.isRegression {
            print("REGRESSION DETECTED: Compute performance has significantly degraded.")
            print("Consider investigating recent changes that may have affected compute performance.")
        } else if result.isSignificant && !result.isRegression {
            print("IMPROVEMENT DETECTED: Compute performance has significantly improved.")
            print("This may indicate optimizations or hardware improvements.")
        } else {
            print("NO SIGNIFICANT CHANGE: Compute performance is within normal variance.")
            print("No action required.")
        }
    }
}
