//
//  CommandLineParser.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation

/// Represents the different modes the performance tester can run in
enum TestMode {
    case runTest(threshold: Double, testConfig: TestConfiguration?)
    case updateBaseline(testConfig: TestConfiguration?)
    case testGPU
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
            
        case "--test-gpu":
            return .testGPU
            
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
            case "--low-res":
                return TestPreset.lowRes.createConfiguration()
            case "--moderate":
                return TestPreset.moderate.createConfiguration()
            case "--complex":
                return TestPreset.complex.createConfiguration()
            case "--high-res":
                return TestPreset.highRes.createConfiguration()
            case "--ultra-high-res":
                return TestPreset.ultraHighRes.createConfiguration()
            default:
                continue
            }
        }
        
        // Return nil for default configuration
        return nil
    }
    
    /// Prints usage information to the console
    static func printUsage() {
        print("""
        Metal Performance Tester
        
        USAGE:
        Metal-Performance-Tester [OPTIONS]
        
        BASIC OPTIONS:
        --update-baseline
        Run test and save results as new baseline
        
        --run-test
        Run performance test and compare against baseline
        
        --test-gpu
        Test GPU detection system and show hardware information
        
        --help, -h
        Show this help message
        
        TEST CONFIGURATION:
        --low-res         Low resolution (720p, mobile/low-end testing)
        --moderate        Moderate test (1080p, daily development testing)
        --complex         Complex test (1440p, feature development)
        --high-res        High resolution (4K, display scaling testing)
        --ultra-high-res  Ultra high resolution (8K, ultra-high resolution testing)
        
        PARAMETERS:
        --threshold N     Performance threshold percentage (0-100)
        
        -----
        
        EXIT CODES:
        0 - Test passed (performance within threshold)
        1 - Test failed (performance regression detected)
        2 - Error (missing baseline, unsupported GPU, etc.)
        """)
    }
}
