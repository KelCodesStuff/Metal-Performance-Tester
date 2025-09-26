//
//  RegressionChecker.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation

/// Result of a performance comparison (legacy enum for backward compatibility)
enum ComparisonResult {
    case passed(improvement: Double)
    case failed(regression: Double)
}

/// Compares current performance against baseline and determines if regression occurred
class RegressionChecker {
    
    /// Compares current performance measurement set against baseline using statistical analysis
    /// - Parameters:
    ///   - current: Current performance measurement set
    ///   - baseline: Baseline performance measurement set
    ///   - significanceLevel: Statistical significance level (default: 0.05 for 95% confidence)
    /// - Returns: Statistical comparison result
    static func compareStatistical(current: PerformanceMeasurementSet, baseline: PerformanceMeasurementSet, significanceLevel: Double = 0.05) -> StatisticalAnalysis.ComparisonResult {
        return StatisticalAnalysis.compare(baseline: baseline, current: current, significanceLevel: significanceLevel)
    }
    
    /// Compares graphics performance results using statistical analysis
    static func compareGraphicsStatistical(current: GraphicsMeasurementSet, baseline: GraphicsMeasurementSet, significanceLevel: Double = 0.05) -> StatisticalAnalysis.ComparisonResult {
        // Convert GraphicsMeasurementSet to PerformanceMeasurementSet for comparison
        let currentPerformance = convertToPerformanceMeasurementSet(current)
        let baselinePerformance = convertToPerformanceMeasurementSet(baseline)
        return StatisticalAnalysis.compare(baseline: baselinePerformance, current: currentPerformance, significanceLevel: significanceLevel)
    }
    
    /// Converts GraphicsMeasurementSet to PerformanceMeasurementSet
    private static func convertToPerformanceMeasurementSet(_ graphicsSet: GraphicsMeasurementSet) -> PerformanceMeasurementSet {
        let performanceResults = graphicsSet.individualResults.map { graphicsResult in
            PerformanceResult(
                gpuTimeMs: graphicsResult.gpuTimeMs,
                deviceName: graphicsResult.deviceName,
                testConfig: graphicsResult.testConfig,
                stageUtilization: graphicsResult.stageUtilization,
                statistics: graphicsResult.statistics
            )
        }
        return PerformanceMeasurementSet(individualResults: performanceResults)
    }
    
    /// Compares current performance result against baseline (legacy method for backward compatibility)
    /// - Parameters:
    ///   - current: Current performance measurement
    ///   - baseline: Baseline performance measurement
    ///   - threshold: Maximum allowed performance regression (as decimal, e.g., 0.05 for 5%)
    /// - Returns: Comparison result indicating pass/fail and percentage change
    static func compare(current: PerformanceResult, baseline: PerformanceResult, threshold: Double) -> ComparisonResult {
        let baselineTime = baseline.gpuTimeMs
        let currentTime = current.gpuTimeMs
        
        // Calculate percentage change (positive = slower, negative = faster)
        let percentageChange = (currentTime - baselineTime) / baselineTime
        
        if percentageChange <= threshold {
            // Performance is within acceptable range (including improvements)
            return .passed(improvement: -percentageChange) // Convert to positive improvement
        } else {
            // Performance regression detected
            return .failed(regression: percentageChange)
        }
    }
    
    
    /// Generates a detailed comparison report (legacy method for backward compatibility)
    /// - Parameters:
    ///   - current: Current performance measurement
    ///   - baseline: Baseline performance measurement
    ///   - result: Comparison result
    ///   - threshold: Threshold used for comparison
    /// - Returns: Formatted report string
    static func generateReport(current: PerformanceResult, baseline: PerformanceResult, result: ComparisonResult, threshold: Double) -> String {
        let baselineTime = baseline.gpuTimeMs
        let currentTime = current.gpuTimeMs
        let thresholdPercent = threshold * 100
        
        var report = "PERFORMANCE COMPARISON REPORT\n"
        report += "================================\n\n"
        report += "Device: \(current.deviceName)\n"
        report += "Test Configuration: \(current.testConfig.description)\n\n"
        
        switch result {
        case .passed(let improvement):
            let improvementPercent = improvement * 100
            report += "Performance Metrics:\n"
            report += "  Baseline: \(String(format: "%.3f", baselineTime)) ms\n"
            report += "  Current:  \(String(format: "%.3f", currentTime)) ms\n"
            report += "  Change:   \(String(format: "%+.1f", improvementPercent))% (improvement)\n"
            report += "  Threshold: \(String(format: "%.1f", thresholdPercent))%\n\n"
            
        case .failed(let regression):
            let regressionPercent = regression * 100
            report += "Performance Metrics:\n"
            report += "  Baseline: \(String(format: "%.3f", baselineTime)) ms\n"
            report += "  Current:  \(String(format: "%.3f", currentTime)) ms\n"
            report += "  Change:   \(String(format: "%+.1f", regressionPercent))% (regression)\n"
            report += "  Threshold: \(String(format: "%.1f", thresholdPercent))%\n\n"
        }
        
        
        // Add result at the bottom
        switch result {
        case .passed:
            report += "RESULT: TEST PASSED\n"
        case .failed:
            report += "RESULT: PERFORMANCE REGRESSION DETECTED\n"
        }
        
        return report
    }
}
