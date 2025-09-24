//
//  DynamicConfigurationManager.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/24/25.
//  Dynamic workload scaling based on GPU performance tier
//

import Foundation
import Metal

/// Manages dynamic test configuration based on detected GPU performance tier
class DynamicConfigurationManager {
    
    /// Generate optimal test configuration for detected GPU tier
    static func generateOptimalConfiguration(for tier: GPUPerformanceTier) -> TestConfiguration {
        print("🔧 Generating optimal configuration for \(tier.rawValue) tier GPU...")
        
        // Create optimized configuration with dynamic adjustments
        let optimizedConfig = TestConfiguration(
            width: Int(tier.optimalResolution.width),
            height: Int(tier.optimalResolution.height),
            pixelFormat: "MTLPixelFormat(rawValue: 80)",
            triangleCount: tier.baseTriangleCount,
            geometryComplexity: calculateOptimalGeometryComplexity(for: tier),
            resolutionScale: calculateOptimalResolutionScale(for: tier),
            testMode: "dynamic",
            baselineName: "Dynamic \(tier.rawValue.capitalized) Baseline"
        )
        
        print("✅ Generated configuration:")
        print("   - Resolution: \(optimizedConfig.width)x\(optimizedConfig.height)")
        print("   - Triangle Count: \(optimizedConfig.triangleCount)")
        print("   - Geometry Complexity: \(optimizedConfig.geometryComplexity)/10")
        print("   - Resolution Scale: \(optimizedConfig.resolutionScale)x")
        
        return optimizedConfig
    }
    
    /// Calculate optimal geometry complexity based on GPU tier
    private static func calculateOptimalGeometryComplexity(for tier: GPUPerformanceTier) -> Int {
        switch tier {
        case .low:
            return 3  // Conservative complexity for low-tier GPUs
        case .medium:
            return 6  // Balanced complexity for medium-tier GPUs
        case .high:
            return 8  // High complexity for high-tier GPUs
        case .ultraHigh:
            return 10 // Maximum complexity for ultra-high-tier GPUs
        }
    }
    
    /// Calculate optimal resolution scale based on GPU tier
    private static func calculateOptimalResolutionScale(for tier: GPUPerformanceTier) -> Double {
        switch tier {
        case .low:
            return 0.5  // Lower resolution for low-tier GPUs
        case .medium:
            return 0.75 // Moderate resolution for medium-tier GPUs
        case .high:
            return 1.0  // Full resolution for high-tier GPUs
        case .ultraHigh:
            return 1.25 // Enhanced resolution for ultra-high-tier GPUs
        }
    }
    
    /// Calculate optimal iteration count based on GPU tier
    private static func calculateOptimalIterations(for tier: GPUPerformanceTier) -> Int {
        switch tier {
        case .low:
            return 50   // Fewer iterations for low-tier GPUs
        case .medium:
            return 75   // Moderate iterations for medium-tier GPUs
        case .high:
            return 100  // Standard iterations for high-tier GPUs
        case .ultraHigh:
            return 150  // More iterations for ultra-high-tier GPUs
        }
    }
    
    /// Auto-detect GPU and generate optimal configuration
    static func autoConfigure() -> TestConfiguration {
        print("🔍 Auto-detecting GPU performance tier...")
        
        let devices = MTLCopyAllDevices()
        guard let device = devices.first else {
            print("⚠️ No Metal devices found, using default configuration")
            return TestPreset.moderate.createConfiguration()
        }
        
        let tier = GPUDetector.detectPerformanceTier(for: device)
        print("✅ Detected GPU: \(device.name)")
        print("✅ Performance Tier: \(tier.rawValue)")
        
        return generateOptimalConfiguration(for: tier)
    }
    
    /// Generate configuration for specific GPU tier (for testing)
    static func generateConfigurationForTier(_ tier: GPUPerformanceTier) -> TestConfiguration {
        print("🎯 Generating configuration for \(tier.rawValue) tier...")
        return generateOptimalConfiguration(for: tier)
    }
    
    /// Compare dynamic vs static configurations
    static func compareConfigurations() {
        print("\n📊 Configuration Comparison:")
        print(String(repeating: "-", count: 50))
        
        for tier in [GPUPerformanceTier.low, .medium, .high, .ultraHigh] {
            let dynamicConfig = generateOptimalConfiguration(for: tier)
            let staticConfig = TestPreset.moderate.createConfiguration()
            
            print("\n\(tier.rawValue.capitalized) Tier:")
            print("  Dynamic:  \(dynamicConfig.width)x\(dynamicConfig.height), \(dynamicConfig.triangleCount) triangles, \(dynamicConfig.geometryComplexity)/10 complexity")
            print("  Static:   \(staticConfig.width)x\(staticConfig.height), \(staticConfig.triangleCount) triangles, \(staticConfig.geometryComplexity)/10 complexity")
        }
    }
}

// MARK: - TestConfiguration Extensions

extension TestConfiguration {
    /// Create a copy with modified parameters
    func withModifications(
        width: Int? = nil,
        height: Int? = nil,
        triangleCount: Int? = nil,
        geometryComplexity: Int? = nil,
        resolutionScale: Double? = nil
    ) -> TestConfiguration {
        return TestConfiguration(
            width: width ?? self.width,
            height: height ?? self.height,
            pixelFormat: self.pixelFormat,
            triangleCount: triangleCount ?? self.triangleCount,
            geometryComplexity: geometryComplexity ?? self.geometryComplexity,
            resolutionScale: resolutionScale ?? self.resolutionScale,
            testMode: self.testMode,
            baselineName: self.baselineName
        )
    }
}
