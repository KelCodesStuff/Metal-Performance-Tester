//
//  TestConfiguration.swift
//  Metal-Performance-Tester
//
//  Created by Kelvin Reid on 9/18/25.
//

import Foundation
import Metal

/// Test type enumeration
enum TestType: String, Codable {
    case graphics = "graphics"
    case compute = "compute"
    case both = "both"
}

/// Threadgroup size structure for compute shaders
struct ThreadgroupSize: Codable {
    let width: Int
    let height: Int
    let depth: Int
    
    init(width: Int, height: Int, depth: Int) {
        self.width = width
        self.height = height
        self.depth = depth
    }
    
    /// Convert to MTLSize
    func toMTLSize() -> MTLSize {
        return MTLSize(width: width, height: height, depth: depth)
    }
}

/// Configuration parameters for the performance test
struct TestConfiguration: Codable {
    /// Render target dimensions
    let width: Int
    let height: Int
    
    /// Pixel format used for rendering
    let pixelFormat: String
    
    /// Number of triangles to render
    let triangleCount: Int
    
    /// Geometry complexity level (1-10 scale)
    let geometryComplexity: Int
    
    /// Resolution scale factor (1.0 = native, 0.5 = half resolution, 2.0 = double resolution)
    let resolutionScale: Double
    
    /// Test mode identifier
    let testMode: String
    
    /// Timestamp when the test was run
    let timestamp: Date
    
    /// Name of the baseline configuration
    let baselineName: String
    
    // MARK: - Compute Testing Parameters
    
    /// Threadgroup size for compute shaders (width x height x depth)
    let threadgroupSize: ThreadgroupSize?
    
    /// Number of threadgroups to dispatch
    let threadgroupCount: ThreadgroupSize?
    
    /// Compute workload complexity (1-10 scale)
    let computeWorkloadComplexity: Int?
    
    /// Test type (graphics, compute, or both)
    let testType: TestType
    
    /// Creates a test configuration with default values
    init(width: Int = 1920, height: Int = 1080, pixelFormat: String = "MTLPixelFormat(rawValue: 80)", 
         triangleCount: Int = 1, geometryComplexity: Int = 1, resolutionScale: Double = 1.0, 
         testMode: String = "simple", baselineName: String = "Simple Baseline",
         threadgroupSize: ThreadgroupSize? = nil, threadgroupCount: ThreadgroupSize? = nil, 
         computeWorkloadComplexity: Int? = nil, testType: TestType = .graphics) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.triangleCount = triangleCount
        self.geometryComplexity = geometryComplexity
        self.resolutionScale = resolutionScale
        self.testMode = testMode
        self.timestamp = Date()
        self.baselineName = baselineName
        self.threadgroupSize = threadgroupSize
        self.threadgroupCount = threadgroupCount
        self.computeWorkloadComplexity = computeWorkloadComplexity
        self.testType = testType
    }
    
    /// Calculates the effective resolution after scaling
    var effectiveWidth: Int {
        return Int(Double(width) * resolutionScale)
    }
    
    /// Calculates the effective resolution after scaling
    var effectiveHeight: Int {
        return Int(Double(height) * resolutionScale)
    }
    
    /// Returns a description of the configuration
    var description: String {
        return baselineName
    }
    
    /// Returns the parameters description
    var parametersDescription: String {
        var description = "- Resolution: \(width)x\(height)"
        if resolutionScale != 1.0 {
            description += " (effective: \(effectiveWidth)x\(effectiveHeight))"
        }
        description += "\n- Triangle count: \(triangleCount)"
        description += "\n- Geometry complexity: \(geometryComplexity)/10"
        description += "\n- Resolution scale: \(String(format: "%.1f", resolutionScale))x"
        return description
    }
}

/// Predefined test configurations for common scenarios
enum TestPreset {
    // MARK: - Graphics Test Presets
    case graphicsLow        // 1280×720, Mobile/low-end testing
    case graphicsModerate   // 1920×1080, Daily development testing
    case graphicsComplex    // 2560×1440, Feature development
    case graphicsHigh       // 3840×2160, Display scaling testing
    case graphicsMax        // 7680×4320, Max resolution testing
    
