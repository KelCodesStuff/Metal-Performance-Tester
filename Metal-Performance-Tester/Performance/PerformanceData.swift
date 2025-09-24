//
//  PerformanceData.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation

// Represents a performance measurement result from a GPU rendering test
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

// Represents a collection of performance measurements with statistical analysis
struct PerformanceMeasurementSet: Codable {
    /// Individual measurement results
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
    
    /// Creates a performance measurement set with a single result (backward compatibility)
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
        Measurement Summary:
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
        
        \(stageUtilizationStatistics != nil ? "Stage Utilization:" : "")
        \(stageUtilizationStatistics?.vertexUtilization != nil ? "- Average Vertex Utilization: \(String(format: "%.1f", stageUtilizationStatistics!.vertexUtilization!.mean))%" : "")
        \(stageUtilizationStatistics?.fragmentUtilization != nil ? "- Average Fragment Utilization: \(String(format: "%.1f", stageUtilizationStatistics!.fragmentUtilization!.mean))%" : "")
        \(stageUtilizationStatistics?.totalUtilization != nil ? "- Average Total Utilization: \(String(format: "%.1f", stageUtilizationStatistics!.totalUtilization!.mean))%" : "")
        """
        
        // Add performance statistics from the last result
        if let lastResult = individualResults.last,
           let stats = lastResult.statistics {
            result += "\n\nPerformance Statistics:"
            if let bandwidth = stats.memoryBandwidth {
                result += "\n- Memory Bandwidth: \(String(format: "%.1f", bandwidth)) MB/s"
            }
            if let cacheHits = stats.cacheHits {
                result += "\n- Cache Hits: \(String(format: "%.0f", cacheHits))"
            }
            if let cacheMisses = stats.cacheMisses {
                result += "\n- Cache Misses: \(String(format: "%.0f", cacheMisses))"
            }
            if let hitRate = stats.cacheHitRate {
                result += "\n- Cache Hit Rate: \(String(format: "%.1f", hitRate * 100))%"
            }
            if let instructions = stats.instructionsExecuted {
                result += "\n- Instructions Executed: \(String(format: "%.0f", instructions))"
            }
        }
        
        return result
    }
}

// Represents a complete test result including current measurements, baseline comparison, and statistical analysis
struct PerformanceTestResult: Codable {
    /// Current performance measurement set
    let currentMeasurementSet: PerformanceMeasurementSet
    
    /// Baseline performance measurement set used for comparison
    let baselineMeasurementSet: PerformanceMeasurementSet
    
    /// Statistical comparison result
    let comparisonResult: StatisticalAnalysis.ComparisonResult
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Test configuration used for the test
    var testConfig: TestConfiguration {
        return currentMeasurementSet.testConfig
    }
    
    /// Device name where the test was run
    var deviceName: String {
        return currentMeasurementSet.deviceName
    }
    
    /// Whether the test detected a performance regression
    var isRegression: Bool {
        return comparisonResult.isRegression
    }
    
    /// Whether the test detected a performance improvement
    var isImprovement: Bool {
        return comparisonResult.isImprovement
    }
    
    /// Test result summary
    var summary: String {
        let result = """
        Test Result Summary:
        - Device: \(deviceName)
        - Configuration: \(testConfig.description)
        - Test Date: \(DateFormatter.iso8601.string(from: timestamp))
        
        Current Performance:
        - Average GPU Time: \(String(format: "%.3f", currentMeasurementSet.statistics.mean)) ms
        - Quality Rating: \(currentMeasurementSet.qualityRating.rawValue)
        
        Baseline Comparison:
        - Baseline GPU Time: \(String(format: "%.3f", baselineMeasurementSet.statistics.mean)) ms
        // Note: meanDifferencePercent is already a percentage value (e.g., 0.42 for 0.42%)
        // DO NOT multiply by 100 - it's already calculated as a percentage
        - Performance Change: \(String(format: "%+.3f", comparisonResult.meanDifference)) ms (\(String(format: "%+.1f", comparisonResult.meanDifferencePercent))%)
        
