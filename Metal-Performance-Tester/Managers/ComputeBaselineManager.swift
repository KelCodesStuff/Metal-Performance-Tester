//
//  ComputeBaselineManager.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/25/25.
//

import Metal
import Foundation

/// Manages compute baseline update operations
class ComputeBaselineManager {
    
    /// Runs the compute performance test and updates the compute baseline with multiple iterations
    func runUpdateBaseline(testConfig: TestConfiguration? = nil) -> Int32 {
        // COMPUTE BASELINE UPDATE OUTPUT: Start of compute baseline update flow
        print("Running compute performance baseline...")
        print()
        
        // Initialize Metal and renderer
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device.")
            return ExitCode.error.rawValue
        }
        
        let config = testConfig ?? TestPreset.computeModerate.createConfiguration()
        
        // COMPUTE BASELINE CONFIGURATION OUTPUT
        print("Compute Baseline Configuration:")
        print("- Baseline: \(config.description)")
        print("- Device: \(device.name)")
        if let threadgroupSize = config.threadgroupSize {
            print("- Threadgroup size: \(threadgroupSize.width)x\(threadgroupSize.height)x\(threadgroupSize.depth)")
        }
        if let threadgroupCount = config.threadgroupCount {
            print("- Threadgroup count: \(threadgroupCount.width)x\(threadgroupCount.height)x\(threadgroupCount.depth)")
        }
        if let complexity = config.computeWorkloadComplexity {
            print("- Compute workload complexity: \(complexity)/10")
        }
        print()
        
        guard let renderer = Renderer(device: device, testConfig: config) else {
            print("Failed to initialize the Renderer.")
            return ExitCode.error.rawValue
        }
        
        // COMPUTE BASELINE UPDATE OUTPUT: Iteration progress and completion
        print("Running 100 iterations to create compute baseline...")
        guard let measurementSet = renderer.runMultipleComputeIterations(iterations: 100) else {
            print("Compute performance measurement not available on this GPU.")
            print("Counter sampling is not supported. Cannot establish compute baseline.")
            return ExitCode.error.rawValue
        }
        
        // COMPUTE PERFORMANCE BASELINE OUTPUT
        print("Progress: (100/100)")
        let separator = String(repeating: "-", count: 60)
        print(separator)
        print("COMPUTE PERFORMANCE BASELINE")
        print()
        
        // Calculate FPS and range using pre-calculated statistics
        let meanFPS = 1000.0 / measurementSet.statistics.mean
        let minFPS = 1000.0 / measurementSet.statistics.max  // max time = min FPS
        let maxFPS = 1000.0 / measurementSet.statistics.min  // min time = max FPS
        
        // Use pre-calculated time statistics (safer and more efficient)
        let minTime = measurementSet.statistics.min
        let maxTime = measurementSet.statistics.max
        let medianTime = measurementSet.statistics.median
        
        
        // Display Frequency section
        print("Frequency:")
        print("- FPS: \(String(format: "%.1f", meanFPS)) (\(String(format: "%.1f", minFPS)) - \(String(format: "%.1f", maxFPS)))")
        print()
        
        // Display Time section
        print("Compute Time:")
        print("- Average: \(String(format: "%.3f", measurementSet.averageGpuTimeMs)) ms")
        print("- Standard Deviation: \(String(format: "%.3f", measurementSet.statistics.standardDeviation)) ms")
        print("- Range: \(String(format: "%.3f", minTime)) - \(String(format: "%.3f", maxTime)) ms")
        print("- Median: \(String(format: "%.3f", medianTime)) ms")
        print()
        
