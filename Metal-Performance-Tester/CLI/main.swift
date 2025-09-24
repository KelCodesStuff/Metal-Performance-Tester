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
        // Display usage information and available commands
        CommandLineParser.printUsage()
        return ExitCode.success.rawValue
        
    case .updateBaseline(let testConfig):
        // Create or update performance baseline with specified configuration
        return runUpdateBaseline(testConfig: testConfig)
        
    case .runTest(let threshold, let testConfig):
        // Run performance test and compare against baseline
        return runPerformanceTest(threshold: threshold, testConfig: testConfig)
        
    case .testGPU:
        // Test GPU detection system and display hardware information
        runGPUDetectionTests()
        return ExitCode.success.rawValue
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
