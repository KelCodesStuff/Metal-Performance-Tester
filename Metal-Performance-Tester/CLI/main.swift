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
        
    case .updateGraphicsBaseline(let testConfig):
        return runUpdateGraphicsBaseline(testConfig: testConfig)
        
    case .runGraphicsTest(let threshold, let testConfig):
        return runGraphicsPerformanceTest(threshold: threshold, testConfig: testConfig)
        
    case .updateComputeBaseline(let testConfig):
        return runUpdateComputeBaseline(testConfig: testConfig)
        
    case .runComputeTest(let threshold, let testConfig):
        return runComputePerformanceTest(threshold: threshold, testConfig: testConfig)
    }
}

// MARK: Graphics Baseline Update Operations
func runUpdateGraphicsBaseline(testConfig: TestConfiguration? = nil) -> Int32 {
    let graphicsBaselineManager = GraphicsBaselineManager()
    return graphicsBaselineManager.runUpdateBaseline(testConfig: testConfig)
}

// MARK: Graphics Performance Test Operations
func runGraphicsPerformanceTest(threshold: Double, testConfig: TestConfiguration? = nil) -> Int32 {
    let graphicsTestManager = GraphicsTestManager()
    return graphicsTestManager.runPerformanceTest(threshold: threshold, testConfig: testConfig)
}

// MARK: Compute Baseline Update Operations
func runUpdateComputeBaseline(testConfig: TestConfiguration? = nil) -> Int32 {
    let computeBaselineManager = ComputeBaselineManager()
    return computeBaselineManager.runUpdateBaseline(testConfig: testConfig)
}

// MARK: Compute Performance Test Operations
func runComputePerformanceTest(threshold: Double, testConfig: TestConfiguration? = nil) -> Int32 {
    let computeTestManager = ComputeTestManager()
    return computeTestManager.runPerformanceTest(threshold: threshold, testConfig: testConfig)
}

// Run the main function and exit with the appropriate code
let exitCode = main()
exit(exitCode)