        // Display Compute Utilization section
        if let lastResult = measurementSet.individualResults.last,
           let computeUtilization = lastResult.computeUtilization {
            print("Compute Utilization:")
            if let computeUtil = computeUtilization.computeUtilization {
                print("- Average Compute Utilization: \(String(format: "%.1f", computeUtil))%")
            }
            if let memoryUtil = computeUtilization.memoryUtilization {
                print("- Average Memory Utilization: \(String(format: "%.1f", memoryUtil))%")
            }
            if let totalUtil = computeUtilization.totalUtilization {
                print("- Average Total Utilization: \(String(format: "%.1f", totalUtil))%")
            }
            if let threadgroupEff = computeUtilization.threadgroupEfficiency {
                print("- Average Threadgroup Efficiency: \(String(format: "%.1f", threadgroupEff))%")
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
            if let instructionsExecuted = statistics.instructionsExecuted {
                print("- Instructions Executed: \(String(format: "%.0f", instructionsExecuted))")
            }
            print()
        }
        
        // Save as new compute baseline
        do {
            try saveBaseline(measurementSet)
            print("Compute baseline created successfully")
            return ExitCode.success.rawValue
        } catch {
            print("Failed to save compute baseline: \(error)")
            return ExitCode.error.rawValue
        }
    }
    
    /// Saves a compute measurement set as the new baseline
    func saveBaseline(_ measurementSet: ComputeMeasurementSet) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // Create a unique filename based on the test configuration
        let config = measurementSet.testConfig
        let presetName = config.testMode.replacingOccurrences(of: "-", with: "_")
        let filename = "\(presetName)_compute_baseline.json"
        
        // Create the baselines directory if it doesn't exist
        let baselinesDirectory = getBaselineDirectory().appendingPathComponent("baselines")
        try FileManager.default.createDirectory(at: baselinesDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create the specific baseline file path in the baselines folder
        let specificBaselinePath = baselinesDirectory.appendingPathComponent(filename)
        
        let data = try encoder.encode(measurementSet)
        try data.write(to: specificBaselinePath)
    
        print("Compute baseline saved to: \(specificBaselinePath.path)")
    }
    
    /// Checks if a compute baseline exists
    func baselineExists() -> Bool {
        let baselinesDirectory = getBaselineDirectory().appendingPathComponent("baselines")
        let files = try? FileManager.default.contentsOfDirectory(at: baselinesDirectory, includingPropertiesForKeys: nil)
        return files?.contains { $0.lastPathComponent.contains("_compute_baseline.json") } ?? false
    }
    
    /// Loads the compute baseline
    func loadBaseline() throws -> ComputeMeasurementSet {
        let baselinesDirectory = getBaselineDirectory().appendingPathComponent("baselines")
        let files = try FileManager.default.contentsOfDirectory(at: baselinesDirectory, includingPropertiesForKeys: nil)
        
        guard let baselineFile = files.first(where: { $0.lastPathComponent.contains("_compute_baseline.json") }) else {
            throw NSError(domain: "ComputeBaselineManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No compute baseline found"])
        }
        
        let data = try Data(contentsOf: baselineFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ComputeMeasurementSet.self, from: data)
    }
    
    /// Saves a compute test result
    func saveTestResult(_ testResult: ComputeTestResult) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        // Create a unique filename based on the test configuration
        let config = testResult.testConfig
        let presetName = config.testMode.replacingOccurrences(of: "-", with: "_")
        let filename = "\(presetName)_compute_results.json"
        
        // Create the results directory if it doesn't exist
        let resultsDirectory = getBaselineDirectory().appendingPathComponent("results")
        try FileManager.default.createDirectory(at: resultsDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Create the specific result file path in the results folder
        let specificResultPath = resultsDirectory.appendingPathComponent(filename)
        
        let data = try encoder.encode(testResult)
        try data.write(to: specificResultPath)
        
        print("\nCompute test result saved to: \(specificResultPath.path)")
    }
    
    /// Gets the baseline directory path
    private func getBaselineDirectory() -> URL {
        // Use the user's Documents directory for baseline storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let baselinePath = documentsPath.appendingPathComponent("Metal-Performance-Tester").appendingPathComponent("Results")
        
        // Create the Results directory if it doesn't exist
        try? FileManager.default.createDirectory(at: baselinePath, withIntermediateDirectories: true)
        
        return baselinePath
    }
}
