//
//  GraphicsTestManager.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Metal
import Foundation

/// Manages graphics performance testing operations
class GraphicsTestManager {
    
    /// Runs the graphics performance test and compares against graphics baseline using statistical analysis
    func runPerformanceTest(threshold: Double, testConfig: TestConfiguration? = nil) -> Int32 {
        // GRAPHICS PERFORMANCE TEST RESULTS OUTPUT
        print("Running graphics performance test...")
        print()
        
        // Check if graphics baseline exists
        let graphicsBaselineManager = GraphicsBaselineManager()
        guard graphicsBaselineManager.baselineExists() else {
            print("\nError: No graphics baseline found.")
            print("Run with --update-graphics-baseline first to establish a graphics performance baseline.")
            return ExitCode.error.rawValue
        }
        
        // Initialize Metal and renderer
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("\nError: Metal is not supported on this device.")
            return ExitCode.error.rawValue
        }
        
        let config = testConfig ?? TestPreset.moderate.createConfiguration()
        
        // GRAPHICS PERFORMANCE TEST OUTPUT: Test configuration section
        print("Graphics Test Configuration:")
        print("- Baseline: \(config.description)")
        print("- Device: \(device.name)")
        print("- Triangle count: \(config.triangleCount)")
        print("- Geometry complexity: \(config.geometryComplexity)/10")
        print("- Resolution: \(config.effectiveWidth)x\(config.effectiveHeight)")
        print("- Resolution scale: \(String(format: "%.1f", config.resolutionScale))x")
        print()
        
        guard let renderer = Renderer(device: device, testConfig: config) else {
            print("\nError: Failed to initialize the Renderer.")
            return ExitCode.error.rawValue
        }
        
        // GRAPHICS PERFORMANCE TEST OUTPUT: Iteration progress and completion
        print("Running 100 iterations for statistical analysis...")
        guard let currentMeasurementSet = renderer.runMultipleGraphicsIterations(iterations: 100) else {
            print("\nError: Graphics performance measurement not available on this GPU.")
            print("Counter sampling is not supported.")
            return ExitCode.error.rawValue
        }
        
        // GRAPHICS PERFORMANCE TEST OUTPUT: Progress completion and main results header
        print("Progress: (100/100)")
        let separator = String(repeating: "-", count: 60)
        print(separator)
        print("GRAPHICS PERFORMANCE TEST RESULTS")
        print()
        
            // Load graphics baseline and compare statistically
            do {
                let baselineMeasurementSet = try graphicsBaselineManager.loadBaseline()
                
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
                generateAndPrintGraphicsStatisticalReport(
                    current: currentMeasurementSet,
                    baseline: baselineMeasurementSet,
                    result: comparisonResult
                )
            
            // Save test result to JSON file
            do {
                try graphicsBaselineManager.saveTestResult(testResult)
            } catch {
                print("\nWarning: Failed to save graphics test result: \(error)")
                // Continue execution even if saving fails
            }
            
            // Return appropriate exit code based on statistical significance
            if comparisonResult.isRegression {
                return ExitCode.failure.rawValue
            } else {
                return ExitCode.success.rawValue
            }
            
        } catch {
            print("\nError: Failed to load graphics baseline: \(error)")
            return ExitCode.error.rawValue
        }
    }
    
    /// Generates and prints a comprehensive graphics statistical report
    private func generateAndPrintGraphicsStatisticalReport(
        current: UnifiedPerformanceMeasurementSet,
        baseline: UnifiedPerformanceMeasurementSet,
        result: StatisticalAnalysis.ComparisonResult
    ) {
        // Calculate FPS for both current and baseline
        let currentMeanFPS = 1000.0 / current.statistics.mean
        let baselineMeanFPS = 1000.0 / baseline.statistics.mean
        
        // Performance comparison section
        print("Performance Comparison:")
        print("- Current FPS: \(String(format: "%.1f", currentMeanFPS))")
        print("- Baseline FPS: \(String(format: "%.1f", baselineMeanFPS))")
        
        let fpsChange = ((currentMeanFPS - baselineMeanFPS) / baselineMeanFPS) * 100
        let fpsChangeString = fpsChange >= 0 ? "+\(String(format: "%.1f", fpsChange))%" : "\(String(format: "%.1f", fpsChange))%"
        print("- FPS Change: \(fpsChangeString)")
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
        
        // Stage utilization comparison (if available)
        if let currentStageUtil = current.stageUtilizationStatistics,
           let baselineStageUtil = baseline.stageUtilizationStatistics {
            print("Stage Utilization Comparison:")
            
            if let currentVertex = currentStageUtil.vertexUtilization,
               let baselineVertex = baselineStageUtil.vertexUtilization {
                let vertexChange = ((currentVertex.mean - baselineVertex.mean) / baselineVertex.mean) * 100
                let vertexChangeString = vertexChange >= 0 ? "+\(String(format: "%.1f", vertexChange))%" : "\(String(format: "%.1f", vertexChange))%"
                print("- Vertex Utilization: \(String(format: "%.1f", currentVertex.mean))% (baseline: \(String(format: "%.1f", baselineVertex.mean))%, change: \(vertexChangeString))")
            }
            
            if let currentFragment = currentStageUtil.fragmentUtilization,
               let baselineFragment = baselineStageUtil.fragmentUtilization {
                let fragmentChange = ((currentFragment.mean - baselineFragment.mean) / baselineFragment.mean) * 100
                let fragmentChangeString = fragmentChange >= 0 ? "+\(String(format: "%.1f", fragmentChange))%" : "\(String(format: "%.1f", fragmentChange))%"
                print("- Fragment Utilization: \(String(format: "%.1f", currentFragment.mean))% (baseline: \(String(format: "%.1f", baselineFragment.mean))%, change: \(fragmentChangeString))")
            }
            
            if let currentTotal = currentStageUtil.totalUtilization,
               let baselineTotal = baselineStageUtil.totalUtilization {
                let totalChange = ((currentTotal.mean - baselineTotal.mean) / baselineTotal.mean) * 100
                let totalChangeString = totalChange >= 0 ? "+\(String(format: "%.1f", totalChange))%" : "\(String(format: "%.1f", totalChange))%"
                print("- Total Utilization: \(String(format: "%.1f", currentTotal.mean))% (baseline: \(String(format: "%.1f", baselineTotal.mean))%, change: \(totalChangeString))")
            }
            print()
        }
        
        // Test conclusion
        if result.isRegression {
            print("REGRESSION DETECTED: Graphics performance has significantly degraded.")
            print("Consider investigating recent changes that may have affected rendering performance.")
        } else if result.isSignificant && !result.isRegression {
            print("IMPROVEMENT DETECTED: Graphics performance has significantly improved.")
            print("This may indicate optimizations or hardware improvements.")
        } else {
            print("NO SIGNIFICANT CHANGE: Graphics performance is within normal variance.")
            print("No action required.")
        }
    }
    
}
