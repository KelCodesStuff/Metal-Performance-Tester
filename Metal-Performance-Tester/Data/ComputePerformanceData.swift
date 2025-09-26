//
//  ComputePerformanceData.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Foundation

// MARK: - Compute Performance Result

/// Represents a compute performance measurement result
struct ComputeResult: Codable {
    /// GPU execution time in milliseconds
    let gpuTimeMs: Double
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Device information for context
    let deviceName: String
    
    /// Test configuration details
    let testConfig: TestConfiguration
    
    /// Compute utilization metrics (if available)
    let computeUtilization: ComputeUtilizationMetrics?
    
    /// General statistics (if available)
    let statistics: GeneralStatistics?
    
    /// Creates a new compute result
    init(gpuTimeMs: Double, deviceName: String, testConfig: TestConfiguration, 
         computeUtilization: ComputeUtilizationMetrics? = nil, 
         statistics: GeneralStatistics? = nil) {
        self.gpuTimeMs = gpuTimeMs
        self.timestamp = Date()
        self.deviceName = deviceName
        self.testConfig = testConfig
        self.computeUtilization = computeUtilization
        self.statistics = statistics
    }
}

// MARK: - Compute Utilization Metrics

/// Represents compute-specific utilization metrics
struct ComputeUtilizationMetrics: Codable {
    /// Compute shader utilization percentage
    let computeUtilization: Double?
    
    /// Memory utilization percentage
    let memoryUtilization: Double?
    
    /// Total utilization percentage
    let totalUtilization: Double?
    
    /// Memory bandwidth utilization percentage
    let memoryBandwidthUtilization: Double?
    
    /// Threadgroup efficiency percentage
    let threadgroupEfficiency: Double?
    
    /// Instructions per second
    let instructionsPerSecond: Double?
    
    /// Creates new compute utilization metrics
    init(computeUtilization: Double? = nil, memoryUtilization: Double? = nil, 
         totalUtilization: Double? = nil, memoryBandwidthUtilization: Double? = nil,
         threadgroupEfficiency: Double? = nil, instructionsPerSecond: Double? = nil) {
        self.computeUtilization = computeUtilization
        self.memoryUtilization = memoryUtilization
        self.totalUtilization = totalUtilization
        self.memoryBandwidthUtilization = memoryBandwidthUtilization
        self.threadgroupEfficiency = threadgroupEfficiency
        self.instructionsPerSecond = instructionsPerSecond
    }
}

// MARK: - Compute Performance Measurement Set

/// Represents a collection of compute performance measurements with statistical analysis
struct ComputeMeasurementSet: Codable {
    /// Individual compute measurement results
    let individualResults: [ComputeResult]
    
    /// Statistical analysis of the measurements
    let statistics: StatisticalAnalysis.PerformanceStatistics
    
    /// Compute utilization statistics (if available)
    let computeUtilizationStatistics: StatisticalAnalysis.ComputeUtilizationStatistics?
    
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
    
    /// Creates a new compute measurement set from individual results
    init(individualResults: [ComputeResult]) {
        guard !individualResults.isEmpty else {
            fatalError("Cannot create ComputeMeasurementSet from empty results")
        }
        
        self.individualResults = individualResults
        self.deviceName = individualResults.first!.deviceName
        self.testConfig = individualResults.first!.testConfig
        self.timestamp = Date()
        
        // Calculate statistics from GPU times
        let gpuTimes = individualResults.map { $0.gpuTimeMs }
        self.statistics = StatisticalAnalysis.calculateStatistics(gpuTimes)
        
        // Calculate compute utilization statistics
        self.computeUtilizationStatistics = StatisticalAnalysis.calculateComputeUtilizationStatistics(from: individualResults)
    }
    
    /// Creates a compute measurement set with a single result
    init(singleResult: ComputeResult) {
        self.individualResults = [singleResult]
        self.deviceName = singleResult.deviceName
        self.testConfig = singleResult.testConfig
        self.timestamp = Date()
        
        // For single result, statistics are trivial
        self.statistics = StatisticalAnalysis.calculateStatistics([singleResult.gpuTimeMs])
        
        // Calculate compute utilization statistics for single result
        self.computeUtilizationStatistics = StatisticalAnalysis.calculateComputeUtilizationStatistics(from: [singleResult])
    }
    
    var summary: String {
        var result = """
        Compute Measurement Summary:
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
            if let computeUtil = computeUtilizationStatistics {
                var result = "Compute Utilization:\n"
                if let compute = computeUtil.computeUtilization {
                    result += "- Average Compute Utilization: \(String(format: "%.1f", compute.mean))%\n"
                }
                if let memory = computeUtil.memoryUtilization {
                    result += "- Average Memory Utilization: \(String(format: "%.1f", memory.mean))%\n"
                }
                if let total = computeUtil.totalUtilization {
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


// MARK: - Compute Test Result

/// Represents the result of a compute performance test comparison
struct ComputeTestResult: Codable {
    /// Current compute performance measurement set
    let current: ComputeMeasurementSet
    
    /// Baseline compute performance measurement set
    let baseline: ComputeMeasurementSet
    
    /// Statistical comparison result
    let comparison: StatisticalAnalysis.ComparisonResult
    
    /// Test configuration used
    let testConfig: TestConfiguration
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Creates a new compute test result
    init(current: ComputeMeasurementSet, baseline: ComputeMeasurementSet, 
         comparison: StatisticalAnalysis.ComparisonResult) {
        self.current = current
        self.baseline = baseline
        self.comparison = comparison
        self.testConfig = current.testConfig
        self.timestamp = Date()
    }
}
