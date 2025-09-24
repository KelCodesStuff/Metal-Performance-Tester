//
//  StatisticalAnalysis.swift
//  Metal-Performance-Tester
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
        
    }
    
    /// Statistical analysis for stage utilization metrics
    struct StageUtilizationStatistics: Codable {
        let vertexUtilization: UtilizationStatistic?
        let fragmentUtilization: UtilizationStatistic?
        let totalUtilization: UtilizationStatistic?
        let sampleCount: Int
        
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
        /// Percentage difference between current and baseline (already multiplied by 100, e.g., 0.42 represents 0.42%)
        /// DO NOT multiply by 100 when formatting - this value is already a percentage
        let meanDifferencePercent: Double
        let confidenceInterval: ConfidenceInterval
        let isSignificant: Bool
        let significanceLevel: Double
        
        /// Stage utilization comparison (if available)
        let stageUtilizationComparison: StageUtilizationComparison?
        
        /// Performance statistics comparison (if available)
        let performanceStatsComparison: PerformanceStatsComparison?
        
        /// Determines if there's a performance regression
        var isRegression: Bool {
            return isSignificant && meanDifference > 0
        }
        
        /// Determines if there's a performance improvement
        var isImprovement: Bool {
            return isSignificant && meanDifference < 0
        }
        
    }
    
    /// Stage utilization comparison between baseline and current
    struct StageUtilizationComparison: Codable {
        let vertexUtilization: UtilizationComparison?
        let fragmentUtilization: UtilizationComparison?
        let totalUtilization: UtilizationComparison?
        
    }
    
    /// Individual utilization comparison
    struct UtilizationComparison: Codable {
        let baseline: Double
        let current: Double
        let change: Double  // current - baseline
        let changePercent: Double  // (change / baseline) * 100
    }
    
    /// Performance statistics comparison between baseline and current
    struct PerformanceStatsComparison: Codable {
        let memoryBandwidth: PerformanceStatComparison?
        let cacheHits: PerformanceStatComparison?
        let cacheMisses: PerformanceStatComparison?
        let cacheHitRate: PerformanceStatComparison?
        let instructionsExecuted: PerformanceStatComparison?
        
    }
    
    /// Individual performance statistic comparison
    struct PerformanceStatComparison: Codable {
        let baseline: Double
        let current: Double
        let change: Double  // current - baseline
        let changePercent: Double  // (change / baseline) * 100
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
        // Calculate percentage difference (already multiplied by 100 to get percentage value)
        // This value is ready for display as a percentage (e.g., 0.42 represents 0.42%)
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
            significanceLevel: significanceLevel,
            stageUtilizationComparison: nil,
            performanceStatsComparison: nil
        )
    }
    
    /// Compare two performance measurement sets with comprehensive analysis
    static func compare(baseline: PerformanceMeasurementSet, current: PerformanceMeasurementSet, significanceLevel: Double = 0.05) -> ComparisonResult {
        let baselineTimes = baseline.individualResults.map { $0.gpuTimeMs }
        let currentTimes = current.individualResults.map { $0.gpuTimeMs }
        
        let baselineStats = calculateStatistics(baselineTimes)
        let currentStats = calculateStatistics(currentTimes)
        
        let meanDifference = currentStats.mean - baselineStats.mean
        // Calculate percentage difference (already multiplied by 100 to get percentage value)
        // This value is ready for display as a percentage (e.g., 0.42 represents 0.42%)
        let meanDifferencePercent = (meanDifference / baselineStats.mean) * 100
        
        // Two-sample t-test for unequal variances (Welch's t-test)
        let isSignificant = performWelchTTest(baseline: baselineTimes, current: currentTimes, significanceLevel: significanceLevel)
        
        // Confidence interval for the difference
        let pooledStdError = sqrt(
            (baselineStats.standardDeviation * baselineStats.standardDeviation / Double(baselineTimes.count)) +
            (currentStats.standardDeviation * currentStats.standardDeviation / Double(currentTimes.count))
        )
        let tValue = tDistributionValue(degreesOfFreedom: min(baselineTimes.count, currentTimes.count) - 1, confidenceLevel: 1 - significanceLevel)
        let marginOfError = tValue * pooledStdError
        let confidenceInterval = (meanDifference - marginOfError, meanDifference + marginOfError)
        
        // Calculate stage utilization comparison
        let stageUtilizationComparison = calculateStageUtilizationComparison(baseline: baseline, current: current)
        
        // Calculate performance statistics comparison
        let performanceStatsComparison = calculatePerformanceStatsComparison(baseline: baseline, current: current)
        
        return ComparisonResult(
            baselineStats: baselineStats,
            currentStats: currentStats,
            meanDifference: meanDifference,
            meanDifferencePercent: meanDifferencePercent,
            confidenceInterval: ConfidenceInterval(lower: confidenceInterval.0, upper: confidenceInterval.1),
            isSignificant: isSignificant,
            significanceLevel: significanceLevel,
            stageUtilizationComparison: stageUtilizationComparison,
            performanceStatsComparison: performanceStatsComparison
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
    
    /// Calculate stage utilization comparison between baseline and current
    private static func calculateStageUtilizationComparison(baseline: PerformanceMeasurementSet, current: PerformanceMeasurementSet) -> StageUtilizationComparison? {
        guard let baselineUtilization = baseline.stageUtilizationStatistics,
              let currentUtilization = current.stageUtilizationStatistics else {
            return nil
        }
        
        let vertexComparison = createUtilizationComparison(
            baseline: baselineUtilization.vertexUtilization?.mean,
            current: currentUtilization.vertexUtilization?.mean
        )
        
        let fragmentComparison = createUtilizationComparison(
            baseline: baselineUtilization.fragmentUtilization?.mean,
            current: currentUtilization.fragmentUtilization?.mean
        )
        
        let totalComparison = createUtilizationComparison(
            baseline: baselineUtilization.totalUtilization?.mean,
            current: currentUtilization.totalUtilization?.mean
        )
        
        return StageUtilizationComparison(
            vertexUtilization: vertexComparison,
            fragmentUtilization: fragmentComparison,
            totalUtilization: totalComparison
        )
    }
    
    /// Calculate performance statistics comparison between baseline and current
    private static func calculatePerformanceStatsComparison(baseline: PerformanceMeasurementSet, current: PerformanceMeasurementSet) -> PerformanceStatsComparison? {
        // Extract performance statistics from individual results
        let baselineStats = extractPerformanceStats(from: baseline.individualResults)
        let currentStats = extractPerformanceStats(from: current.individualResults)
        
        let memoryBandwidthComparison = createPerformanceStatComparison(
            baseline: baselineStats.memoryBandwidth,
            current: currentStats.memoryBandwidth
        )
        
        let cacheHitRateComparison = createPerformanceStatComparison(
            baseline: baselineStats.cacheHitRate,
            current: currentStats.cacheHitRate
        )
        
        let cacheHitsComparison = createPerformanceStatComparison(
            baseline: baselineStats.cacheHits,
            current: currentStats.cacheHits
        )
        
        let cacheMissesComparison = createPerformanceStatComparison(
            baseline: baselineStats.cacheMisses,
            current: currentStats.cacheMisses
        )
        
        let instructionsComparison = createPerformanceStatComparison(
            baseline: baselineStats.instructionsExecuted,
            current: currentStats.instructionsExecuted
        )
        
        return PerformanceStatsComparison(
            memoryBandwidth: memoryBandwidthComparison,
            cacheHits: cacheHitsComparison,
            cacheMisses: cacheMissesComparison,
            cacheHitRate: cacheHitRateComparison,
            instructionsExecuted: instructionsComparison
        )
    }
    
    /// Extract performance statistics from individual results
    private static func extractPerformanceStats(from results: [PerformanceResult]) -> (memoryBandwidth: Double?, cacheHits: Double?, cacheMisses: Double?, cacheHitRate: Double?, instructionsExecuted: Double?) {
        let memoryBandwidths = results.compactMap { $0.statistics?.memoryBandwidth }
        let cacheHits = results.compactMap { $0.statistics?.cacheHits }
        let cacheMisses = results.compactMap { $0.statistics?.cacheMisses }
        let cacheHitRates = results.compactMap { $0.statistics?.cacheHitRate }
        let instructions = results.compactMap { $0.statistics?.instructionsExecuted }
        
        let avgMemoryBandwidth = memoryBandwidths.isEmpty ? nil : memoryBandwidths.reduce(0, +) / Double(memoryBandwidths.count)
        let avgCacheHits = cacheHits.isEmpty ? nil : cacheHits.reduce(0, +) / Double(cacheHits.count)
        let avgCacheMisses = cacheMisses.isEmpty ? nil : cacheMisses.reduce(0, +) / Double(cacheMisses.count)
        let avgCacheHitRate = cacheHitRates.isEmpty ? nil : cacheHitRates.reduce(0, +) / Double(cacheHitRates.count)
        let avgInstructions = instructions.isEmpty ? nil : instructions.reduce(0, +) / Double(instructions.count)
        
        return (avgMemoryBandwidth, avgCacheHits, avgCacheMisses, avgCacheHitRate, avgInstructions)
    }
    
    /// Create utilization comparison from baseline and current values
    private static func createUtilizationComparison(baseline: Double?, current: Double?) -> UtilizationComparison? {
        guard let baseline = baseline, let current = current else { return nil }
        
        let change = current - baseline
        let changePercent = baseline != 0 ? (change / baseline) * 100 : 0
        
        return UtilizationComparison(
            baseline: baseline,
            current: current,
            change: change,
            changePercent: changePercent
        )
    }
    
    /// Create performance statistic comparison from baseline and current values
    private static func createPerformanceStatComparison(baseline: Double?, current: Double?) -> PerformanceStatComparison? {
        guard let baseline = baseline, let current = current else { return nil }
        
        let change = current - baseline
        let changePercent = baseline != 0 ? (change / baseline) * 100 : 0
        
        return PerformanceStatComparison(
            baseline: baseline,
            current: current,
            change: change,
            changePercent: changePercent
        )
    }
}