        Statistical Analysis:
        - Confidence Range: \(String(format: "%.3f", abs(comparisonResult.confidenceInterval.lower))) to \(String(format: "%.3f", abs(comparisonResult.confidenceInterval.upper))) ms (95% confidence)
        - Reliability: \(comparisonResult.isSignificant ? "Statistically significant (real change, not random)" : "Not statistically significant (could be random variation)")
        
        \(comparisonResult.stageUtilizationComparison != nil ? "Stage Utilization Comparison:" : "")
        \(comparisonResult.stageUtilizationComparison?.vertexUtilization != nil ? "- Vertex Utilization: \(String(format: "%.1f", comparisonResult.stageUtilizationComparison!.vertexUtilization!.current))%  (\(String(format: "%+.1f", comparisonResult.stageUtilizationComparison!.vertexUtilization!.change))%)" : "")
        \(comparisonResult.stageUtilizationComparison?.fragmentUtilization != nil ? "- Fragment Utilization: \(String(format: "%.1f", comparisonResult.stageUtilizationComparison!.fragmentUtilization!.current))%  (\(String(format: "%+.1f", comparisonResult.stageUtilizationComparison!.fragmentUtilization!.change))%)" : "")
        \(comparisonResult.stageUtilizationComparison?.totalUtilization != nil ? "- Total Utilization: \(String(format: "%.1f", comparisonResult.stageUtilizationComparison!.totalUtilization!.current))%  (\(String(format: "%+.1f", comparisonResult.stageUtilizationComparison!.totalUtilization!.change))%)" : "")
        
        \(comparisonResult.performanceStatsComparison != nil ? "Memory Statistics Comparison:" : "")
        \(comparisonResult.performanceStatsComparison?.cacheHits != nil ? "- Cache Hits: \(String(format: "%.0f", comparisonResult.performanceStatsComparison!.cacheHits!.current))" : "")
        \(comparisonResult.performanceStatsComparison?.cacheMisses != nil ? "- Cache Misses: \(String(format: "%.0f", comparisonResult.performanceStatsComparison!.cacheMisses!.current))" : "")
        \(comparisonResult.performanceStatsComparison?.cacheHitRate != nil ? "- Cache Hit Rate: \(String(format: "%.1f", comparisonResult.performanceStatsComparison!.cacheHitRate!.current * 100))%  (\(String(format: "%+.1f", comparisonResult.performanceStatsComparison!.cacheHitRate!.changePercent))%)" : "")
        \(comparisonResult.performanceStatsComparison?.memoryBandwidth != nil ? "- Memory Bandwidth: \(String(format: "%.1f", comparisonResult.performanceStatsComparison!.memoryBandwidth!.current)) MB/s  (\(String(format: "%+.1f", comparisonResult.performanceStatsComparison!.memoryBandwidth!.changePercent))%)" : "")
        \(comparisonResult.performanceStatsComparison?.instructionsExecuted != nil ? "- Instructions Executed: \(String(format: "%.0f", comparisonResult.performanceStatsComparison!.instructionsExecuted!.current))  (\(String(format: "%+.1f", comparisonResult.performanceStatsComparison!.instructionsExecuted!.changePercent))%)" : "")
        
