//
//  SharedPerformanceData.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Foundation

// MARK: - Shared Performance Result

/// Represents a general performance measurement result
struct PerformanceResult: Codable {
    /// GPU execution time in milliseconds
    let gpuTimeMs: Double
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Device information for context
    let deviceName: String
    
    /// Test configuration details
    let testConfig: TestConfiguration
    
    /// Stage utilization metrics (if available)
    let stageUtilization: StageUtilizationMetrics?
    
    /// General statistics (if available)
    let statistics: GeneralStatistics?
    
    /// Creates a new performance result
    init(gpuTimeMs: Double, deviceName: String, testConfig: TestConfiguration, 
         stageUtilization: StageUtilizationMetrics? = nil, 
         statistics: GeneralStatistics? = nil) {
        self.gpuTimeMs = gpuTimeMs
        self.timestamp = Date()
        self.deviceName = deviceName
        self.testConfig = testConfig
        self.stageUtilization = stageUtilization
        self.statistics = statistics
    }
}

// MARK: - Shared Performance Measurement Set

/// Represents a collection of performance measurements with statistical analysis
struct PerformanceMeasurementSet: Codable {
    /// Individual performance measurement results
    let individualResults: [PerformanceResult]
    
    /// Statistical analysis of the measurements
    let statistics: StatisticalAnalysis.PerformanceStatistics
    
    /// Stage utilization statistics (if available)
    let stageUtilizationStatistics: StatisticalAnalysis.StageUtilizationStatistics?
    
    /// Device information (consistent across all measurements)
    let deviceName: String
    
    /// Test configuration (consistent across all measurements)
    let testConfig: TestConfiguration
    
    /// Timestamp when the measurement set was created
    let timestamp: Date
    
    /// Number of iterations performed
    var iterationCount: Int {
        return individualResults.count
    }
    
    /// Average GPU time (convenience property)
    var averageGpuTimeMs: Double {
        return statistics.mean
    }
    
    /// Quality rating based on coefficient of variation
    var qualityRating: StatisticalAnalysis.QualityRating {
        return statistics.qualityRating
    }
    
    /// Creates a new performance measurement set from individual results
    init(individualResults: [PerformanceResult]) {
        guard !individualResults.isEmpty else {
            fatalError("Cannot create PerformanceMeasurementSet from empty results")
        }
        
        self.individualResults = individualResults
        self.deviceName = individualResults.first!.deviceName
        self.testConfig = individualResults.first!.testConfig
        self.timestamp = Date()
        
        // Calculate statistics from GPU times
        let gpuTimes = individualResults.map { $0.gpuTimeMs }
        self.statistics = StatisticalAnalysis.calculateStatistics(gpuTimes)
        
        // Calculate stage utilization statistics
        self.stageUtilizationStatistics = StatisticalAnalysis.calculateStageUtilizationStatistics(from: individualResults)
    }
    
    /// Creates a performance measurement set with a single result
    init(singleResult: PerformanceResult) {
        self.individualResults = [singleResult]
        self.deviceName = singleResult.deviceName
        self.testConfig = singleResult.testConfig
        self.timestamp = Date()
        
        // For single result, statistics are trivial
        self.statistics = StatisticalAnalysis.calculateStatistics([singleResult.gpuTimeMs])
        
        // Calculate stage utilization statistics for single result
        self.stageUtilizationStatistics = StatisticalAnalysis.calculateStageUtilizationStatistics(from: [singleResult])
    }
    
    var summary: String {
        var result = """
        Performance Measurement Summary:
        - Iterations: \(iterationCount)
        - Device: \(deviceName)
        - Configuration: \(testConfig.description)
        
        Statistical Analysis:
        - Average: \(String(format: "%.3f", statistics.mean)) ms
        - Standard Deviation: \(String(format: "%.3f", statistics.standardDeviation)) ms
        - Range: \(String(format: "%.3f", statistics.min)) - \(String(format: "%.3f", statistics.max)) ms
        - Median: \(String(format: "%.3f", statistics.median)) ms
        - Coefficient of Variation: \(String(format: "%.1f", statistics.coefficientOfVariation * 100))%
        - Quality: \(statistics.qualityRating.rawValue)
        
        \({
            if let stageUtil = stageUtilizationStatistics {
                var result = "Stage Utilization:\n"
                if let vertex = stageUtil.vertexUtilization {
                    result += "- Average Vertex Utilization: \(String(format: "%.1f", vertex.mean))%\n"
                }
                if let fragment = stageUtil.fragmentUtilization {
                    result += "- Average Fragment Utilization: \(String(format: "%.1f", fragment.mean))%\n"
                }
                if let total = stageUtil.totalUtilization {
                    result += "- Average Total Utilization: \(String(format: "%.1f", total.mean))%\n"
                }
                return result
            }
            return ""
        }())
        """
        
        // Add performance statistics from the last result
        if let lastResult = individualResults.last,
           let stats = lastResult.statistics {
            result += "\n\nPerformance Statistics:"
            if let bandwidth = stats.memoryBandwidth {
                result += "\n- Memory Bandwidth: \(String(format: "%.1f", bandwidth)) MB/s"
            }
            if let instructions = stats.instructionsExecuted {
                result += "\n- Instructions Executed: \(String(format: "%.0f", instructions))"
            }
        }
        
        return result
    }
}

// MARK: - Shared Test Result

/// Represents the result of a performance test comparison
struct PerformanceTestResult: Codable {
    /// Current performance measurement set
    let current: PerformanceMeasurementSet
    
    /// Baseline performance measurement set
    let baseline: PerformanceMeasurementSet
    
    /// Statistical comparison result
    let comparison: StatisticalAnalysis.ComparisonResult
    
    /// Test configuration used
    let testConfig: TestConfiguration
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Creates a new performance test result
    init(current: PerformanceMeasurementSet, baseline: PerformanceMeasurementSet, 
         comparison: StatisticalAnalysis.ComparisonResult) {
        self.current = current
        self.baseline = baseline
        self.comparison = comparison
        self.testConfig = current.testConfig
        self.timestamp = Date()
    }
}
