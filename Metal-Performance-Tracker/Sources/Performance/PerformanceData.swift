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
        // Priority order: project Data folder first, then fallback to current directory
        let possibleDataPaths = [
            // Try to find project directory by looking for the executable's source location (highest priority)
            findProjectFromExecutable()?.appendingPathComponent("Data"),
            // If running from build directory, try to find project root
            findProjectRoot(from: currentURL)?.appendingPathComponent("Metal-Performance-Tracker").appendingPathComponent("Data"),
            // If running from project root
            currentURL.appendingPathComponent("Metal-Performance-Tracker").appendingPathComponent("Data"),
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
    
    /// Attempts to find the project directory by looking at the executable's location
    private func findProjectFromExecutable() -> URL? {
        // Get the executable's path
        guard let executablePath = Bundle.main.executablePath else {
            return nil
        }
        
        let executableURL = URL(fileURLWithPath: executablePath)
        let executableDir = executableURL.deletingLastPathComponent()
        
        // If we're running from DerivedData, try to find the project by looking for common patterns
        if executableDir.path.contains("DerivedData") {
            // Look for the project in common user directories
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let commonProjectPaths = [
                "Projects/Xcode/Metal-Performance-Tracker/Metal-Performance-Tracker",
                "Developer/Metal-Performance-Tracker/Metal-Performance-Tracker",
                "Documents/Metal-Performance-Tracker/Metal-Performance-Tracker",
                "Desktop/Metal-Performance-Tracker/Metal-Performance-Tracker"
            ]
            
            for projectPath in commonProjectPaths {
                let fullPath = homeDir.appendingPathComponent(projectPath)
                let dataPath = fullPath.appendingPathComponent("Data")
                if FileManager.default.fileExists(atPath: dataPath.path) {
                    return fullPath
                }
            }
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
    
        print("Baseline saved to: \(baselineFilePath.path)")
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
