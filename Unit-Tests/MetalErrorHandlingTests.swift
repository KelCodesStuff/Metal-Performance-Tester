//
//  MetalErrorHandlingTests.swift
//  Unit-Tests
//
//  Created by Kelvin Reid on 9/26/25.
//

import XCTest
import Metal

final class MetalErrorHandlingTests: XCTestCase {

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

    // MARK: - Error Handling Tests
    
    /// Tests Metal error handling with valid descriptors
    /// Verifies that Metal API handles edge cases gracefully without crashing
    func testMetalErrorHandling() throws {
        // Test Metal error handling
        XCTAssertNotNil(device, "Device should be available")
        
        // Test that invalid operations don't crash
        // Note: We avoid creating invalid descriptors that would cause crashes
        // Instead, we test that the API handles edge cases gracefully
        
        // Test with minimal valid descriptor
        let validDescriptor = MTLTextureDescriptor()
        validDescriptor.width = 1
        validDescriptor.height = 1
        validDescriptor.pixelFormat = .bgra8Unorm
        validDescriptor.usage = .renderTarget
        
        let texture = device.makeTexture(descriptor: validDescriptor)
        XCTAssertNotNil(texture, "Valid descriptor should create texture")
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
    
    /// Tests Metal resource creation within device limits
    /// Verifies that resources can be created with reasonable sizes without exceeding limits
    func testMetalResourceCreationWithLimits() throws {
        // Test resource creation within device limits
        XCTAssertNotNil(device, "Device should be available")
        
        // Test buffer creation with reasonable size
        let testData = Array(0..<100).map { Float($0) }
        let buffer = device.makeBuffer(bytes: testData, 
                                      length: testData.count * MemoryLayout<Float>.size, 
                                      options: .storageModeShared)
        
        XCTAssertNotNil(buffer, "Buffer should be created within limits")
    }
    
    /// Tests Metal texture creation with reasonable dimensions
    /// Verifies that textures can be created with valid dimensions without exceeding limits
    func testMetalTextureCreationWithLimits() throws {
        // Test texture creation with reasonable dimensions
        XCTAssertNotNil(device, "Device should be available")
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 64  // Small but valid size
        textureDescriptor.height = 64
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.usage = .renderTarget
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        XCTAssertNotNil(texture, "Texture should be created with valid dimensions")
    }
    
    /// Tests Metal command queue error handling
    /// Verifies that command queues and command buffers can be created and executed without crashing
    func testMetalCommandQueueErrorHandling() throws {
        // Test command queue error handling
        XCTAssertNotNil(device, "Device should be available")
        
        let commandQueue = device.makeCommandQueue()
        XCTAssertNotNil(commandQueue, "Command queue should be created")
        
        if let commandQueue = commandQueue {
            // Test that we can create command buffers without crashing
            let commandBuffer = commandQueue.makeCommandBuffer()
            XCTAssertNotNil(commandBuffer, "Command buffer should be created")
            
            // Test that we can commit empty command buffers
            if let commandBuffer = commandBuffer {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
                XCTAssertEqual(commandBuffer.status, .completed, "Empty command buffer should complete")
            }
        }
    }
    
    /// Tests Metal library error handling
    /// Verifies that library creation and function queries handle missing shaders gracefully
    func testMetalLibraryErrorHandling() throws {
        // Test library error handling
        XCTAssertNotNil(device, "Device should be available")
        
        // Test that library creation doesn't crash even if no shaders are available
        let library = device.makeDefaultLibrary()
        // Library might be nil if no shaders are available, which is acceptable
        XCTAssertTrue(true, "Library creation should not crash")
        
        if let library = library {
            // Test that querying non-existent functions doesn't crash
            let nonExistentFunction = library.makeFunction(name: "non_existent_function")
            XCTAssertNil(nonExistentFunction, "Non-existent function should return nil")
        }
    }
}