        Result: \(isRegression ? "PERFORMANCE REGRESSION DETECTED" : isImprovement ? "PERFORMANCE IMPROVEMENT DETECTED" : "NO SIGNIFICANT CHANGE DETECTED")
        """
        
        return result
    }
    
    /// Creates a new performance test result
    init(current: PerformanceMeasurementSet, baseline: PerformanceMeasurementSet, comparison: StatisticalAnalysis.ComparisonResult) {
        self.currentMeasurementSet = current
        self.baselineMeasurementSet = baseline
        self.comparisonResult = comparison
        self.timestamp = Date()
    }
}

// Extension for ISO8601 date formatting
extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

/// Manages performance baseline data storage and retrieval
class PerformanceBaselineManager {
    
    /// Default filename for the baseline JSON file
    static let baselineFileName = "performance_baseline.json"
    
    /// Default filename for the test results JSON file
    static let testResultsFileName = "performance_test_results.json"
    
    /// Public access to the test results file path
    var testResultsFilePath: URL {
        return privateTestResultsFilePath
    }
    
    /// Gets the baseline file path in the project's Data directory (cached to avoid multiple project discovery calls)
    private lazy var baselineFilePath: URL = {
        // Try to find the project's Data directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        let currentURL = URL(fileURLWithPath: currentDirectory)
        
        // Look for the Data directory in common locations
        // Priority order: project Data folder first, then fallback to current directory
        let possibleDataPaths = [
            // Try to find project directory by looking for the executable's source location (highest priority)
            findProjectFromExecutable()?.appendingPathComponent("Data"),
            // If running from build directory, try to find project root
            findProjectRoot(from: currentURL)?.appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Data"),
            // If running from project root
            currentURL.appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Data"),
            // If running from project root with different structure (current actual structure)
            currentURL.appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Data"),
            // If running from project root with different structure
            currentURL.appendingPathComponent("Data")
        ].compactMap { $0 }
        
        // Use the first valid path, or fall back to current directory
        for dataPath in possibleDataPaths {
            if FileManager.default.fileExists(atPath: dataPath.path) {
                return dataPath.appendingPathComponent(PerformanceBaselineManager.baselineFileName)
            }
        }
        
        // Fallback: create Data directory in current location
        let fallbackDataPath = currentURL.appendingPathComponent("Data")
        try? FileManager.default.createDirectory(at: fallbackDataPath, withIntermediateDirectories: true)
        return fallbackDataPath.appendingPathComponent(PerformanceBaselineManager.baselineFileName)
    }()
    
    /// Gets the test results file path in the project's Data directory (cached to avoid multiple project discovery calls)
    private lazy var privateTestResultsFilePath: URL = {
        // Try to find the project's Data directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        let currentURL = URL(fileURLWithPath: currentDirectory)
        
        // Look for the Data directory in common locations
        // Priority order: project Data folder first, then fallback to current directory
        let possibleDataPaths = [
            // Try to find project directory by looking for the executable's source location (highest priority)
            findProjectFromExecutable()?.appendingPathComponent("Data"),
            // If running from build directory, try to find project root
            findProjectRoot(from: currentURL)?.appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Data"),
            // If running from project root
            currentURL.appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Data"),
            // If running from project root with different structure (current actual structure)
            currentURL.appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Data"),
            // If running from project root with different structure
            currentURL.appendingPathComponent("Data")
        ].compactMap { $0 }
        
        // Use the first valid path, or fall back to current directory
        for dataPath in possibleDataPaths {
            if FileManager.default.fileExists(atPath: dataPath.path) {
                return dataPath.appendingPathComponent(PerformanceBaselineManager.testResultsFileName)
            }
        }
        
        // Fallback: create Data directory in current location
        let fallbackDataPath = currentURL.appendingPathComponent("Data")
        try? FileManager.default.createDirectory(at: fallbackDataPath, withIntermediateDirectories: true)
        return fallbackDataPath.appendingPathComponent(PerformanceBaselineManager.testResultsFileName)
    }()
    
    /// Attempts to find the project root directory
    private func findProjectRoot(from startURL: URL) -> URL? {
        var currentURL = startURL
        
        // Walk up the directory tree looking for project indicators
        while currentURL.path != "/" {
            let xcodeProject = currentURL.appendingPathComponent("Metal-Performance-Tester.xcodeproj")
            if FileManager.default.fileExists(atPath: xcodeProject.path) {
                return currentURL
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        return nil
    }
    
    /// Attempts to find the project directory using multiple strategies for maximum robustness
    private func findProjectFromExecutable() -> URL? {
        // Get the executable's path
        guard let executablePath = Bundle.main.executablePath else {
            return nil
        }
        
        let executableURL = URL(fileURLWithPath: executablePath)
        let executableDir = executableURL.deletingLastPathComponent()
        
        // Strategy 1: Check for custom project path via environment variable
        if let customPath = ProcessInfo.processInfo.environment["METAL_PERFORMANCE_PROJECT_PATH"] {
            let projectURL = URL(fileURLWithPath: customPath)
            let dataPath = projectURL.appendingPathComponent("Data")
            if FileManager.default.fileExists(atPath: dataPath.path) {
                print("Found project via environment variable: \(projectURL.path)")
                return projectURL
            }
        }
        
        // Strategy 2: Search up directory tree from executable location
        // This works regardless of where the project is located
        var searchDir = executableDir
        while searchDir.path != "/" {
            let potentialDataPath = searchDir.appendingPathComponent("Data")
            if FileManager.default.fileExists(atPath: potentialDataPath.path) {
                // Additional validation: avoid DerivedData directories
                // Look for project-specific indicators to ensure this is the actual project
                let projectFile = searchDir.appendingPathComponent("Metal-Performance-Tester.xcodeproj")
                let sourcesDir = searchDir.appendingPathComponent("Sources")
                
                if FileManager.default.fileExists(atPath: projectFile.path) || 
                   FileManager.default.fileExists(atPath: sourcesDir.path) {
                    print("Found project by searching up directory tree: \(searchDir.path)")
                    return searchDir
                }
            }
            searchDir = searchDir.deletingLastPathComponent()
        }
        
        // Strategy 3: Fallback to hardcoded paths (only if running from DerivedData)
        // This maintains backward compatibility for common project structures
        if executableDir.path.contains("DerivedData") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let commonProjectPaths = [
                "Projects/Xcode/Metal-Performance-Tester/Metal-Performance-Tester",
                "Developer/Metal-Performance-Tester/Metal-Performance-Tester",
                "Documents/Metal-Performance-Tester/Metal-Performance-Tester",
                "Desktop/Metal-Performance-Tester/Metal-Performance-Tester"
            ]
            
            for projectPath in commonProjectPaths {
                let fullPath = homeDir.appendingPathComponent(projectPath)
                let dataPath = fullPath.appendingPathComponent("Data")
                if FileManager.default.fileExists(atPath: dataPath.path) {
                    return fullPath
                }
            }
        }
        
        print("Warning: Could not locate project directory using any strategy")
        return nil
    }
    
    /// Saves a performance measurement set as the new baseline
    func saveBaseline(_ measurementSet: PerformanceMeasurementSet) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // Create a unique filename based on the test configuration
        let config = measurementSet.testConfig
        let safeBaselineName = config.baselineName.replacingOccurrences(of: " ", with: "_").lowercased()
        let filename = "baseline_\(safeBaselineName).json"
        
        // Create the baselines directory if it doesn't exist
        let baselinesDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("baselines")
        try FileManager.default.createDirectory(at: baselinesDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create the specific baseline file path in the baselines folder
        let specificBaselinePath = baselinesDirectory.appendingPathComponent(filename)
        
        let data = try encoder.encode(measurementSet)
        try data.write(to: specificBaselinePath)
    
        print("Baseline saved to: \(specificBaselinePath.path)")
    }
    
    /// Saves a single performance result as the new baseline (backward compatibility)
    func saveBaseline(_ result: PerformanceResult) throws {
        let measurementSet = PerformanceMeasurementSet(singleResult: result)
        try saveBaseline(measurementSet)
    }
    
    /// Loads the current baseline performance measurement set
    func loadBaseline() throws -> PerformanceMeasurementSet {
        // First try to load from the old location for backward compatibility
        if FileManager.default.fileExists(atPath: baselineFilePath.path) {
            let data = try Data(contentsOf: baselineFilePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PerformanceMeasurementSet.self, from: data)
        }
        
        // If not found, look in the baselines folder
        let baselinesDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("baselines")
        let files = try FileManager.default.contentsOfDirectory(at: baselinesDirectory, includingPropertiesForKeys: nil)
        let baselineFiles = files.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("baseline_") }
        
        if baselineFiles.isEmpty {
            throw NSError(domain: "PerformanceBaselineManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No baseline files found in baselines directory"])
        }
        
        // For now, load the first available baseline (in the future, we could make this configurable)
        let baselineFile = baselineFiles.first!
        let data = try Data(contentsOf: baselineFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(PerformanceMeasurementSet.self, from: data)
    }
    
    /// Loads the current baseline as a single performance result (backward compatibility)
    func loadBaselineAsSingleResult() throws -> PerformanceResult {
        let measurementSet = try loadBaseline()
        return measurementSet.individualResults.first!
    }
    
    /// Checks if a baseline file exists
    func baselineExists() -> Bool {
        // Check old location first
        if FileManager.default.fileExists(atPath: baselineFilePath.path) {
            return true
        }
        
        // Check baselines folder
        let baselinesDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("baselines")
        do {
            let files = try FileManager.default.contentsOfDirectory(at: baselinesDirectory, includingPropertiesForKeys: nil)
            let baselineFiles = files.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("baseline_") }
            return !baselineFiles.isEmpty
        } catch {
            return false
        }
    }
    
    /// Deletes the baseline file
    func deleteBaseline() throws {
        try FileManager.default.removeItem(at: baselineFilePath)
        print("Baseline file deleted")
    }
    
    /// Lists all available baseline files
    func listBaselines() -> [URL] {
        let baselinesDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("baselines")
        do {
            let files = try FileManager.default.contentsOfDirectory(at: baselinesDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("baseline_") }
        } catch {
            print("Error listing baselines: \(error)")
            return []
        }
    }
    
    /// Loads a specific baseline by filename
    func loadSpecificBaseline(filename: String) throws -> PerformanceMeasurementSet {
        let baselinesDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("baselines")
        let specificPath = baselinesDirectory.appendingPathComponent(filename)
        
        let data = try Data(contentsOf: specificPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(PerformanceMeasurementSet.self, from: data)
    }
    
    // MARK: - Test Results Management
    
    /// Saves a performance test result to the test results file
    func saveTestResult(_ testResult: PerformanceTestResult) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // Create a unique filename based on the test configuration
        let config = testResult.testConfig
        let safeTestName = config.baselineName.replacingOccurrences(of: " ", with: "_").lowercased()
        let filename = "test_result_\(safeTestName).json"
        
        // Create the results directory if it doesn't exist
        let resultsDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("results")
        try FileManager.default.createDirectory(at: resultsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create the specific test result file path in the results folder
        let specificTestResultPath = resultsDirectory.appendingPathComponent(filename)
        
        let data = try encoder.encode(testResult)
        try data.write(to: specificTestResultPath)
        
        print("Test result saved to: \(specificTestResultPath.path)")
    }
    
    /// Saves a performance test result to the test results file and prints the save message
    func saveTestResultWithMessage(_ testResult: PerformanceTestResult) throws {
        try saveTestResult(testResult)
        print("Test result saved to: \(privateTestResultsFilePath.path)")
    }
    
    /// Loads the most recent performance test result
    func loadTestResult() throws -> PerformanceTestResult {
        let data = try Data(contentsOf: privateTestResultsFilePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(PerformanceTestResult.self, from: data)
    }
    
    /// Checks if a test results file exists
    func testResultExists() -> Bool {
        return FileManager.default.fileExists(atPath: privateTestResultsFilePath.path)
    }
    
    /// Deletes the test results file
    func deleteTestResult() throws {
        try FileManager.default.removeItem(at: privateTestResultsFilePath)
        print("Test result file deleted")
    }
    
    /// Lists all available test result files
    func listTestResults() -> [URL] {
        let resultsDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("results")
        do {
            let files = try FileManager.default.contentsOfDirectory(at: resultsDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("test_result_") }
        } catch {
            print("Error listing test results: \(error)")
            return []
        }
    }
    
    /// Loads a specific test result by filename
    func loadSpecificTestResult(filename: String) throws -> PerformanceTestResult {
        let resultsDirectory = baselineFilePath.deletingLastPathComponent().appendingPathComponent("results")
        let specificPath = resultsDirectory.appendingPathComponent(filename)
        
        let data = try Data(contentsOf: specificPath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(PerformanceTestResult.self, from: data)
    }
}
