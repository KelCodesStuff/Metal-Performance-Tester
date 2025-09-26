//
//  MetalCommandTests.swift
//  Unit-Tests
//
//  Created by Kelvin Reid on 9/26/25.
//

import XCTest
import Metal

final class MetalCommandTests: XCTestCase {

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

    // MARK: - Command Buffer Tests
    
    /// Tests Metal command buffer creation and execution
    /// Verifies that command buffers can be created, committed, and completed successfully
    func testMetalCommandBuffer() throws {
        // Test command buffer creation and execution
        guard let commandQueue = device.makeCommandQueue() else {
            XCTFail("Command queue should be created")
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        XCTAssertNotNil(commandBuffer, "Command buffer should be created")
        
        if let commandBuffer = commandBuffer {
            XCTAssertTrue(commandBuffer.device === device, "Command buffer device should match")
            
            // Test command buffer execution
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            XCTAssertEqual(commandBuffer.status, .completed, "Command buffer should complete")
        }
    }
    
    /// Tests Metal command buffer creation and execution performance
    /// Measures the time taken to create, commit, and complete command buffers
    func testMetalCommandBufferPerformance() throws {
        // Test command buffer creation performance
        guard let commandQueue = device.makeCommandQueue() else {
            XCTFail("Command queue should be created")
            return
        }
        
        measure {
            let commandBuffer = commandQueue.makeCommandBuffer()
            XCTAssertNotNil(commandBuffer, "Command buffer should be created in performance test")
            
            if let commandBuffer = commandBuffer {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }
        }
    }
    
    /// Tests creation of multiple command buffers
    /// Verifies that multiple command buffers can be created and are independent instances
    func testMetalMultipleCommandBuffers() throws {
        // Test creating multiple command buffers
        guard let commandQueue = device.makeCommandQueue() else {
            XCTFail("Command queue should be created")
            return
        }
        
        let commandBuffer1 = commandQueue.makeCommandBuffer()
        let commandBuffer2 = commandQueue.makeCommandBuffer()
        
        XCTAssertNotNil(commandBuffer1, "First command buffer should be created")
        XCTAssertNotNil(commandBuffer2, "Second command buffer should be created")
        
        // They should be different instances
        XCTAssertTrue(commandBuffer1 !== commandBuffer2, "Command buffers should be different instances")
        
        // But they should use the same device
        if let buffer1 = commandBuffer1, let buffer2 = commandBuffer2 {
            XCTAssertTrue(buffer1.device === buffer2.device, "Both command buffers should use the same device")
        }
    }

    // MARK: - Command Execution Tests
    
    /// Tests basic Metal command execution workflow
    /// Verifies that command buffers can be committed and completed successfully
    func testMetalCommandExecution() throws {
        // Test basic command execution
        guard let commandQueue = device.makeCommandQueue() else {
            XCTFail("Command queue should be created")
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        XCTAssertNotNil(commandBuffer, "Command buffer should be created")
        
        if let commandBuffer = commandBuffer {
            // Test that we can commit and wait for completion
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // Test command buffer status
            XCTAssertEqual(commandBuffer.status, .completed, "Command buffer should complete successfully")
        }
    }
    
    /// Tests Metal command buffer status tracking throughout execution lifecycle
    /// Verifies that command buffer status changes correctly from creation to completion
    func testMetalCommandBufferStatus() throws {
        // Test command buffer status tracking
        guard let commandQueue = device.makeCommandQueue() else {
            XCTFail("Command queue should be created")
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        XCTAssertNotNil(commandBuffer, "Command buffer should be created")
        
        if let commandBuffer = commandBuffer {
            // Initially should be not committed
            XCTAssertEqual(commandBuffer.status, .notEnqueued, "Command buffer should start as not enqueued")
            
            // After commit, status should change (may be enqueued or completed depending on execution speed)
            commandBuffer.commit()
            
            // The status should be either enqueued, committed, or completed (depending on execution speed)
            let statusAfterCommit = commandBuffer.status
            XCTAssertTrue(statusAfterCommit == .enqueued || statusAfterCommit == .committed || statusAfterCommit == .completed, 
                        "Command buffer should be enqueued, committed, or completed after commit, got: \(statusAfterCommit) (rawValue: \(statusAfterCommit.rawValue))")
            
            // After completion, should be completed
            commandBuffer.waitUntilCompleted()
            XCTAssertEqual(commandBuffer.status, .completed, "Command buffer should be completed after wait")
        }
    }
}
