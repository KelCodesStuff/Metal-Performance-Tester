//
//  CommandLineParser.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation

/// Represents the different modes the performance tracker can run in
enum TestMode {
    case runTest(threshold: Double, testConfig: TestConfiguration?)
    case updateBaseline(testConfig: TestConfiguration?)
    case help
}

/// Parses command-line arguments and determines the test mode
class CommandLineParser {
    
    /// Default performance regression threshold (5%)
    static let defaultThreshold = 0.05
    
    /// Parses command-line arguments and returns the appropriate test mode
    /// - Parameter arguments: Command-line arguments (excluding program name)
    /// - Returns: The test mode to execute
    static func parse(arguments: [String]) -> TestMode {
        guard !arguments.isEmpty else {
            return .help
        }
        
        let firstArg = arguments[0]
        
        switch firstArg {
        case "--run-test":
            // Parse optional threshold argument
            let threshold = parseThreshold(from: arguments, defaultThreshold: defaultThreshold)
            let testConfig = parseTestConfiguration(from: arguments)
            return .runTest(threshold: threshold, testConfig: testConfig)
            
        case "--update-baseline":
            let testConfig = parseTestConfiguration(from: arguments)
            return .updateBaseline(testConfig: testConfig)
            
        case "--help", "-h":
            return .help
            
        default:
            print("Unknown argument: \(firstArg)")
            return .help
        }
    }
    
    /// Parses the threshold value from command-line arguments
    /// - Parameters:
    ///   - arguments: All command-line arguments
    ///   - defaultThreshold: Default threshold if none specified
    /// - Returns: The threshold value as a decimal (e.g., 0.05 for 5%)
    private static func parseThreshold(from arguments: [String], defaultThreshold: Double) -> Double {
        // Look for --threshold argument
        if let thresholdIndex = arguments.firstIndex(of: "--threshold"),
           thresholdIndex + 1 < arguments.count {
            let thresholdString = arguments[thresholdIndex + 1]
            
            if let threshold = Double(thresholdString) {
                // Validate threshold range (0-100%)
                if threshold >= 0.0 && threshold <= 100.0 {
                    // Convert percentage to decimal (e.g., 5.0 -> 0.05)
                    return threshold / 100.0
                } else {
                    print("Invalid threshold value: \(thresholdString)%. Must be between 0 and 100. Using default: \(defaultThreshold * 100)%")
                }
            } else {
                print("Invalid threshold value: \(thresholdString). Using default: \(defaultThreshold * 100)%")
            }
        }
        
        return defaultThreshold
    }
    
    /// Parses test configuration from command-line arguments
    /// - Parameter arguments: All command-line arguments
    /// - Returns: TestConfiguration if specified, nil for default
    private static func parseTestConfiguration(from arguments: [String]) -> TestConfiguration? {
        // Check for preset arguments first
        for arg in arguments {
            switch arg {
            case "--simple":
                return TestPreset.simple.createConfiguration()
            case "--moderate":
                return TestPreset.moderate.createConfiguration()
            case "--complex":
                return TestPreset.complex.createConfiguration()
            case "--stress":
                return TestPreset.stress.createConfiguration()
            case "--high-res":
                return TestPreset.highRes.createConfiguration()
            case "--low-res":
                return TestPreset.lowRes.createConfiguration()
            case "--custom":
                return TestPreset.custom(triangleCount: 5000, width: 2560, height: 1440, complexity: 10, scale: 1.0).createConfiguration()
            default:
                continue
            }
        }
        
        // Check for custom parameters
        var triangleCount: Int?
        var width: Int?
        var height: Int?
        var complexity: Int?
        var resolutionScale: Double?
        
        // Parse --triangles argument
        if let trianglesIndex = arguments.firstIndex(of: "--triangles"),
           trianglesIndex + 1 < arguments.count,
           let triangles = Int(arguments[trianglesIndex + 1]) {
            triangleCount = triangles
        }
        
        // Parse --resolution argument (e.g., "1920x1080")
        if let resolutionIndex = arguments.firstIndex(of: "--resolution"),
           resolutionIndex + 1 < arguments.count {
            let resolutionString = arguments[resolutionIndex + 1]
            if let xIndex = resolutionString.firstIndex(of: "x") {
                let widthString = String(resolutionString[..<xIndex])
                let heightString = String(resolutionString[resolutionString.index(after: xIndex)...])
                if let w = Int(widthString), let h = Int(heightString) {
                    width = w
                    height = h
                }
            }
        }
        
        // Parse --complexity argument
        if let complexityIndex = arguments.firstIndex(of: "--complexity"),
           complexityIndex + 1 < arguments.count,
           let comp = Int(arguments[complexityIndex + 1]),
           comp >= 1 && comp <= 10 {
            complexity = comp
        }
        
        // Parse --scale argument
        if let scaleIndex = arguments.firstIndex(of: "--scale"),
           scaleIndex + 1 < arguments.count,
           let scale = Double(arguments[scaleIndex + 1]) {
            resolutionScale = scale
        }
        
        // If any custom parameters were specified, create custom configuration
        if triangleCount != nil || width != nil || height != nil || complexity != nil || resolutionScale != nil {
            return TestConfiguration(
                width: width ?? 1920,
                height: height ?? 1080,
                triangleCount: triangleCount ?? 1,
                geometryComplexity: complexity ?? 1,
                resolutionScale: resolutionScale ?? 1.0,
                testMode: "custom",
                baselineName: "Custom Baseline"
            )
        }
        
        // Return nil for default configuration
        return nil
    }
    
    /// Prints usage information to the console
    static func printUsage() {
        print("""
        Metal Performance Tracker
        
        USAGE:
        Metal-Performance-Tracker [OPTIONS]
        
        BASIC OPTIONS:
        --update-baseline
        Run test and save results as new baseline
        
        --run-test
        Run performance test and compare against baseline
        
        --help, -h
        Show this help message
        
        TEST CONFIGURATION:
        --low-res         Low resolution (100 triangles, 720p)
        --simple          Simple test (1 triangle, 1080p)
        --moderate        Moderate test (100 triangles, 1080p)
        --complex         Complex test (1K triangles, 1080p)
        --high-res        High resolution (1K triangles, 4K)
        --stress          Stress test (10K triangles, 1080p)
        --custom          Custom test (5K triangles, 2560x1440, complexity 10, scale 1.0x)
        
        CUSTOM PARAMETERS:
        --triangles N     Number of triangles to render
        --resolution WxH  Render resolution (e.g., 1920x1080)
        --complexity N    Geometry complexity (1-10)
        --scale N         Resolution scale factor (0.5-4.0)
        --threshold N     Performance threshold percentage (0-100)
        
        -----
        
        EXIT CODES:
        0 - Test passed (performance within threshold)
        1 - Test failed (performance regression detected)
        2 - Error (missing baseline, unsupported GPU, etc.)
        """)
    }
}
