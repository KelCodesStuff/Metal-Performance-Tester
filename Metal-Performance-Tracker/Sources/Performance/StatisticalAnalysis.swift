//
//  StatisticalAnalysis.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/20/25.
//

import Foundation

/// Statistical analysis utilities for performance data
struct StatisticalAnalysis {
    
    /// Confidence interval structure
    struct ConfidenceInterval: Codable {
        let lower: Double
        let upper: Double
    }
    
    /// Statistical summary of performance measurements
    struct PerformanceStatistics: Codable {
        let mean: Double
        let standardDeviation: Double
        let min: Double
        let max: Double
        let median: Double
        let coefficientOfVariation: Double // CV = stdDev / mean
        let sampleCount: Int
        let confidenceInterval95: ConfidenceInterval
        
        /// Quality rating based on coefficient of variation
        var qualityRating: QualityRating {
            if coefficientOfVariation < 0.05 { // < 5% CV
                return .excellent
            } else if coefficientOfVariation < 0.10 { // < 10% CV
                return .good
            } else if coefficientOfVariation < 0.20 { // < 20% CV
                return .fair
            } else {
                return .poor
            }
        }
        
        /// Summary of the performance statistics
        var summary: String {
            return """
            - Average: \(String(format: "%.3f", mean)) ms
            - Standard Deviation: \(String(format: "%.3f", standardDeviation)) ms
            - Range: \(String(format: "%.3f", min)) - \(String(format: "%.3f", max)) ms
            - Median: \(String(format: "%.3f", median)) ms
            - Coefficient of Variation: \(String(format: "%.1f", coefficientOfVariation * 100))%
            - Quality: \(qualityRating.rawValue)
            """
        }
    }
    
    /// Statistical analysis for stage utilization metrics
    struct StageUtilizationStatistics: Codable {
        let vertexUtilization: UtilizationStatistic?
        let fragmentUtilization: UtilizationStatistic?
        let totalUtilization: UtilizationStatistic?
        let sampleCount: Int
        
        /// Summary of stage utilization statistics
        var summary: String {
            var result = "Stage Utilization:\n"
            
            if let vertex = vertexUtilization {
                result += "- Average Vertex Utilization: \(String(format: "%.1f", vertex.mean))%\n"
            }
            
            if let fragment = fragmentUtilization {
                result += "- Average Fragment Utilization: \(String(format: "%.1f", fragment.mean))%\n"
            }
            
            if let total = totalUtilization {
                result += "- Average Total Utilization: \(String(format: "%.1f", total.mean))%\n"
            }
            
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    /// Individual utilization statistic
    struct UtilizationStatistic: Codable {
        let mean: Double
        let standardDeviation: Double
        let min: Double
        let max: Double
        let median: Double
        let coefficientOfVariation: Double
    }
    
    enum QualityRating: String, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
    }
    
    /// Result of statistical comparison between two performance datasets
    struct ComparisonResult: Codable {
        let baselineStats: PerformanceStatistics
        let currentStats: PerformanceStatistics
        let meanDifference: Double
        let meanDifferencePercent: Double
        let confidenceInterval: ConfidenceInterval
        let isSignificant: Bool
        let significanceLevel: Double
        
        /// Determines if there's a performance regression
        var isRegression: Bool {
            return isSignificant && meanDifference > 0
        }
        
        /// Determines if there's a performance improvement
        var isImprovement: Bool {
            return isSignificant && meanDifference < 0
        }
        
        /// Summary of the statistical comparison
        var summary: String {
            let direction = meanDifference > 0 ? "regression" : "improvement"
            let significance = isSignificant ? "significant" : "not significant"
            
            return """
            Mean Difference: \(String(format: "%+.3f", meanDifference)) ms (\(String(format: "%+.1f", meanDifferencePercent))%)
            Confidence Interval: [\(String(format: "%.3f", confidenceInterval.lower)), \(String(format: "%.3f", confidenceInterval.upper))]
            Statistical Significance: \(significance)
            Result: \(isSignificant ? direction : "no significant change")
            """
        }
    }
    
    /// Calculate statistical summary from a collection of performance measurements
    static func calculateStatistics(_ values: [Double]) -> PerformanceStatistics {
        guard !values.isEmpty else {
            fatalError("Cannot calculate statistics from empty array")
        }
        
        let sortedValues = values.sorted()
        let n = values.count
        
        // Basic statistics
        let mean = values.reduce(0, +) / Double(n)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(n - 1)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = standardDeviation / mean
        
        // Percentiles
        let median = calculatePercentile(sortedValues, 50.0)
        
        // Confidence interval (95%)
        let tValue = tDistributionValue(degreesOfFreedom: n - 1, confidenceLevel: 0.95)
        let marginOfError = tValue * (standardDeviation / sqrt(Double(n)))
        let confidenceInterval = (mean - marginOfError, mean + marginOfError)
        
        return PerformanceStatistics(
            mean: mean,
            standardDeviation: standardDeviation,
            min: sortedValues.first!,
            max: sortedValues.last!,
            median: median,
            coefficientOfVariation: coefficientOfVariation,
            sampleCount: n,
            confidenceInterval95: ConfidenceInterval(lower: confidenceInterval.0, upper: confidenceInterval.1)
        )
    }
    
