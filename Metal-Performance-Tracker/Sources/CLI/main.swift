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
        
    case .updateBaseline:
        return runUpdateBaseline()
        
    case .runTest(let threshold):
        return runPerformanceTest(threshold: threshold)
    }
}

/// Runs the performance test and updates the baseline
func runUpdateBaseline() -> Int32 {
    print("Updating performance baseline...")
    
    // Initialize Metal and renderer
    guard let device = MTLCreateSystemDefaultDevice() else {
        print("Metal is not supported on this device.")
        return ExitCode.error.rawValue
    }
    
    guard let renderer = Renderer(device: device) else {
        print("Failed to initialize the Renderer.")
        return ExitCode.error.rawValue
    }
    
    // Run the performance test
    guard let result = renderer.draw() else {
        print("Performance measurement not available on this GPU.")
        print("   Counter sampling is not supported. Cannot establish baseline.")
        return ExitCode.error.rawValue
    }
    
    // Save as new baseline
    let baselineManager = PerformanceBaselineManager()
    do {
        try baselineManager.saveBaseline(result)
        print("Baseline updated successfully!")
        return ExitCode.success.rawValue
    } catch {
        print("Failed to save baseline: \(error)")
        return ExitCode.error.rawValue
    }
}

/// Runs the performance test and compares against baseline
func runPerformanceTest(threshold: Double) -> Int32 {
    print("Running performance test...")
    
    // Check if baseline exists
    let baselineManager = PerformanceBaselineManager()
    guard baselineManager.baselineExists() else {
        print("No baseline found. Run with --update-baseline first.")
        return ExitCode.error.rawValue
    }
    
    // Initialize Metal and renderer
    guard let device = MTLCreateSystemDefaultDevice() else {
        print("Metal is not supported on this device.")
        return ExitCode.error.rawValue
    }
    
    guard let renderer = Renderer(device: device) else {
        print("Failed to initialize the Renderer.")
        return ExitCode.error.rawValue
    }
    
    // Run the performance test
    guard let currentResult = renderer.draw() else {
        print("Performance measurement not available on this GPU.")
        print("Counter sampling is not supported.")
        return ExitCode.error.rawValue
    }
    
    // Load baseline and compare
    do {
        let baselineResult = try baselineManager.loadBaseline()
        let comparisonResult = RegressionChecker.compare(
            current: currentResult,
            baseline: baselineResult,
            threshold: threshold
        )
        
        // Generate and print report
        let report = RegressionChecker.generateReport(
            current: currentResult,
            baseline: baselineResult,
            result: comparisonResult,
            threshold: threshold
        )
        print(report)
        
        // Return appropriate exit code
        switch comparisonResult {
        case .passed:
            return ExitCode.success.rawValue
        case .failed:
            return ExitCode.failure.rawValue
        }
        
    } catch {
        print("Failed to load baseline: \(error)")
        return ExitCode.error.rawValue
    }
}

// Run the main function and exit with the appropriate code
exit(main())
