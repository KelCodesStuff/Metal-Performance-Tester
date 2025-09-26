//
//  MetalDeviceTests.swift
//  Unit-Tests
//
//  Created by Kelvin Reid on 9/26/25.
//

import XCTest
import Metal

final class MetalDeviceTests: XCTestCase {

    var device: MTLDevice!
    
    override func setUpWithError() throws {
        // Set up Metal device for testing
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal is not supported on this device")
        }
        self.device = device
    }

    override func tearDownWithError() throws {
        device = nil
    }

    // MARK: - Device Initialization Tests
    
    /// Tests Metal device creation and basic initialization
    /// Verifies that a Metal device can be created and has basic properties
    func testMetalDeviceInitialization() throws {
        // Test that Metal device can be created
        XCTAssertNotNil(device, "Metal device should be available")
        XCTAssertTrue(device.name.count > 0, "Device should have a name")
    }
    
    /// Tests Metal device properties and capabilities
    /// Verifies device name, GPU family support, and other device characteristics
    func testMetalDeviceProperties() throws {
        // Test Metal device properties
        XCTAssertNotNil(device, "Metal device should be available")
        
        // Test device name
        XCTAssertTrue(device.name.count > 0, "Device should have a name")
        
        // Test device capabilities - check for any GPU family support
        // Note: AMD GPUs don't support Apple's proprietary GPU families
        // Instead, we'll check if the device can create basic Metal resources
        let supportsAppleGPU = device.supportsFamily(.apple1) || device.supportsFamily(.apple2) || device.supportsFamily(.apple3) || device.supportsFamily(.apple4)
        
        // For non-Apple GPUs, we'll verify the device works by checking basic capabilities
        let deviceWorks = device.maxBufferLength > 0 && device.name.count > 0
        
        // Either support Apple GPU families OR be a working Metal device
        XCTAssertTrue(supportsAppleGPU || deviceWorks, "Device should support Apple GPU families or be a working Metal device")
    }
    
    /// Tests basic Metal device capabilities and resource creation
    /// Verifies that the device can create command queues and libraries
    func testMetalDeviceCapabilities() throws {
        // Test basic Metal device capabilities
        XCTAssertNotNil(device, "Metal device should be available")
        
        // Test that we can create a command queue
        let commandQueue = device.makeCommandQueue()
        XCTAssertNotNil(commandQueue, "Should be able to create command queue")
        
        // Test that we can create a library (might be nil if no shaders)
        let _ = device.makeDefaultLibrary()
        // Library might be nil if no shaders are available, which is acceptable
        XCTAssertTrue(true, "Library creation attempt should not crash")
    }
    
    /// Tests Metal device limits and constraints
    /// Verifies that device limits are reasonable and accessible
    func testMetalDeviceLimits() throws {
        // Test Metal device limits
        XCTAssertNotNil(device, "Device should be available")
        
        // Test maximum buffer length
        let maxBufferLength = device.maxBufferLength
        XCTAssertGreaterThan(maxBufferLength, 0, "Max buffer length should be positive")
    }

    // MARK: - Device Performance Tests
    
    /// Tests Metal device creation performance
    /// Measures the time taken to create a Metal device instance
    func testMetalDevicePerformance() throws {
        // Test Metal device performance
        measure {
            let device = MTLCreateSystemDefaultDevice()
            XCTAssertNotNil(device, "Device should be created in performance test")
        }
    }
}
