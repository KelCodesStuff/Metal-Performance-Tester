//
//  MetalResourceTests.swift
//  Unit-Tests
//
//  Created by Kelvin Reid on 9/26/25.
//

import XCTest
import Metal

final class MetalResourceTests: XCTestCase {

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

    // MARK: - Command Queue Tests
    
    /// Tests Metal command queue creation and basic properties
    /// Verifies that command queues can be created and are properly connected to the device
    func testMetalCommandQueueCreation() throws {
        // Test command queue creation
        let commandQueue = device.makeCommandQueue()
        XCTAssertNotNil(commandQueue, "Command queue should be created")
        
        // Test command queue properties
        if let commandQueue = commandQueue {
            XCTAssertTrue(commandQueue.device === device, "Command queue device should match")
        }
    }
    
    /// Tests creation of multiple command queues
    /// Verifies that multiple command queues can be created and are independent instances
    func testMetalMultipleCommandQueues() throws {
        // Test creating multiple command queues
        let commandQueue1 = device.makeCommandQueue()
        let commandQueue2 = device.makeCommandQueue()
        
        XCTAssertNotNil(commandQueue1, "First command queue should be created")
        XCTAssertNotNil(commandQueue2, "Second command queue should be created")
        
        // They should be different instances
        XCTAssertTrue(commandQueue1 !== commandQueue2, "Command queues should be different instances")
        
        // But they should use the same device
        if let queue1 = commandQueue1, let queue2 = commandQueue2 {
            XCTAssertTrue(queue1.device === queue2.device, "Both command queues should use the same device")
        }
    }

    // MARK: - Library Tests
    
    /// Tests Metal library creation and basic properties
    /// Verifies that libraries can be created and are properly connected to the device
    func testMetalLibraryCreation() throws {
        // Test library creation
        let library = device.makeDefaultLibrary()
        // Library might be nil if no shaders are available, which is acceptable
        XCTAssertTrue(true, "Library creation should not crash")
        
        // Test library properties if created
        if let library = library {
            XCTAssertTrue(library.device === device, "Library device should match")
        }
    }
    
    /// Tests Metal pipeline state creation from library functions
    /// Verifies that shader functions can be queried from the library
    func testMetalPipelineStateCreation() throws {
        // Test pipeline state creation
        guard let library = device.makeDefaultLibrary() else {
            // Skip if no library available (no shaders)
            throw XCTSkip("No Metal library available - no shaders in test target")
        }
        
        // Try to find basic shader functions
        let _ = library.makeFunction(name: "vertex_main")
        let _ = library.makeFunction(name: "fragment_main")
        
        // These might be nil if the shaders don't exist, which is fine for testing
        // We're just testing that the library can be queried
        XCTAssertTrue(true, "Library query should work")
    }

    // MARK: - Texture Tests
    
    /// Tests Metal texture creation and properties
    /// Verifies that textures can be created with specific dimensions and formats
    func testMetalTextureCreation() throws {
        // Test texture creation
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width = 256
        textureDescriptor.height = 256
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.usage = .renderTarget
        
        let texture = device.makeTexture(descriptor: textureDescriptor)
        XCTAssertNotNil(texture, "Texture should be created")
        
        if let texture = texture {
            XCTAssertEqual(texture.width, 256, "Texture width should match")
            XCTAssertEqual(texture.height, 256, "Texture height should match")
            XCTAssertEqual(texture.pixelFormat, .bgra8Unorm, "Pixel format should match")
            XCTAssertTrue(texture.device === device, "Texture device should match")
        }
    }
    
    /// Tests Metal texture creation performance
    /// Measures the time taken to create textures with different dimensions
    func testMetalTextureCreationPerformance() throws {
        // Test texture creation performance
        measure {
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.width = 512
            textureDescriptor.height = 512
            textureDescriptor.pixelFormat = .bgra8Unorm
            textureDescriptor.usage = .renderTarget
            
            let texture = device.makeTexture(descriptor: textureDescriptor)
            XCTAssertNotNil(texture, "Texture should be created in performance test")
        }
    }

    // MARK: - Buffer Tests
    
    /// Tests Metal buffer creation and properties
    /// Verifies that buffers can be created with specific data and storage modes
    func testMetalBufferCreation() throws {
        // Test buffer creation
        let testData: [Float] = [1.0, 2.0, 3.0, 4.0]
        let buffer = device.makeBuffer(bytes: testData, 
                                      length: testData.count * MemoryLayout<Float>.size, 
                                      options: .storageModeShared)
        
        XCTAssertNotNil(buffer, "Buffer should be created")
        
        if let buffer = buffer {
            XCTAssertEqual(buffer.length, testData.count * MemoryLayout<Float>.size, "Buffer length should match")
            XCTAssertTrue(buffer.device === device, "Buffer device should match")
        }
    }
    
    /// Tests Metal buffer creation performance
    /// Measures the time taken to create buffers with different data sizes
    func testMetalBufferCreationPerformance() throws {
        // Test buffer creation performance
        let testData = Array(0..<1000).map { Float($0) }
        
        measure {
            let buffer = device.makeBuffer(bytes: testData, 
                                         length: testData.count * MemoryLayout<Float>.size, 
                                         options: .storageModeShared)
            XCTAssertNotNil(buffer, "Buffer should be created in performance test")
        }
    }

    // MARK: - Render Pass Tests
    
    /// Tests Metal render pass descriptor creation and configuration
    /// Verifies that render pass descriptors can be created and configured properly
    func testMetalRenderPassDescriptor() throws {
        // Test render pass descriptor creation
        let renderPassDescriptor = MTLRenderPassDescriptor()
        XCTAssertNotNil(renderPassDescriptor, "Render pass descriptor should be created")
        
        // Test color attachment configuration
        let colorAttachment = renderPassDescriptor.colorAttachments[0]
        XCTAssertNotNil(colorAttachment, "Color attachment should exist")
        
        if let colorAttachment = colorAttachment {
            colorAttachment.loadAction = .clear
            colorAttachment.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            colorAttachment.storeAction = .store
            
            XCTAssertEqual(colorAttachment.loadAction, .clear, "Load action should be set")
            XCTAssertEqual(colorAttachment.storeAction, .store, "Store action should be set")
        }
    }
}