    // MARK: - Compute Test Presets
    case computeLow         // Low compute workload
    case computeModerate    // Moderate compute workload
    case computeComplex     // Complex compute workload
    case computeHigh        // High compute workload
    case computeMax         // Max compute workload
    
    /// Creates a test configuration for this preset
    func createConfiguration() -> TestConfiguration {
        switch self {
            // MARK: - Graphics Test Configurations
        case .graphicsLow:
            // Low GPU Load: 1280×720 @ 1000 triangles, complexity 6/10
            return TestConfiguration(width: 1280, height: 720, triangleCount: 4000,
                                   geometryComplexity: 6, resolutionScale: 1.0, testMode: "graphics-low",
                                   baselineName: "Low Graphics Baseline")
            
        case .graphicsModerate:
            // Moderate GPU Load: 1920×1080 @ 2000 triangles, complexity 7/10
            return TestConfiguration(width: 1920, height: 1080, triangleCount: 4000,
                                   geometryComplexity: 7, resolutionScale: 1.0, testMode: "graphics-moderate",
                                   baselineName: "Moderate Graphics Baseline")
            
        case .graphicsComplex:
            // Complex GPU Load: 2560x1440 @ 5000 triangles, complexity 9/10
            return TestConfiguration(width: 2560, height: 1440, triangleCount: 5000,
                                   geometryComplexity: 9, resolutionScale: 1.0, testMode: "graphics-complex",
                                   baselineName: "Complex Graphics Baseline")
            
        case .graphicsHigh:
            // High GPU Load: 3840×2160 @ 8000 triangles, complexity 9/10
            return TestConfiguration(width: 3840, height: 2160, triangleCount: 8000,
                                   geometryComplexity: 9, resolutionScale: 1.0, testMode: "graphics-high",
                                   baselineName: "High Graphics Baseline")
            
        case .graphicsMax:
            // Max GPU Load: 7680×4320 @ 15000 triangles, complexity 10/10
            return TestConfiguration(width: 7680, height: 4320, triangleCount: 10000,
                                   geometryComplexity: 10, resolutionScale: 1.0, testMode: "graphics-max",
                                   baselineName: "Max Graphics Baseline")
            
        // MARK: - Compute Test Configurations
        case .computeLow:
            // Low Compute Load: 128x128 threadgroups, complexity 3/10
            return TestConfiguration(width: 128, height: 128, triangleCount: 0,
                                   geometryComplexity: 1, resolutionScale: 1.0, testMode: "compute-low",
                                   baselineName: "Low Compute Baseline",
                                   threadgroupSize: ThreadgroupSize(width: 16, height: 16, depth: 1),
                                   threadgroupCount: ThreadgroupSize(width: 8, height: 8, depth: 1),
                                   computeWorkloadComplexity: 3, testType: .compute)
            
        case .computeModerate:
            // Moderate Compute Load: 256x256 threadgroups, complexity 5/10
            return TestConfiguration(width: 256, height: 256, triangleCount: 0,
                                   geometryComplexity: 1, resolutionScale: 1.0, testMode: "compute-moderate",
                                   baselineName: "Moderate Compute Baseline",
                                   threadgroupSize: ThreadgroupSize(width: 16, height: 16, depth: 1),
                                   threadgroupCount: ThreadgroupSize(width: 16, height: 16, depth: 1),
                                   computeWorkloadComplexity: 5, testType: .compute)
            
        case .computeComplex:
            // Complex Compute Load: 384x384 threadgroups, complexity 7/10
            return TestConfiguration(width: 384, height: 384, triangleCount: 0,
                                   geometryComplexity: 1, resolutionScale: 1.0, testMode: "compute-complex",
                                   baselineName: "Complex Compute Baseline",
                                   threadgroupSize: ThreadgroupSize(width: 16, height: 16, depth: 1),
                                   threadgroupCount: ThreadgroupSize(width: 24, height: 24, depth: 1),
                                   computeWorkloadComplexity: 7, testType: .compute)
            
        case .computeHigh:
            // High Compute Load: 512x512 threadgroups, complexity 8/10
            return TestConfiguration(width: 512, height: 512, triangleCount: 0,
                                   geometryComplexity: 1, resolutionScale: 1.0, testMode: "compute-high",
                                   baselineName: "High Compute Baseline",
                                   threadgroupSize: ThreadgroupSize(width: 16, height: 16, depth: 1),
                                   threadgroupCount: ThreadgroupSize(width: 32, height: 32, depth: 1),
                                   computeWorkloadComplexity: 8, testType: .compute)
            
        case .computeMax:
            // Max Compute Load: 1024x1024 threadgroups, complexity 10/10
            return TestConfiguration(width: 1024, height: 1024, triangleCount: 0,
                                   geometryComplexity: 1, resolutionScale: 1.0, testMode: "compute-max",
                                   baselineName: "Max Compute Baseline",
                                   threadgroupSize: ThreadgroupSize(width: 16, height: 16, depth: 1),
                                   threadgroupCount: ThreadgroupSize(width: 64, height: 64, depth: 1),
                                   computeWorkloadComplexity: 10, testType: .compute)
        }
    }
    
