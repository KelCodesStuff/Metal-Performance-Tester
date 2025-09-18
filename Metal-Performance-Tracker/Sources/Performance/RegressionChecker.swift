//
//  RegressionChecker.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation

/// Result of a performance comparison
enum ComparisonResult {
    case passed(improvement: Double)
    case failed(regression: Double)
}

/// Compares current performance against baseline and determines if regression occurred
class RegressionChecker {
    
    /// Compares current performance result against baseline
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
    
    /// Generates a detailed comparison report
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
        Test Configuration: \(current.testConfig.width)x\(current.testConfig.height) @ \(current.testConfig.pixelFormat)
        
        """
        
        switch result {
        case .passed(let improvement):
            let improvementPercent = improvement * 100
            report += """
            TEST PASSED
            
            Performance Metrics:
            - Baseline: \(String(format: "%.3f", baselineTime)) ms
            - Current:  \(String(format: "%.3f", currentTime)) ms
            - Change:   \(String(format: "%+.1f", improvementPercent))% (improvement)
            - Threshold: \(String(format: "%.1f", thresholdPercent))%
            
            """
            
        case .failed(let regression):
            let regressionPercent = regression * 100
            report += """
            PERFORMANCE REGRESSION DETECTED
            
            Performance Metrics:
            - Baseline: \(String(format: "%.3f", baselineTime)) ms
            - Current:  \(String(format: "%.3f", currentTime)) ms
            - Change:   \(String(format: "%+.1f", regressionPercent))% (regression)
            - Threshold: \(String(format: "%.1f", thresholdPercent))%
            
            """
        }
        
        // Add timestamp information
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        report += """
        
        Timestamps:
        - Baseline: \(formatter.string(from: baseline.timestamp))
        - Current:  \(formatter.string(from: current.timestamp))
        
        """
        
        return report
    }
}
