//
//  CommandLineParser.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation

/// Represents the different modes the performance tester can run in
enum TestMode {
    case runGraphicsTest(threshold: Double, testConfig: TestConfiguration?)
    case updateGraphicsBaseline(testConfig: TestConfiguration?)
    case runComputeTest(threshold: Double, testConfig: TestConfiguration?)
    case updateComputeBaseline(testConfig: TestConfiguration?)
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
        case "--graphics-test":
            // Parse optional threshold argument
            let threshold = parseThreshold(from: arguments, defaultThreshold: defaultThreshold)
            let testConfig = parseGraphicsTestConfiguration(from: arguments)
            return .runGraphicsTest(threshold: threshold, testConfig: testConfig)
            
        case "--update-graphics-baseline":
            let testConfig = parseGraphicsTestConfiguration(from: arguments)
            return .updateGraphicsBaseline(testConfig: testConfig)
            
        case "--compute-test":
            // Parse optional threshold argument
            let threshold = parseThreshold(from: arguments, defaultThreshold: defaultThreshold)
            let testConfig = parseComputeTestConfiguration(from: arguments)
            return .runComputeTest(threshold: threshold, testConfig: testConfig)
            
        case "--update-compute-baseline":
            let testConfig = parseComputeTestConfiguration(from: arguments)
            return .updateComputeBaseline(testConfig: testConfig)
            
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
    
    /// Parses graphics test configuration from command-line arguments
    /// - Parameter arguments: All command-line arguments
    /// - Returns: TestConfiguration if specified, nil for default
    private static func parseGraphicsTestConfiguration(from arguments: [String]) -> TestConfiguration? {
        // Check for graphics preset arguments first
        for arg in arguments {
            switch arg {
            case "--graphics-low":
                return TestPreset.lowRes.createConfiguration()
            case "--graphics-moderate":
                return TestPreset.moderate.createConfiguration()
            case "--graphics-complex":
                return TestPreset.complex.createConfiguration()
            case "--graphics-high":
                return TestPreset.highRes.createConfiguration()
            case "--graphics-ultra-high":
                return TestPreset.ultraHighRes.createConfiguration()
            default:
                continue
            }
        }
        
        // Return nil for default configuration
        return nil
    }
    
    /// Parses compute test configuration from command-line arguments
    /// - Parameter arguments: All command-line arguments
    /// - Returns: TestConfiguration if specified, nil for default
    private static func parseComputeTestConfiguration(from arguments: [String]) -> TestConfiguration? {
        // Check for compute preset arguments first
        for arg in arguments {
            switch arg {
            case "--compute-low":
                return TestPreset.computeLow.createConfiguration()
            case "--compute-moderate":
                return TestPreset.computeModerate.createConfiguration()
            case "--compute-complex":
                return TestPreset.computeComplex.createConfiguration()
            case "--compute-high":
                return TestPreset.computeHigh.createConfiguration()
            case "--compute-ultra-high":
                return TestPreset.computeUltraHigh.createConfiguration()
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
        A comprehensive tool for testing GPU performance regressions in Metal applications
        
        USAGE:
        Metal-Performance-Tester [COMMAND] [OPTIONS]
        
        COMMANDS:
        --update-graphics-baseline Run graphics test and save results as new baseline
        --graphics-test            Run graphics performance test and compare against baseline
        --update-compute-baseline  Run compute test and save results as new baseline
        --compute-test             Run compute performance test and compare against baseline
        --help, -h                 Show this help message
        
        GRAPHICS TEST CONFIGURATIONS:
        --graphics-low         Low resolution (720p, mobile/low-end testing)
        --graphics-moderate    Moderate test (1080p, daily development testing) [DEFAULT]
        --graphics-complex     Complex test (1440p, feature development)
        --graphics-high        High resolution (4K, display scaling testing)
        --graphics-ultra-high  Ultra high resolution (8K, ultra-high resolution testing)
        
        COMPUTE TEST CONFIGURATIONS:
        --compute-low        Low compute workload (128x128, basic compute testing)
        --compute-moderate   Moderate compute workload (256x256, daily compute testing)
        --compute-complex    Complex compute workload (384x384, feature compute testing)
        --compute-high       High compute workload (512x512, high-performance compute testing)
        --compute-ultra-high Ultra-high compute workload (1024x1024, ultra-high compute testing)
        
        EXAMPLES:
        # Graphics Testing
        Metal-Performance-Tester --update-graphics-baseline --graphics-moderate
        Metal-Performance-Tester --graphics-test --graphics-moderate
        
        # Compute Testing
        Metal-Performance-Tester --update-compute-baseline --compute-moderate
        Metal-Performance-Tester --compute-test --compute-high
        
        # Quick tests with default settings
        Metal-Performance-Tester --graphics-test
        Metal-Performance-Tester --compute-test
        
        REQUIREMENTS:
        • macOS 15.0 or later
        • Apple Silicon GPU (M1/M2/M3/M4 series)
        • Metal 2.0 or later
        
        -----
        
        EXIT CODES:
        0 - Test passed (performance within threshold)
        1 - Test failed (performance regression detected)
        2 - Error (missing baseline, unsupported GPU, etc.)
        
        For more information, visit: https://github.com/KelCodesStuff/Metal-Performance-Tester
        """)
    }
}