    /// Calculate stage utilization statistics from performance results
    static func calculateStageUtilizationStatistics(from results: [PerformanceResult]) -> StageUtilizationStatistics? {
        guard !results.isEmpty else { return nil }
        
        // Extract utilization data, filtering out nil values
        let vertexValues = results.compactMap { $0.stageUtilization?.vertexUtilization }
        let fragmentValues = results.compactMap { $0.stageUtilization?.fragmentUtilization }
        let totalValues = results.compactMap { $0.stageUtilization?.totalUtilization }
        
        // Only proceed if we have at least some utilization data
        guard !vertexValues.isEmpty || !fragmentValues.isEmpty || !totalValues.isEmpty else { return nil }
        
        let vertexUtilization = vertexValues.isEmpty ? nil : calculateUtilizationStatistic(vertexValues)
        let fragmentUtilization = fragmentValues.isEmpty ? nil : calculateUtilizationStatistic(fragmentValues)
        let totalUtilization = totalValues.isEmpty ? nil : calculateUtilizationStatistic(totalValues)
        
        return StageUtilizationStatistics(
            vertexUtilization: vertexUtilization,
            fragmentUtilization: fragmentUtilization,
            totalUtilization: totalUtilization,
            sampleCount: results.count
        )
    }
    
    /// Calculate utilization statistic for a single utilization metric
    private static func calculateUtilizationStatistic(_ values: [Double]) -> UtilizationStatistic {
        let n = values.count
        let sortedValues = values.sorted()
        
        let mean = values.reduce(0, +) / Double(n)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(n - 1)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = standardDeviation / mean
        
        let median = calculatePercentile(sortedValues, 50.0)
        
        return UtilizationStatistic(
            mean: mean,
            standardDeviation: standardDeviation,
            min: sortedValues.first!,
            max: sortedValues.last!,
            median: median,
            coefficientOfVariation: coefficientOfVariation
        )
    }
    
    /// Compare two performance datasets statistically
    static func compare(baseline: [Double], current: [Double], significanceLevel: Double = 0.05) -> ComparisonResult {
        let baselineStats = calculateStatistics(baseline)
        let currentStats = calculateStatistics(current)
        
        let meanDifference = currentStats.mean - baselineStats.mean
        let meanDifferencePercent = (meanDifference / baselineStats.mean) * 100
        
        // Two-sample t-test for unequal variances (Welch's t-test)
        let isSignificant = performWelchTTest(baseline: baseline, current: current, significanceLevel: significanceLevel)
        
        // Confidence interval for the difference
        let pooledStdError = sqrt(
            (baselineStats.standardDeviation * baselineStats.standardDeviation / Double(baseline.count)) +
            (currentStats.standardDeviation * currentStats.standardDeviation / Double(current.count))
        )
        let tValue = tDistributionValue(degreesOfFreedom: min(baseline.count, current.count) - 1, confidenceLevel: 1 - significanceLevel)
        let marginOfError = tValue * pooledStdError
        let confidenceInterval = (meanDifference - marginOfError, meanDifference + marginOfError)
        
        return ComparisonResult(
            baselineStats: baselineStats,
            currentStats: currentStats,
            meanDifference: meanDifference,
            meanDifferencePercent: meanDifferencePercent,
            confidenceInterval: ConfidenceInterval(lower: confidenceInterval.0, upper: confidenceInterval.1),
            isSignificant: isSignificant,
            significanceLevel: significanceLevel
        )
    }
    
    // MARK: - Helper Functions
    
    /// Calculate percentile from sorted array
    private static func calculatePercentile(_ sortedValues: [Double], _ percentile: Double) -> Double {
        let n = sortedValues.count
        let index = (percentile / 100.0) * Double(n - 1)
        
        if index.truncatingRemainder(dividingBy: 1) == 0 {
            // Exact index
            return sortedValues[Int(index)]
        } else {
            // Interpolate between two values
            let lowerIndex = Int(index.rounded(.down))
            let upperIndex = min(lowerIndex + 1, n - 1)
            let weight = index - Double(lowerIndex)
            
            return sortedValues[lowerIndex] * (1 - weight) + sortedValues[upperIndex] * weight
        }
    }
    
    /// Approximate t-distribution critical value
    private static func tDistributionValue(degreesOfFreedom: Int, confidenceLevel: Double) -> Double {
        // Simplified approximation for common confidence levels
        // For production use, consider using a proper statistical library
        let df = Double(degreesOfFreedom)
        
        if confidenceLevel == 0.95 {
            if df >= 30 {
                return 1.96 // Normal approximation
            } else if df >= 10 {
                return 2.228
            } else if df >= 5 {
                return 2.571
            } else {
                return 2.776
            }
        } else if confidenceLevel == 0.99 {
            if df >= 30 {
                return 2.576
            } else if df >= 10 {
                return 3.169
            } else if df >= 5 {
                return 4.032
            } else {
                return 4.604
            }
        }
        
        // Default to 95% confidence
        return 2.0
    }
    
    /// Perform Welch's t-test for unequal variances
    private static func performWelchTTest(baseline: [Double], current: [Double], significanceLevel: Double) -> Bool {
        let baselineStats = calculateStatistics(baseline)
        let currentStats = calculateStatistics(current)
        
        // Calculate Welch's t-statistic
        let se1 = baselineStats.standardDeviation / sqrt(Double(baseline.count))
        let se2 = currentStats.standardDeviation / sqrt(Double(current.count))
        let pooledSE = sqrt(se1 * se1 + se2 * se2)
        
        let tStatistic = (baselineStats.mean - currentStats.mean) / pooledSE
        
        // Degrees of freedom for Welch's t-test
        let df = pow(se1 * se1 + se2 * se2, 2) / 
                (pow(se1 * se1, 2) / Double(baseline.count - 1) + pow(se2 * se2, 2) / Double(current.count - 1))
        
        let criticalValue = tDistributionValue(degreesOfFreedom: Int(df), confidenceLevel: 1 - significanceLevel)
        
        return abs(tStatistic) > criticalValue
    }
}
