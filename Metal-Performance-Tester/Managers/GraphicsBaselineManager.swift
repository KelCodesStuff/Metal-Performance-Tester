//
//  GraphicsBaselineManager.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Metal
import Foundation

/// Manages graphics baseline update operations
class GraphicsBaselineManager {
    
    /// Runs the graphics performance test and updates the graphics baseline with multiple iterations
    func runUpdateBaseline(testConfig: TestConfiguration? = nil) -> Int32 {
        // GRAPHICS BASELINE UPDATE OUTPUT: Start of graphics baseline update flow
        print("Running graphics performance baseline...")
        print()
        
        // Initialize Metal and renderer
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device.")
            return ExitCode.error.rawValue
        }
        
        let config = testConfig ?? TestPreset.graphicsModerate.createConfiguration()
        
        // GRAPHICS BASELINE CONFIGURATION OUTPUT
        print("Graphics Baseline Configuration:")
        print("- Baseline: \(config.description)")
        print("- Device: \(device.name)")
        print("- Triangle count: \(config.triangleCount)")
        print("- Geometry complexity: \(config.geometryComplexity)/10")
        print("- Resolution: \(config.effectiveWidth)x\(config.effectiveHeight)")
        print("- Resolution scale: \(String(format: "%.1f", config.resolutionScale))x")
        print()
        
        guard let renderer = Renderer(device: device, testConfig: config) else {
            print("Failed to initialize the Renderer.")
            return ExitCode.error.rawValue
        }
        
        // GRAPHICS BASELINE UPDATE OUTPUT: Iteration progress and completion
        print("Running 100 iterations to create graphics baseline...")
        guard let measurementSet = renderer.runMultipleGraphicsIterations(iterations: 100) else {
            print("Graphics performance measurement not available on this GPU.")
            print("Counter sampling is not supported. Cannot establish graphics baseline.")
            return ExitCode.error.rawValue
        }
        
        // GRAPHICS PERFORMANCE BASELINE OUTPUT
        print("Progress: (100/100)")
        let separator = String(repeating: "-", count: 60)
        print(separator)
        print("GRAPHICS PERFORMANCE BASELINE")
        print()
        
        // Calculate FPS and range using pre-calculated statistics
        let meanFPS = 1000.0 / measurementSet.statistics.mean
        let minFPS = 1000.0 / measurementSet.statistics.max  // max time = min FPS
        let maxFPS = 1000.0 / measurementSet.statistics.min  // min time = max FPS
        
        // Use pre-calculated time statistics (safer and more efficient)
        let minTime = measurementSet.statistics.min
        let maxTime = measurementSet.statistics.max
        let medianTime = measurementSet.statistics.median
        
        // Calculate quality rating using pre-calculated coefficient of variation
        
        // Display Frequency section
        print("Frequency:")
        print("- FPS: \(String(format: "%.1f", meanFPS)) (\(String(format: "%.1f", minFPS)) - \(String(format: "%.1f", maxFPS)))")
        print()
        
        // Display Time section
        print("Render Time:")
        print("- Average: \(String(format: "%.3f", measurementSet.averageGpuTimeMs)) ms")
        print("- Standard Deviation: \(String(format: "%.3f", measurementSet.statistics.standardDeviation)) ms")
        print("- Range: \(String(format: "%.3f", minTime)) - \(String(format: "%.3f", maxTime)) ms")
        print("- Median: \(String(format: "%.3f", medianTime)) ms")
        print()
        
        // Display Stage Utilization section
        if let lastResult = measurementSet.individualResults.last,
           let stageUtilization = lastResult.stageUtilization {
            print("Stage Utilization:")
            if let vertexUtil = stageUtilization.vertexUtilization {
                print("- Average Vertex Utilization: \(String(format: "%.1f", vertexUtil))%")
            }
            if let fragmentUtil = stageUtilization.fragmentUtilization {
                print("- Average Fragment Utilization: \(String(format: "%.1f", fragmentUtil))%")
            }
            if let totalUtil = stageUtilization.totalUtilization {
                print("- Average Total Utilization: \(String(format: "%.1f", totalUtil))%")
            }
            print()
        }
        
        // Display Performance Statistics section
        if let lastResult = measurementSet.individualResults.last,
           let statistics = lastResult.statistics {
            print("Memory Statistics:")
            if let memoryBandwidth = statistics.memoryBandwidth {
                print("- Memory Bandwidth: \(String(format: "%.1f", memoryBandwidth)) MB/s")
            }
            if let cacheHits = statistics.cacheHits {
                print("- Cache Hits: \(cacheHits)")
            }
            if let cacheMisses = statistics.cacheMisses {
                print("- Cache Misses: \(cacheMisses)")
            }
            if let cacheHitRate = statistics.cacheHitRate {
                print("- Cache Hit Rate: \(String(format: "%.1f", cacheHitRate))%")
            }
            if let instructionsExecuted = statistics.instructionsExecuted {
                print("- Instructions Executed: \(String(format: "%.0f", instructionsExecuted))")
            }
            print()
        }
        
