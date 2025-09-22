//
//  main.swift
//  Metal-Performance-Tracker
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

/// Runs the performance test and updates the baseline with multiple iterations
func runUpdateBaseline(testConfig: TestConfiguration? = nil) -> Int32 {
    print("Updating performance baseline...")
    
    // Initialize Metal and renderer
    guard let device = MTLCreateSystemDefaultDevice() else {
        print("Metal is not supported on this device.")
        return ExitCode.error.rawValue
    }
    
    let config = testConfig ?? TestPreset.moderate.createConfiguration()
    guard let renderer = Renderer(device: device, testConfig: config) else {
        print("Failed to initialize the Renderer.")
        return ExitCode.error.rawValue
    }
    
    // Run multiple iterations for statistical baseline
    guard let measurementSet = renderer.runMultipleIterations(iterations: 100, showProgress: true) else {
        print("Performance measurement not available on this GPU.")
        print("Counter sampling is not supported. Cannot establish baseline.")
        return ExitCode.error.rawValue
    }
    
    // Save as new baseline
    let baselineManager = PerformanceBaselineManager()
    do {
        try baselineManager.saveBaseline(measurementSet)
        print("Baseline updated successfully!")
        return ExitCode.success.rawValue
    } catch {
        print("Failed to save baseline: \(error)")
        return ExitCode.error.rawValue
    }
}

/// Runs the performance test and compares against baseline using statistical analysis
func runPerformanceTest(threshold: Double, testConfig: TestConfiguration? = nil) -> Int32 {
    print("Running performance test...")
    
    // Check if baseline exists
    let baselineManager = PerformanceBaselineManager()
    guard baselineManager.baselineExists() else {
        print("\nError: No baseline found.")
        print("Run with --update-baseline first to establish a performance baseline.")
        return ExitCode.error.rawValue
    }
    
    // Initialize Metal and renderer
    guard let device = MTLCreateSystemDefaultDevice() else {
        print("\nError: Metal is not supported on this device.")
        return ExitCode.error.rawValue
    }
    
    let config = testConfig ?? TestPreset.moderate.createConfiguration()
    guard let renderer = Renderer(device: device, testConfig: config, showConfiguration: false) else {
        print("\nError: Failed to initialize the Renderer.")
        return ExitCode.error.rawValue
    }
    
    // Run multiple iterations for statistical comparison
    guard let currentMeasurementSet = renderer.runMultipleIterations(iterations: 100, showProgress: true, showDetailedResults: false) else {
        print("\nError: Performance measurement not available on this GPU.")
        print("Counter sampling is not supported.")
        return ExitCode.error.rawValue
    }
    
    // Load baseline and compare statistically
    do {
        let baselineMeasurementSet = try baselineManager.loadBaseline()
        let comparisonResult = RegressionChecker.compareStatistical(
            current: currentMeasurementSet,
            baseline: baselineMeasurementSet,
            significanceLevel: 0.05
        )
        
        // Create and save test result
        let testResult = PerformanceTestResult(
            current: currentMeasurementSet,
            baseline: baselineMeasurementSet,
            comparison: comparisonResult
        )
        
        // Save test result to JSON file
        do {
            try baselineManager.saveTestResult(testResult)
        } catch {
            print("\nWarning: Failed to save test result: \(error)")
            // Continue execution even if saving fails
        }
        
        // Generate and print statistical report
        let report = RegressionChecker.generateStatisticalReport(
            current: currentMeasurementSet,
            baseline: baselineMeasurementSet,
            result: comparisonResult
        )
        print(report)
        
        // Return appropriate exit code based on statistical significance
        if comparisonResult.isRegression {
            return ExitCode.failure.rawValue
        } else {
            return ExitCode.success.rawValue
        }
        
    } catch {
        print("\nError: Failed to load baseline: \(error)")
        return ExitCode.error.rawValue
    }
}

// Run the main function and exit with the appropriate code
exit(main())
