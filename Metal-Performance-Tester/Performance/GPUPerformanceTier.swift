//
//  GPUPerformanceTier.swift
//  Metal-Performance-Tester
//
///  Created by Kelvin Reid on 9/24/25.
//

import Foundation
import Metal

/// Represents different GPU performance tiers for dynamic workload scaling
enum GPUPerformanceTier: String, CaseIterable, Codable {
    case low = "Low Performance"
    case medium = "Medium Performance"
    case high = "High Performance"
    case ultraHigh = "Ultra High Performance"
    
    /// Target FPS for this performance tier
    var targetFPS: Double {
        switch self {
        case .low:
            return 30.0      // 30 FPS target for low-end GPUs
        case .medium:
            return 60.0      // 60 FPS target for medium GPUs
        case .high:
            return 120.0     // 120 FPS target for high-end GPUs
        case .ultraHigh:
            return 240.0     // 240 FPS target for ultra-high-end GPUs
        }
    }
    
    /// Base triangle count for this performance tier
    var baseTriangleCount: Int {
        switch self {
        case .low:
            return 1000      // 1,000 triangles for low-end GPUs
        case .medium:
            return 5000      // 5,000 triangles for medium GPUs
        case .high:
            return 20000     // 20,000 triangles for high-end GPUs
        case .ultraHigh:
            return 100000    // 100,000 triangles for ultra-high-end GPUs
        }
    }
    
    /// Geometry complexity multiplier for this performance tier
    var geometryComplexity: Double {
        switch self {
        case .low:
            return 2.0       // Simple geometry for low-end GPUs
        case .medium:
            return 5.0       // Moderate geometry for medium GPUs
        case .high:
            return 8.0        // Complex geometry for high-end GPUs
        case .ultraHigh:
            return 10.0       // Maximum geometry for ultra-high-end GPUs
        }
    }
    
    /// Optimal resolution for this performance tier
    var optimalResolution: CGSize {
        switch self {
        case .low:
            return CGSize(width: 1280, height: 720)    // 720p for low-end GPUs
        case .medium:
            return CGSize(width: 1920, height: 1080)  // 1080p for medium GPUs
        case .high:
            return CGSize(width: 2560, height: 1440)   // 1440p for high-end GPUs
        case .ultraHigh:
            return CGSize(width: 3840, height: 2160)   // 4K for ultra-high-end GPUs
        }
    }
    
    /// Human-readable description of this performance tier
    var description: String {
        switch self {
        case .low:
            return "Low Performance (30 FPS target, 720p, 1K triangles)"
        case .medium:
            return "Medium Performance (60 FPS target, 1080p, 5K triangles)"
        case .high:
            return "High Performance (120 FPS target, 1440p, 20K triangles)"
        case .ultraHigh:
            return "Ultra High Performance (240 FPS target, 4K, 100K triangles)"
        }
    }
    
    /// Hardware examples for this performance tier
    var hardwareExamples: [String] {
        switch self {
        case .low:
            return [
                "M1 base",
                "M2 base",
                "M3 base",
                "M4 base"
            ]
        case .medium:
            return [
                "M1 Pro",
                "M2 Pro",
                "M3 Pro",
                "M4 Pro"
            ]
        case .high:
            return [
                "M1 Max",
                "M2 Max",
                "M3 Max",
                "M4 Max"
            ]
        case .ultraHigh:
            return [
                "M1 Ultra",
                "M2 Ultra",
                "M3 Ultra",
                "M4 Ultra"
            ]
        }
    }
}

// MARK: - GPU Configuration Support

/// Configuration for dual-GPU systems
struct GPUConfiguration: Codable {
    let primary: String?      // Primary GPU name
    let secondary: String?     // Secondary GPU name
    let recommended: String?   // Recommended GPU for testing
    let performanceTier: GPUPerformanceTier
    
    init(primary: String?, secondary: String?, recommended: String?, performanceTier: GPUPerformanceTier) {
        self.primary = primary
        self.secondary = secondary
        self.recommended = recommended
        self.performanceTier = performanceTier
    }
}

// MARK: - GPU Detection Logic

/// GPU detection and classification system
class GPUDetector {
    
    /// Detects the performance tier of a given Metal device
    static func detectPerformanceTier(for device: MTLDevice) -> GPUPerformanceTier {
        let deviceName = device.name.lowercased()
        
        // M Series detection (Apple Silicon)
        if deviceName.contains("apple") {
            return detectMSeriesTier(deviceName: deviceName)
        }
        
        // Intel GPU detection
        if deviceName.contains("intel") {
            return detectIntelTier(deviceName: deviceName)
        }
        
        // AMD GPU detection
        if deviceName.contains("amd") || deviceName.contains("radeon") {
            return detectAMDTier(deviceName: deviceName)
        }
        
        // Default to medium tier for unknown GPUs
        return .medium
    }
    