        // Save as new graphics baseline
        let graphicsBaselineManager = GraphicsBaselineManager()
        do {
            try graphicsBaselineManager.saveBaseline(measurementSet)
            print("Graphics baseline created successfully")
            return ExitCode.success.rawValue
        } catch {
            print("Failed to save graphics baseline: \(error)")
            return ExitCode.error.rawValue
        }
    }
    
    /// Saves a unified measurement set as the new baseline
    func saveBaseline(_ measurementSet: UnifiedPerformanceMeasurementSet) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // Create a unique filename based on the test configuration
        let config = measurementSet.testConfig
        let presetName = generateCleanFilename(from: config.testMode)
        let filename = "\(presetName)_graphics_baseline.json"
        
        // Create the baselines directory if it doesn't exist
        let baselinesDirectory = getBaselineDirectory().appendingPathComponent("baselines")
        try FileManager.default.createDirectory(at: baselinesDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create the specific baseline file path in the baselines folder
        let specificBaselinePath = baselinesDirectory.appendingPathComponent(filename)
        
        let data = try encoder.encode(measurementSet)
        try data.write(to: specificBaselinePath)
    
        print("Graphics baseline saved to: \(specificBaselinePath.path)")
    }
    
    /// Checks if a graphics baseline exists for the given test configuration
    func baselineExists(for testConfig: TestConfiguration? = nil) -> Bool {
        let baselinesDirectory = getBaselineDirectory().appendingPathComponent("baselines")
        let files = try? FileManager.default.contentsOfDirectory(at: baselinesDirectory, includingPropertiesForKeys: nil)
        
        if let config = testConfig {
            // Check for specific baseline based on test configuration
            let presetName = generateCleanFilename(from: config.testMode)
            let expectedFilename = "\(presetName)_graphics_baseline.json"
            return files?.contains { $0.lastPathComponent == expectedFilename } ?? false
        } else {
            // Check if any graphics baseline exists (legacy behavior)
            return files?.contains { $0.lastPathComponent.contains("_graphics_baseline.json") } ?? false
        }
    }
    
    /// Loads the graphics baseline for the given test configuration
    func loadBaseline(for testConfig: TestConfiguration? = nil) throws -> UnifiedPerformanceMeasurementSet {
        let baselinesDirectory = getBaselineDirectory().appendingPathComponent("baselines")
        let files = try FileManager.default.contentsOfDirectory(at: baselinesDirectory, includingPropertiesForKeys: nil)
        
        let baselineFile: URL
        
        if let config = testConfig {
            // Load specific baseline based on test configuration
            let presetName = generateCleanFilename(from: config.testMode)
            let expectedFilename = "\(presetName)_graphics_baseline.json"
            
            guard let specificFile = files.first(where: { $0.lastPathComponent == expectedFilename }) else {
                throw NSError(
                    domain: "GraphicsBaselineManager", 
                    code: 1, 
                    userInfo: [
                        NSLocalizedDescriptionKey: "No graphics baseline found for test configuration '\(config.testMode)'. Expected file: \(expectedFilename). Run with --update-graphics-baseline --\(config.testMode) first to establish a baseline."
                    ]
                )
            }
            baselineFile = specificFile
        } else {
            // Legacy behavior: load the first available graphics baseline
            guard let firstFile = files.first(where: { $0.lastPathComponent.contains("_graphics_baseline.json") }) else {
                throw NSError(domain: "GraphicsBaselineManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No graphics baseline found"])
            }
            baselineFile = firstFile
        }
        
        let data = try Data(contentsOf: baselineFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UnifiedPerformanceMeasurementSet.self, from: data)
    }
    
    /// Saves a graphics test result
    func saveTestResult(_ testResult: UnifiedPerformanceTestResult) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // Create a unique filename based on the test configuration
        let config = testResult.testConfig
        let presetName = generateCleanFilename(from: config.testMode)
        let filename = "\(presetName)_graphics_results.json"
        
        // Create the results directory if it doesn't exist
        let resultsDirectory = getBaselineDirectory().appendingPathComponent("results")
        try FileManager.default.createDirectory(at: resultsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create the specific result file path in the results folder
        let specificResultPath = resultsDirectory.appendingPathComponent(filename)
        
        let data = try encoder.encode(testResult)
        try data.write(to: specificResultPath)
        
        print("\nGraphics test result saved to: \(specificResultPath.path)")
    }
    
    /// Gets the baseline directory path
    private func getBaselineDirectory() -> URL {
        // Use Application Support directory for baseline storage (proper macOS convention)
        let applicationSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baselinePath = applicationSupportPath.appendingPathComponent("Metal-Performance-Tester")
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(at: baselinePath, withIntermediateDirectories: true)
        
        return baselinePath
    }
    
    /// Generates clean filenames by extracting the key part of the test mode
    /// Examples: "graphics-max" -> "max", "compute-moderate" -> "moderate"
    private func generateCleanFilename(from testMode: String) -> String {
        // Remove the prefix (graphics- or compute-) and return the key part
        if testMode.hasPrefix("graphics-") {
            return String(testMode.dropFirst("graphics-".count))
        } else if testMode.hasPrefix("compute-") {
            return String(testMode.dropFirst("compute-".count))
        }
        // Fallback: replace dashes with underscores for other formats
        return testMode.replacingOccurrences(of: "-", with: "_")
    }
}
