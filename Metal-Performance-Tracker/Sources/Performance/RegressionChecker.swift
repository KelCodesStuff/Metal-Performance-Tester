//
//  RegressionChecker.swift
//  Metal-Performance-Tracker
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
        let baselineTimes = baseline.individualResults.map { $0.gpuTimeMs }
        let currentTimes = current.individualResults.map { $0.gpuTimeMs }
        
        return StatisticalAnalysis.compare(baseline: baselineTimes, current: currentTimes, significanceLevel: significanceLevel)
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
    
    /// Generates a detailed statistical comparison report
    /// - Parameters:
    ///   - current: Current performance measurement set
    ///   - baseline: Baseline performance measurement set
    ///   - result: Statistical comparison result
    /// - Returns: Formatted report string
    static func generateStatisticalReport(current: PerformanceMeasurementSet, baseline: PerformanceMeasurementSet, result: StatisticalAnalysis.ComparisonResult) -> String {
        var report = """

        PERFORMANCE TEST RESULTS
        ============================
        
        Test Configuration: \(current.testConfig.description)
        Device: \(current.deviceName)
        
        Statistics:
        - Iterations: \(current.iterationCount)
        - Quality Rating: \(current.qualityRating.rawValue)
        - Mean GPU Time: \(String(format: "%.3f", current.statistics.mean)) ms
        - Standard Deviation: \(String(format: "%.3f", current.statistics.standardDeviation)) ms
        - Coefficient of Variation: \(String(format: "%.1f", current.statistics.coefficientOfVariation * 100))%
        
        """
        
        // Add stage utilization if available
        if let stageUtilStats = current.stageUtilizationStatistics {
            report += "\nStage Utilization:\n"
            if let vertex = stageUtilStats.vertexUtilization {
                report += "- Average Vertex Utilization: \(String(format: "%.1f", vertex.mean))%\n"
            }
            if let fragment = stageUtilStats.fragmentUtilization {
                report += "- Average Fragment Utilization: \(String(format: "%.1f", fragment.mean))%\n"
            }
            if let total = stageUtilStats.totalUtilization {
                report += "- Average Total Utilization: \(String(format: "%.1f", total.mean))%\n"
            }
        }
        
        // Add performance statistics from the last result
        if let lastResult = current.individualResults.last,
           let stats = lastResult.statistics {
            report += "\nPerformance Statistics:\n"
            if let bandwidth = stats.memoryBandwidth {
                report += "- Memory Bandwidth: \(String(format: "%.1f", bandwidth)) MB/s\n"
            }
            if let cacheHits = stats.cacheHits {
                report += "- Cache Hits: \(String(format: "%.0f", cacheHits))\n"
            }
            if let cacheMisses = stats.cacheMisses {
                report += "- Cache Misses: \(String(format: "%.0f", cacheMisses))\n"
            }
            if let hitRate = stats.cacheHitRate {
                report += "- Cache Hit Rate: \(String(format: "%.1f", hitRate * 100))%\n"
            }
            if let instructions = stats.instructionsExecuted {
                report += "- Instructions Executed: \(String(format: "%.0f", instructions))\n"
            }
        }
        
        // Add baseline comparison context
        report += "\nBaseline Comparison:\n"
        report += "- Baseline: \(String(format: "%.3f", baseline.statistics.mean)) ms\n"
        report += "- Current:  \(String(format: "%.3f", current.statistics.mean)) ms\n"
        report += "- Change:   \(String(format: "%+.3f", result.meanDifference)) ms (\(String(format: "%+.1f", result.meanDifferencePercent * 100))%)\n"
        
        report += "\nStatistical Comparison:\n"
        report += "- Confidence Interval: [\(String(format: "%.3f", result.confidenceInterval.lower)), \(String(format: "%.3f", result.confidenceInterval.upper))]\n"
        report += "- Statistical Significance: \(result.isSignificant ? "significant" : "not significant")\n"
        
        // Add result at the bottom
        if result.isRegression {
            report += "\nResult: PERFORMANCE REGRESSION DETECTED"
        } else if result.isImprovement {
            report += "\nResult: PERFORMANCE IMPROVEMENT DETECTED"
        } else {
            report += "\nResult: NO SIGNIFICANT CHANGE DETECTED"
        }
        
        return report
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
        
        var report = """
        PERFORMANCE COMPARISON REPORT
        ================================
        
        Device: \(current.deviceName)
        Test Configuration: \(current.testConfig.description)
        
        """
        
        switch result {
        case .passed(let improvement):
            let improvementPercent = improvement * 100
            report += """
            Performance Metrics:
              Baseline: \(String(format: "%.3f", baselineTime)) ms
              Current:  \(String(format: "%.3f", currentTime)) ms
              Change:   \(String(format: "%+.1f", improvementPercent))% (improvement)
              Threshold: \(String(format: "%.1f", thresholdPercent))%
            
            """
            
        case .failed(let regression):
            let regressionPercent = regression * 100
            report += """
            Performance Metrics:
              Baseline: \(String(format: "%.3f", baselineTime)) ms
              Current:  \(String(format: "%.3f", currentTime)) ms
              Change:   \(String(format: "%+.1f", regressionPercent))% (regression)
              Threshold: \(String(format: "%.1f", thresholdPercent))%
            
            """
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