    /// Name of the preset
    var name: String {
        switch self {
        case .graphicsLow: return "Low Resolution (720p, Mobile Testing)"
        case .graphicsModerate: return "Moderate (1080p, Daily Development)"
        case .graphicsComplex: return "Complex (1080p, Feature Development)"
        case .graphicsHigh: return "High Resolution (4K, Display Scaling)"
        case .graphicsMax: return "Max Resolution (8K, Max Resolution Testing)"
        case .computeLow: return "Compute Low (128x128, Basic Compute Testing)"
        case .computeModerate: return "Compute Moderate (256x256, Daily Compute Testing)"
        case .computeComplex: return "Compute Complex (384x384, Feature Compute Testing)"
        case .computeHigh: return "Compute High (512x512, High-Performance Compute Testing)"
        case .computeMax: return "Compute Max (1024x1024, Max Compute Testing)"
        }
    }
}

/// Helper functions for test configuration management
struct TestConfigurationHelper {
    
    /// Generates triangle vertices based on complexity level
    static func generateTriangleVertices(count: Int, complexity: Int) -> [Float] {
        var vertices: [Float] = []
        
        // Base triangle size decreases as complexity increases
        let baseSize = max(0.1, 1.0 - Double(complexity - 1) * 0.08)
        
        for i in 0..<count {
            // Distribute triangles across the screen
            let row = i / 100  // 100 triangles per row
            let col = i % 100
            
            // Calculate position offset
            let xOffset = (Float(col) - 50.0) * 0.02  // Spread across screen
            let yOffset = (Float(row) - 30.0) * 0.02  // Spread vertically
            
            // Generate triangle vertices with deterministic variations for consistent performance
            // Use triangle index to create predictable size variations
            let sizeVariation = sin(Float(i) * 0.1) * 0.2 + 1.0  // Deterministic size variation
            let size = Float(baseSize) * sizeVariation
            let rotation = Float(i) * 0.1  // Slight rotation per triangle
            
            // Calculate rotated triangle vertices
            let cosR = cos(rotation)
            let sinR = sin(rotation)
            
            // Triangle 1 (top center)
            let x1 = xOffset + size * 0.0 * cosR - size * 0.5 * sinR
            let y1 = yOffset + size * 0.0 * sinR + size * 0.5 * cosR
            vertices.append(contentsOf: [x1, y1, 0.0])
            
            // Triangle 2 (bottom left)
            let x2 = xOffset + size * -0.5 * cosR - size * -0.5 * sinR
            let y2 = yOffset + size * -0.5 * sinR + size * -0.5 * cosR
            vertices.append(contentsOf: [x2, y2, 0.0])
            
            // Triangle 3 (bottom right)
            let x3 = xOffset + size * 0.5 * cosR - size * -0.5 * sinR
            let y3 = yOffset + size * 0.5 * sinR + size * -0.5 * cosR
            vertices.append(contentsOf: [x3, y3, 0.0])
        }
        
        return vertices
    }
    
    /// Validates a test configuration
    static func validate(_ config: TestConfiguration) -> Bool {
        return config.width > 0 && config.height > 0 && 
               config.triangleCount > 0 && 
               config.geometryComplexity >= 1 && config.geometryComplexity <= 10 &&
               config.resolutionScale > 0.1 && config.resolutionScale <= 4.0
    }
    
}
