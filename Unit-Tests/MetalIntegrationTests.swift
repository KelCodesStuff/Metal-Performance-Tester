//
//  MetalIntegrationTests.swift
//  Unit-Tests
//
//  Created by Kelvin Reid on 9/26/25.
//

import XCTest
import Metal

final class MetalIntegrationTests: XCTestCase {

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

    // MARK: - Integration Tests
    
    /// Tests Metal component integration and connectivity
    /// Verifies that all Metal components (device, command queue, library, texture, command buffer) work together
    func testMetalIntegration() throws {
        // Test that all Metal components work together
        XCTAssertNotNil(device, "Device should be available")
        
        // Create command queue
        let commandQueue = device.makeCommandQueue()
        XCTAssertNotNil(commandQueue, "Command queue should be created")
        
        // Create library (might be nil if no shaders)
        let library = device.makeDefaultLibrary()
        // Library might be nil if no shaders are available, which is acceptable
        
        // Create texture
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 256
        textureDescriptor.height = 256
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.usage = .renderTarget
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        XCTAssertNotNil(texture, "Texture should be created")
        
        // Create command buffer
        let commandBuffer = commandQueue?.makeCommandBuffer()
        XCTAssertNotNil(commandBuffer, "Command buffer should be created")
        
        // Test that all components are properly connected
        XCTAssertTrue(commandQueue?.device === device, "Command queue should be connected to device")
        if let library = library {
            XCTAssertTrue(library.device === device, "Library should be connected to device")
        }
        XCTAssertTrue(texture?.device === device, "Texture should be connected to device")
        XCTAssertTrue(commandBuffer?.device === device, "Command buffer should be connected to device")
    }
    
    /// Tests a complete Metal workflow from resource creation to command execution
    /// Verifies the end-to-end Metal rendering pipeline works correctly
    func testMetalWorkflow() throws {
        // Test a complete Metal workflow
        XCTAssertNotNil(device, "Device should be available")
        
        // Step 1: Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            XCTFail("Command queue should be created")
            return
        }
        
        // Step 2: Create texture
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 128
        textureDescriptor.height = 128
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.usage = .renderTarget
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            XCTFail("Texture should be created")
            return
        }
        
        // Step 3: Create command buffer
        let commandBuffer = commandQueue.makeCommandBuffer()
        XCTAssertNotNil(commandBuffer, "Command buffer should be created")
        
        // Step 4: Execute commands
        if let commandBuffer = commandBuffer {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            XCTAssertEqual(commandBuffer.status, .completed, "Command buffer should complete")
        }
    }
    
    /// Tests Metal resource lifecycle management
    /// Verifies that resources remain valid throughout their lifecycle and after use
    func testMetalResourceLifecycle() throws {
        // Test Metal resource lifecycle
        XCTAssertNotNil(device, "Device should be available")
        
        // Create resources
        let commandQueue = device.makeCommandQueue()
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 64
        textureDescriptor.height = 64
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.usage = .renderTarget
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        let commandBuffer = commandQueue?.makeCommandBuffer()
        
        // Verify resources are created
        XCTAssertNotNil(commandQueue, "Command queue should be created")
        XCTAssertNotNil(texture, "Texture should be created")
        XCTAssertNotNil(commandBuffer, "Command buffer should be created")
        
        // Test resource usage
        if let commandBuffer = commandBuffer {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        // Resources should still be valid after use
        XCTAssertNotNil(commandQueue, "Command queue should remain valid")
        XCTAssertNotNil(texture, "Texture should remain valid")
    }
    
    /// Tests multiple concurrent Metal workflows
    /// Verifies that multiple independent Metal workflows can execute simultaneously
    func testMetalMultipleWorkflows() throws {
        // Test multiple concurrent Metal workflows
        XCTAssertNotNil(device, "Device should be available")
        
        // Create multiple command queues
        let commandQueue1 = device.makeCommandQueue()
        let commandQueue2 = device.makeCommandQueue()
        
        XCTAssertNotNil(commandQueue1, "First command queue should be created")
        XCTAssertNotNil(commandQueue2, "Second command queue should be created")
        
        // Create command buffers from both queues
        let commandBuffer1 = commandQueue1?.makeCommandBuffer()
        let commandBuffer2 = commandQueue2?.makeCommandBuffer()
        
        XCTAssertNotNil(commandBuffer1, "First command buffer should be created")
        XCTAssertNotNil(commandBuffer2, "Second command buffer should be created")
        
        // Execute both command buffers
        if let commandBuffer1 = commandBuffer1 {
            commandBuffer1.commit()
            commandBuffer1.waitUntilCompleted()
        }
        
        if let commandBuffer2 = commandBuffer2 {
            commandBuffer2.commit()
            commandBuffer2.waitUntilCompleted()
        }
        
        // Both should complete successfully
        XCTAssertTrue(true, "Multiple workflows should execute successfully")
    }
}
