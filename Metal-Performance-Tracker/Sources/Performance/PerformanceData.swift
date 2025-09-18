//
//  PerformanceData.swift
//  Metal-Performance-Tracker
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
    
    /// Creates a new performance result
    init(gpuTimeMs: Double, deviceName: String, testConfig: TestConfiguration) {
        self.gpuTimeMs = gpuTimeMs
        self.timestamp = Date()
        self.deviceName = deviceName
        self.testConfig = testConfig
    }
}

/// Configuration parameters for the performance test
struct TestConfiguration: Codable {
    /// Render target dimensions
    let width: Int
    let height: Int
    
    /// Pixel format used for rendering
    let pixelFormat: String
    
    /// Number of vertices rendered
    let vertexCount: Int
    
    /// Creates a test configuration from current renderer settings
    init(width: Int, height: Int, pixelFormat: String, vertexCount: Int) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.vertexCount = vertexCount
    }
}

/// Manages performance baseline data storage and retrieval
class PerformanceBaselineManager {
    
    /// Default filename for the baseline JSON file
    static let baselineFileName = "performance_baseline.json"
    
    /// Gets the baseline file path in the project's Data directory
    private var baselineFilePath: URL {
        // Try to find the project's Data directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        let currentURL = URL(fileURLWithPath: currentDirectory)
        
        // Look for the Data directory in common locations
        let possibleDataPaths = [
            // If running from project root
            currentURL.appendingPathComponent("Metal-Performance-Tracker").appendingPathComponent("Data"),
            // If running from project root with different structure
            currentURL.appendingPathComponent("Data"),
            // If running from build directory, try to find project root
            findProjectRoot(from: currentURL)?.appendingPathComponent("Metal-Performance-Tracker").appendingPathComponent("Data")
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
    }
    
    /// Attempts to find the project root directory
    private func findProjectRoot(from startURL: URL) -> URL? {
        var currentURL = startURL
        
        // Walk up the directory tree looking for project indicators
        while currentURL.path != "/" {
            let xcodeProject = currentURL.appendingPathComponent("Metal-Performance-Tracker.xcodeproj")
            if FileManager.default.fileExists(atPath: xcodeProject.path) {
                return currentURL
            }
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        return nil
    }
    
    /// Saves a performance result as the new baseline
    func saveBaseline(_ result: PerformanceResult) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(result)
        try data.write(to: baselineFilePath)
    
        print("GPU Time: \(String(format: "%.3f", result.gpuTimeMs)) ms")
        print("Device: \(result.deviceName)")
        print("\nBaseline saved to: \(baselineFilePath.path)")
    }
    
    /// Loads the current baseline performance result
    func loadBaseline() throws -> PerformanceResult {
        let data = try Data(contentsOf: baselineFilePath)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(PerformanceResult.self, from: data)
    }
    
    /// Checks if a baseline file exists
    func baselineExists() -> Bool {
        return FileManager.default.fileExists(atPath: baselineFilePath.path)
    }
    
    /// Deletes the baseline file
    func deleteBaseline() throws {
        try FileManager.default.removeItem(at: baselineFilePath)
        print("Baseline file deleted")
    }
}