    /// Detects M Series performance tier based on device name
    private static func detectMSeriesTier(deviceName: String) -> GPUPerformanceTier {
        // M1 Series
        if deviceName.contains("m1") {
            if deviceName.contains("ultra") {
                return .ultraHigh
            } else if deviceName.contains("max") {
                return .high
            } else if deviceName.contains("pro") {
                return .medium
            } else {
                return .low // M1 base
            }
        }
        
        // M2 Series
        if deviceName.contains("m2") {
            if deviceName.contains("ultra") {
                return .ultraHigh
            } else if deviceName.contains("max") {
                return .high
            } else if deviceName.contains("pro") {
                return .medium
            } else {
                return .low // M2 base
            }
        }
        
        // M3 Series
        if deviceName.contains("m3") {
            if deviceName.contains("ultra") {
                return .ultraHigh
            } else if deviceName.contains("max") {
                return .high
            } else if deviceName.contains("pro") {
                return .medium
            } else {
                return .low // M3 base
            }
        }
        
        // M4 Series
        if deviceName.contains("m4") {
            if deviceName.contains("ultra") {
                return .ultraHigh
            } else if deviceName.contains("max") {
                return .high
            } else if deviceName.contains("pro") {
                return .medium
            } else {
                return .low // M4 base
            }
        }
        
        // Default for unknown M Series
        return .medium
    }
    
    /// Detects Intel GPU performance tier
    private static func detectIntelTier(deviceName: String) -> GPUPerformanceTier {
        // Intel UHD Graphics 630 (your current GPU)
        if deviceName.contains("uhd graphics 630") {
            return .low
        }
        
        // Intel Arc Graphics (high-end discrete)
        if deviceName.contains("arc") {
            return .high
        }
        
        // Intel Iris Xe (integrated, newer)
        if deviceName.contains("iris xe") {
            return .medium
        }
        
        // Other Intel UHD Graphics
        if deviceName.contains("uhd graphics") {
            return .low
        }
        
        // Default for unknown Intel GPUs
        return .low
    }
    
    /// Detects AMD GPU performance tier
    private static func detectAMDTier(deviceName: String) -> GPUPerformanceTier {
        // AMD Radeon Pro 5300M (your current GPU)
        if deviceName.contains("radeon pro 5300m") {
            return .medium
        }
        
        // High-end AMD Radeon Pro GPUs
        if deviceName.contains("radeon pro 5500m") || deviceName.contains("radeon pro 5600m") {
            return .high
        }
        
        // Other AMD Radeon Pro GPUs
        if deviceName.contains("radeon pro") {
            return .medium
        }
        
        // Default for unknown AMD GPUs
        return .medium
    }
    
    /// Detects and configures dual-GPU systems
    static func detectDualGPUConfiguration(devices: [MTLDevice]) -> GPUConfiguration {
        guard devices.count >= 2 else {
            // Single GPU system
            let primary = devices.first
            let tier = primary != nil ? detectPerformanceTier(for: primary!) : .medium
            return GPUConfiguration(
                primary: primary?.name,
                secondary: nil,
                recommended: primary?.name,
                performanceTier: tier
            )
        }
        
        // Sort devices by performance tier (highest first)
        let sortedDevices = devices.sorted { device1, device2 in
            let tier1 = detectPerformanceTier(for: device1)
            let tier2 = detectPerformanceTier(for: device2)
            return tier1.rawValue > tier2.rawValue
        }
        
        let primary = sortedDevices.first
        let secondary = sortedDevices.count > 1 ? sortedDevices[1] : nil
        
        // For dual-GPU systems, recommend the higher performance GPU
        let recommended = primary
        let tier = primary != nil ? detectPerformanceTier(for: primary!) : .medium
        
        return GPUConfiguration(
            primary: primary?.name,
            secondary: secondary?.name,
            recommended: recommended?.name,
            performanceTier: tier
        )
    }
    
    /// Gets system information for debugging
    static func getSystemInfo() -> String {
        var info = "GPU Detection System Info:\n"
        
        // Get available Metal devices
        let devices = MTLCopyAllDevices()
        info += "Available Metal devices: \(devices.count)\n"
        
        for (index, device) in devices.enumerated() {
            let tier = detectPerformanceTier(for: device)
            info += "Device \(index + 1): \(device.name) -> \(tier.rawValue)\n"
        }
        
        return info
    }
}
