//
//  GPUDetectionTest.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/24/25.
//  Comprehensive GPU detection testing system
//

import Foundation
import Metal

/// Comprehensive GPU detection testing system
class GPUDetectionTest {
    
    /// Run all GPU detection tests
    static func runAllTests() {
        
        testBasicDetection()
        testSeriesDetection()
        
        print("\nAll GPU detection tests completed!")
    }
    
    /// Test basic GPU detection functionality
    private static func testBasicDetection() {
        print("\nTest 1: Basic GPU Detection")
        
        let devices = MTLCopyAllDevices()
        print("Found \(devices.count) Metal device(s)")
        
        for (index, device) in devices.enumerated() {
            let tier = GPUDetector.detectPerformanceTier(for: device)
            print("\nDevice \(index + 1): \(device.name)")
            print("- Performance Tier: \(tier.rawValue)")
            print("- Target FPS: \(tier.targetFPS)")
            print("- Base Triangle Count: \(tier.baseTriangleCount)")
            print("- Optimal Resolution: \(Int(tier.optimalResolution.width))x\(Int(tier.optimalResolution.height))")
        }
    }
    
    
    
    /// Test M Series GPU detection and tier assignment
    private static func testSeriesDetection() {
        print(String(repeating: "-", count: 60))
        print("Test 2: GPU Series Detection")
        
        let devices = MTLCopyAllDevices()
        
        for device in devices {
            let tier = GPUDetector.detectPerformanceTier(for: device)
            let deviceName = device.name.lowercased()
            
            print("\nHardware: \(device.name)")
            
            // Test M Series GPU detection
            if deviceName.contains("apple m") {
                print("- Apple Silicon GPU detected")
                
                // Determine expected tier based on M Series variant
                let expectedTier = getExpectedTierForMSeries(deviceName)
                let expectedFPS = expectedTier.targetFPS
                
                print("- Expected: \(expectedTier.rawValue) tier (\(expectedFPS) FPS)")
                print("- Actual: \(tier.rawValue) (\(tier.targetFPS) FPS)")
                print("- Status: \(tier == expectedTier ? "CORRECT" : "INCORRECT")")
                
                // Additional M Series specific info
                if deviceName.contains("ultra") {
                    print("- Ultra variant: Highest performance tier")
                } else if deviceName.contains("max") {
                    print("- Max variant: High performance tier")
                } else if deviceName.contains("pro") {
                    print("- Pro variant: Medium performance tier")
                } else {
                    print("- Base variant: Low performance tier")
                }
            } else {
                print("- Non-M Series GPU detected")
                print("- Tier: \(tier.rawValue) (\(tier.targetFPS) FPS)")
            }
        }
    }
    
    /// Helper function to determine expected tier for M Series GPUs
    private static func getExpectedTierForMSeries(_ deviceName: String) -> GPUPerformanceTier {
        if deviceName.contains("ultra") {
            return .ultraHigh
        } else if deviceName.contains("max") {
            return .high
        } else if deviceName.contains("pro") {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Test Runner

/// Run GPU detection tests from command line
func runGPUDetectionTests() {
    print("Starting GPU Detection Tests...")
    
    GPUDetectionTest.runAllTests()
}
