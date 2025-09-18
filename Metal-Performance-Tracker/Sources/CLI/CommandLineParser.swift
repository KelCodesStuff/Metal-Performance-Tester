//
//  CommandLineParser.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/17/25.
//

import Foundation

/// Represents the different modes the performance tracker can run in
enum TestMode {
    case runTest(threshold: Double)
    case updateBaseline
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
            return .runTest(threshold: threshold)
            
        case "--update-baseline":
            return .updateBaseline
            
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
                // Convert percentage to decimal (e.g., 5.0 -> 0.05)
                return threshold / 100.0
            } else {
                print("Invalid threshold value: \(thresholdString). Using default: \(defaultThreshold * 100)%")
            }
        }
        
        return defaultThreshold
    }
    
    /// Prints usage information to the console
    static func printUsage() {
        print("""
        Metal Performance Tracker
        
        USAGE:
        Metal-Performance-Tracker [OPTIONS]
        
        OPTIONS:
        --update-baseline
        Run test and save results as new baseline
        
        --run-test
        Run performance test and compare against baseline
        
        --help, -h
        Show this help message
        
        -----
        
        EXIT CODES:
        0 - Test passed (performance within threshold)
        1 - Test failed (performance regression detected)
        2 - Error (missing baseline, unsupported GPU, etc.)
        """)
    }
}
