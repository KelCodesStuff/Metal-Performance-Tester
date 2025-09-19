//
//  TestConfiguration.swift
//  Metal-Performance-Tracker
//
//  Created by Kelvin Reid on 9/18/25.
//

import Foundation

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
    
    /// Human-readable name for this baseline configuration
    let baselineName: String
    
    /// Creates a test configuration with default values
    init(width: Int = 1920, height: Int = 1080, pixelFormat: String = "MTLPixelFormat(rawValue: 80)", 
         triangleCount: Int = 1, geometryComplexity: Int = 1, resolutionScale: Double = 1.0, 
         testMode: String = "simple", baselineName: String = "Simple Baseline") {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.triangleCount = triangleCount
        self.geometryComplexity = geometryComplexity
        self.resolutionScale = resolutionScale
        self.testMode = testMode
        self.timestamp = Date()
        self.baselineName = baselineName
    }
    
    /// Creates a test configuration from current renderer settings (backwards compatibility)
    init(width: Int, height: Int, pixelFormat: String, vertexCount: Int) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.triangleCount = vertexCount / 3  // Convert vertices to triangles
        self.geometryComplexity = 1
        self.resolutionScale = 1.0
        self.testMode = "legacy"
        self.timestamp = Date()
        self.baselineName = "Legacy Baseline"
    }
    
    /// Calculates the effective resolution after scaling
    var effectiveWidth: Int {
        return Int(Double(width) * resolutionScale)
    }
    
    /// Calculates the effective resolution after scaling
    var effectiveHeight: Int {
        return Int(Double(height) * resolutionScale)
    }
    
    /// Returns a human-readable description of the configuration
    var description: String {
        return baselineName
    }
    
    /// Returns the parameters description
    var parametersDescription: String {
        if resolutionScale != 1.0 {
            return "\(width)x\(height) @ \(triangleCount) triangles (complexity: \(geometryComplexity)/10, scale: \(String(format: "%.1f", resolutionScale))x)"
        } else {
            return "\(effectiveWidth)x\(effectiveHeight) @ \(triangleCount) triangles (complexity: \(geometryComplexity)/10, scale: \(String(format: "%.1f", resolutionScale))x)"
        }
    }
}

/// Predefined test configurations for common scenarios
enum TestPreset {
    case simple           // 1 triangle, 1080p
    case moderate         // 100 triangles, 1080p
    case complex          // 1000 triangles, 1080p
    case stress           // 10000 triangles, 1080p
    case highRes          // 1000 triangles, 4K
    case lowRes           // 100 triangles, 720p
    case custom(triangleCount: Int, width: Int, height: Int, complexity: Int, scale: Double)
    
    /// Creates a test configuration for this preset
    func createConfiguration() -> TestConfiguration {
        switch self {
        case .simple:
            return TestConfiguration(width: 1920, height: 1080, triangleCount: 1, 
                                   geometryComplexity: 1, resolutionScale: 1.0, testMode: "simple", 
                                   baselineName: "Simple Baseline")
            
        case .moderate:
            return TestConfiguration(width: 1920, height: 1080, triangleCount: 100, 
                                   geometryComplexity: 5, resolutionScale: 1.0, testMode: "moderate",
                                   baselineName: "Moderate Baseline")
            
        case .complex:
            return TestConfiguration(width: 1920, height: 1080, triangleCount: 1000, 
                                   geometryComplexity: 8, resolutionScale: 1.0, testMode: "complex",
                                   baselineName: "Complex Baseline")
            
        case .stress:
            return TestConfiguration(width: 1920, height: 1080, triangleCount: 10000, 
                                   geometryComplexity: 10, resolutionScale: 1.0, testMode: "stress",
                                   baselineName: "Stress Baseline")
            
        case .highRes:
            return TestConfiguration(width: 3840, height: 2160, triangleCount: 1000, 
                                   geometryComplexity: 8, resolutionScale: 1.0, testMode: "high-res",
                                   baselineName: "High Resolution Baseline")
            
        case .lowRes:
            return TestConfiguration(width: 1280, height: 720, triangleCount: 100, 
                                   geometryComplexity: 5, resolutionScale: 1.0, testMode: "low-res",
                                   baselineName: "Low Resolution Baseline")
            
        case .custom(let triangleCount, let width, let height, let complexity, let scale):
            return TestConfiguration(width: width, height: height, triangleCount: triangleCount, 
                                   geometryComplexity: complexity, resolutionScale: scale, testMode: "custom",
                                   baselineName: "Custom Baseline")
        }
    }
    
    /// Human-readable name for the preset
    var name: String {
        switch self {
        case .simple: return "Simple (1 triangle, 1080p)"
        case .moderate: return "Moderate (100 triangles, 1080p)"
        case .complex: return "Complex (1000 triangles, 1080p)"
        case .stress: return "Stress Test (10K triangles, 1080p)"
        case .highRes: return "High Resolution (1K triangles, 4K)"
        case .lowRes: return "Low Resolution (100 triangles, 720p)"
        case .custom: return "Custom Configuration"
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
            
            // Generate triangle vertices with slight variations
            let size = Float(baseSize) * (0.8 + 0.4 * Float.random(in: 0...1))
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
    
    /// Estimates the relative performance impact of a configuration
    static func estimatePerformanceImpact(_ config: TestConfiguration) -> String {
        let pixelCount = config.effectiveWidth * config.effectiveHeight
        let triangleCount = config.triangleCount
        let complexity = config.geometryComplexity
        
        // Normalize impacts to be more balanced
        let pixelImpact = Double(pixelCount) / (1920 * 1080)  // 0.44 for 720p, 1.0 for 1080p, 4.0 for 4K
        let vertexImpact = sqrt(Double(triangleCount)) / 10.0  // 0.1 for 1 triangle, 1.0 for 100 triangles, 3.16 for 1K triangles
        let complexityImpact = Double(complexity) / 10.0  // 0.1 to 1.0
        
        // Weighted combination: triangles are most important for geometry processing, then pixels, then complexity
        let totalImpact = (vertexImpact * 0.5) + (pixelImpact * 0.3) + (complexityImpact * 0.2)
        
        if totalImpact < 0.4 {
            return "Low Impact"
        } else if totalImpact < 0.8 {
            return "Medium Impact"
        } else if totalImpact < 1.6 {
            return "High Impact"
        } else {
            return "Very High Impact"
        }
    }
}
