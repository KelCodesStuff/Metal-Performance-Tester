//
//  UnifiedPerformanceData.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/26/25.
//

import Foundation

// MARK: - Backward Compatibility Type Aliases

/// Backward compatibility alias for PerformanceResult
typealias PerformanceResult = UnifiedPerformanceResult

/// Backward compatibility alias for PerformanceMeasurementSet  
typealias PerformanceMeasurementSet = UnifiedPerformanceMeasurementSet

/// Backward compatibility alias for GraphicsResult
typealias GraphicsResult = UnifiedPerformanceResult

/// Backward compatibility alias for GraphicsMeasurementSet
typealias GraphicsMeasurementSet = UnifiedPerformanceMeasurementSet

/// Backward compatibility alias for ComputeResult
typealias ComputeResult = UnifiedPerformanceResult

/// Backward compatibility alias for ComputeMeasurementSet
typealias ComputeMeasurementSet = UnifiedPerformanceMeasurementSet

// MARK: - Compute Utilization Metrics

/// Represents compute-specific utilization metrics
struct ComputeUtilizationMetrics: Codable {
    /// Compute unit utilization percentage
    let computeUtilization: Double
    
    /// Memory utilization percentage
    let memoryUtilization: Double
    
    /// Total utilization percentage
    let totalUtilization: Double
    
    /// Memory bandwidth utilization percentage
    let memoryBandwidthUtilization: Double
    
    /// Threadgroup efficiency percentage
    let threadgroupEfficiency: Double
    
    /// Instructions per second
    let instructionsPerSecond: Double
}

// MARK: - Unified Performance Result

/// Represents a performance measurement result that can handle both graphics and compute workloads
struct UnifiedPerformanceResult: Codable {
    /// GPU execution time in milliseconds
    let gpuTimeMs: Double
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Device information for context
    let deviceName: String
    
    /// Test configuration details
    let testConfig: TestConfiguration
    
    /// Test type (graphics or compute)
    let testType: TestType
    
    /// Graphics-specific utilization metrics (if available)
    let stageUtilization: StageUtilizationMetrics?
    
    /// Compute-specific utilization metrics (if available)
    let computeUtilization: ComputeUtilizationMetrics?
    
    /// General statistics (if available)
    let statistics: GeneralStatistics?
    
    /// Creates a new unified performance result
    init(gpuTimeMs: Double, deviceName: String, testConfig: TestConfiguration, 
         testType: TestType, stageUtilization: StageUtilizationMetrics? = nil,
         computeUtilization: ComputeUtilizationMetrics? = nil, 
         statistics: GeneralStatistics? = nil) {
        self.gpuTimeMs = gpuTimeMs
        self.timestamp = Date()
        self.deviceName = deviceName
        self.testConfig = testConfig
        self.testType = testType
        self.stageUtilization = stageUtilization
        self.computeUtilization = computeUtilization
        self.statistics = statistics
    }
    
    /// Convenience initializer for graphics results
    static func graphics(gpuTimeMs: Double, deviceName: String, testConfig: TestConfiguration,
                         stageUtilization: StageUtilizationMetrics? = nil,
                         statistics: GeneralStatistics? = nil) -> UnifiedPerformanceResult {
        return UnifiedPerformanceResult(
            gpuTimeMs: gpuTimeMs,
            deviceName: deviceName,
            testConfig: testConfig,
            testType: .graphics,
            stageUtilization: stageUtilization,
            computeUtilization: nil,
            statistics: statistics
        )
    }
    
    /// Convenience initializer for compute results
    static func compute(gpuTimeMs: Double, deviceName: String, testConfig: TestConfiguration,
                        computeUtilization: ComputeUtilizationMetrics? = nil,
                        statistics: GeneralStatistics? = nil) -> UnifiedPerformanceResult {
        return UnifiedPerformanceResult(
            gpuTimeMs: gpuTimeMs,
            deviceName: deviceName,
            testConfig: testConfig,
            testType: .compute,
            stageUtilization: nil,
            computeUtilization: computeUtilization,
            statistics: statistics
        )
    }
}

