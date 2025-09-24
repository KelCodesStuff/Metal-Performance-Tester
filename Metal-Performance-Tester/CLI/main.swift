//
//  main.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/17/25.
//

import Metal
import Foundation

/// Exit codes for different scenarios
enum ExitCode: Int32 {
    case success = 0      // Test passed
    case failure = 1      // Performance regression detected
    case error = 2        // Error (missing baseline, unsupported GPU, etc.)
}

/// Main application entry point
func main() -> Int32 {
    // Parse command-line arguments
    let arguments = Array(CommandLine.arguments.dropFirst())
    let testMode = CommandLineParser.parse(arguments: arguments)
    
    switch testMode {
    case .help:
        CommandLineParser.printUsage()
        return ExitCode.success.rawValue
        
    case .updateBaseline(let testConfig):
        return runUpdateBaseline(testConfig: testConfig)
        
    case .runTest(let threshold, let testConfig):
        return runPerformanceTest(threshold: threshold, testConfig: testConfig)
    }
}

// MARK: Baseline Update Operations
func runUpdateBaseline(testConfig: TestConfiguration? = nil) -> Int32 {
    let baselineManager = BaselineManager()
    return baselineManager.runUpdateBaseline(testConfig: testConfig)
}

// MARK: Performance Test Operations
func runPerformanceTest(threshold: Double, testConfig: TestConfiguration? = nil) -> Int32 {
    let performanceTestManager = PerformanceTestManager()
    return performanceTestManager.runPerformanceTest(threshold: threshold, testConfig: testConfig)
}

// Run the main function and exit with the appropriate code
let exitCode = main()
exit(exitCode)