// MARK: - Unified Performance Measurement Set

/// Represents a collection of performance measurements with statistical analysis
struct UnifiedPerformanceMeasurementSet: Codable {
    /// Individual performance measurement results
    let individualResults: [UnifiedPerformanceResult]
    
    /// Statistical analysis of the measurements
    let statistics: StatisticalAnalysis.PerformanceStatistics
    
    /// Stage utilization statistics (if available for graphics tests)
    let stageUtilizationStatistics: StatisticalAnalysis.StageUtilizationStatistics?
    
    /// Compute utilization statistics (if available for compute tests)
    let computeUtilizationStatistics: StatisticalAnalysis.ComputeUtilizationStatistics?
    
    /// Device information (consistent across all measurements)
    let deviceName: String
    
    /// Test configuration (consistent across all measurements)
    let testConfig: TestConfiguration
    
    /// Test type (graphics or compute)
    let testType: TestType
    
    /// Timestamp when the measurement set was created
    let timestamp: Date
    
    /// Number of iterations performed
    let iterationCount: Int
    
    /// Average GPU time in milliseconds (computed property)
    var averageGpuTimeMs: Double {
        return statistics.mean
    }
    
    /// Creates a new unified performance measurement set
    init(individualResults: [UnifiedPerformanceResult]) {
        self.individualResults = individualResults
        self.deviceName = individualResults.first?.deviceName ?? "Unknown"
        self.testConfig = individualResults.first?.testConfig ?? TestConfiguration()
        self.testType = individualResults.first?.testType ?? .graphics
        self.timestamp = Date()
        self.iterationCount = individualResults.count
        
        // Calculate statistics
        let gpuTimes = individualResults.map { $0.gpuTimeMs }
        self.statistics = StatisticalAnalysis.calculateStatistics(gpuTimes)
        
        // Calculate stage utilization statistics for graphics tests
        if testType == .graphics {
            self.stageUtilizationStatistics = StatisticalAnalysis.calculateStageUtilizationStatistics(
                from: individualResults.filter { $0.stageUtilization != nil }.map { result in
                    PerformanceResult(
                        gpuTimeMs: result.gpuTimeMs,
                        deviceName: result.deviceName,
                        testConfig: result.testConfig,
                        testType: .graphics,
                        stageUtilization: result.stageUtilization!,
                        statistics: result.statistics
                    )
                }
            )
            self.computeUtilizationStatistics = nil
        } else {
            // Calculate compute utilization statistics for compute tests
            self.computeUtilizationStatistics = StatisticalAnalysis.calculateComputeUtilizationStatistics(
                from: individualResults.filter { $0.computeUtilization != nil }.map { result in
                    ComputeResult(
                        gpuTimeMs: result.gpuTimeMs,
                        deviceName: result.deviceName,
                        testConfig: result.testConfig,
                        testType: .compute,
                        computeUtilization: result.computeUtilization!,
                        statistics: result.statistics
                    )
                }
            )
            self.stageUtilizationStatistics = nil
        }
    }
    
    /// Creates a performance measurement set with a single result
    init(singleResult: UnifiedPerformanceResult) {
        self.individualResults = [singleResult]
        self.deviceName = singleResult.deviceName
        self.testConfig = singleResult.testConfig
        self.testType = singleResult.testType
        self.timestamp = Date()
        self.iterationCount = 1
        
        // For single result, statistics are trivial
        self.statistics = StatisticalAnalysis.calculateStatistics([singleResult.gpuTimeMs])
        
        // Calculate utilization statistics for single result
        if testType == .graphics, let stageUtil = singleResult.stageUtilization {
            self.stageUtilizationStatistics = StatisticalAnalysis.calculateStageUtilizationStatistics(
                from: [PerformanceResult(
                    gpuTimeMs: singleResult.gpuTimeMs,
                    deviceName: singleResult.deviceName,
                    testConfig: singleResult.testConfig,
                    testType: .graphics,
                    stageUtilization: stageUtil,
                    statistics: singleResult.statistics
                )]
            )
            self.computeUtilizationStatistics = nil
        } else if testType == .compute, let computeUtil = singleResult.computeUtilization {
            self.computeUtilizationStatistics = StatisticalAnalysis.calculateComputeUtilizationStatistics(
                from: [ComputeResult(
                    gpuTimeMs: singleResult.gpuTimeMs,
                    deviceName: singleResult.deviceName,
                    testConfig: singleResult.testConfig,
                    testType: .compute,
                    computeUtilization: computeUtil,
                    statistics: singleResult.statistics
                )]
            )
            self.stageUtilizationStatistics = nil
        } else {
            self.stageUtilizationStatistics = nil
            self.computeUtilizationStatistics = nil
        }
    }
    
    var summary: String {
        var result = """
        Performance Measurement Summary:
        - Iterations: \(iterationCount)
        - Device: \(deviceName)
        - Test Type: \(testType.rawValue.capitalized)
        - Configuration: \(testConfig.description)
        
        Statistical Analysis:
        - Average: \(String(format: "%.3f", statistics.mean)) ms
        - Standard Deviation: \(String(format: "%.3f", statistics.standardDeviation)) ms
        - Range: \(String(format: "%.3f", statistics.min)) - \(String(format: "%.3f", statistics.max)) ms
        - Median: \(String(format: "%.3f", statistics.median)) ms
        - Coefficient of Variation: \(String(format: "%.1f", statistics.coefficientOfVariation * 100))%
        - Quality: \(statistics.qualityRating.rawValue)
        
        """
        
        // Add utilization statistics based on test type
        if testType == .graphics, let stageUtil = stageUtilizationStatistics {
            result += "Stage Utilization:\n"
            if let vertex = stageUtil.vertexUtilization {
                result += "- Average Vertex Utilization: \(String(format: "%.1f", vertex.mean))%\n"
            }
            if let fragment = stageUtil.fragmentUtilization {
                result += "- Average Fragment Utilization: \(String(format: "%.1f", fragment.mean))%\n"
            }
            if let total = stageUtil.totalUtilization {
                result += "- Average Total Utilization: \(String(format: "%.1f", total.mean))%\n"
            }
        } else if testType == .compute, let computeUtil = computeUtilizationStatistics {
            result += "Compute Utilization:\n"
            if let compute = computeUtil.computeUtilization {
                result += "- Average Compute Utilization: \(String(format: "%.1f", compute.mean))%\n"
            }
            if let memory = computeUtil.memoryUtilization {
                result += "- Average Memory Utilization: \(String(format: "%.1f", memory.mean))%\n"
            }
            if let total = computeUtil.totalUtilization {
                result += "- Average Total Utilization: \(String(format: "%.1f", total.mean))%\n"
            }
        }
        
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

// MARK: - Unified Test Result

/// Represents the result of a performance test comparison
struct UnifiedPerformanceTestResult: Codable {
    /// Current performance measurement set
    let current: UnifiedPerformanceMeasurementSet
    
    /// Baseline performance measurement set
    let baseline: UnifiedPerformanceMeasurementSet
    
    /// Statistical comparison result
    let comparison: StatisticalAnalysis.ComparisonResult
    
    /// Test configuration used
    let testConfig: TestConfiguration
    
    /// Test type (graphics or compute)
    let testType: TestType
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Creates a new unified performance test result
    init(current: UnifiedPerformanceMeasurementSet, baseline: UnifiedPerformanceMeasurementSet, 
         comparison: StatisticalAnalysis.ComparisonResult) {
        self.current = current
        self.baseline = baseline
        self.comparison = comparison
        self.testConfig = current.testConfig
        self.testType = current.testType
        self.timestamp = Date()
    }
}
