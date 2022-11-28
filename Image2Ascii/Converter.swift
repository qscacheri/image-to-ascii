//
//  Converter.swift
//  Image2Ascii
//
//  Created by Quin Scacheri on 11/26/22.
//

import CoreGraphics
import CoreImage
import Foundation
import Metal
import MetalKit
import SwiftUI

func resize(image: NSImage, w: Int, h: Int) -> NSImage {
    let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
    let newImage = NSImage(size: destSize)
    newImage.lockFocus()
    image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: .sourceOver, fraction: CGFloat(1))
    newImage.unlockFocus()
    newImage.size = destSize
    return newImage
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }

        return nil
    }
}

extension NSImage {
    /// Create a CIImage using the best representation available
    ///
    /// - Returns: Converted image, or nil
    func asCIImage() -> CIImage? {
        if let cgImage = self.asCGImage() {
            return CIImage(cgImage: cgImage)
        }
        return nil
    }

    /// Create a CGImage using the best representation of the image available in the NSImage for the image size
    ///
    /// - Returns: Converted image, or nil
    func asCGImage() -> CGImage? {
        var rect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.size)
        return self.cgImage(forProposedRect: &rect, context: NSGraphicsContext.current, hints: nil)
    }
}

class Converter {
    let device: MTLDevice
    let pipelineState: MTLComputePipelineState
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Error creating metal device")
        }
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Error creating command queue")
        }
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Error creating default library")
        }
        guard let pipelineState = try? device.makeComputePipelineState(function: library.makeFunction(name: "image2Ascii")!) else {
            fatalError("Error creating pipeline state")
        }

        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.pipelineState = pipelineState
    }

    func convert(image: NSImage, scale: CGFloat, onComplete: @escaping (_ ascii: String?) -> ()) {

        let newWidth = image.size.width * scale
        let newHeight = image.size.height * scale
        let resized = image.resized(to: NSSize(width: newWidth, height: newHeight))
        let textureLoader = MTKTextureLoader(device: self.device)
//        let imageTexture = try! textureLoader.newTexture(URL: imageUrl)
        guard let cgImage = resized?.asCGImage() else { fatalError() }
        let imageTexture: MTLTexture
        do {
            imageTexture = try textureLoader.newTexture(cgImage: cgImage)
        } catch {
            fatalError(error.localizedDescription)
        }

        let imageWidth = imageTexture.width
        let imageHeight = imageTexture.height
        let sharedCapturer = MTLCaptureManager.shared()
        let customScope = sharedCapturer.makeCaptureScope(device: self.device)
        customScope.label = "Ascii"
        sharedCapturer.defaultCaptureScope = customScope

//        while true {
        customScope.begin()
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { fatalError("Unable to create command buffer") }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            fatalError("Unable to create encoder")
        }

        let outputBuffer = self.device.makeBuffer(length: MemoryLayout<CChar>.stride * (imageWidth + 1) * imageHeight, options: [])!
        encoder.setComputePipelineState(self.pipelineState)
        encoder.setBuffer(outputBuffer, offset: 0, index: 0)
        encoder.setTexture(imageTexture, index: 0)

        let threadsPerGrid = MTLSize(width: imageWidth + 1,
                                     height: imageHeight,
                                     depth: 1)

        let w = self.pipelineState.threadExecutionWidth
        let h = self.pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        encoder.dispatchThreads(threadsPerGrid,
                                threadsPerThreadgroup: threadsPerThreadgroup)

        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.addCompletedHandler { _ in
            let result = outputBuffer.contents().assumingMemoryBound(to: CChar.self)

            let dataArray = Array(UnsafeBufferPointer(start: result, count: (imageWidth + 1) * imageHeight))
            let ascii: String = .init(cString: dataArray)
            onComplete(ascii)
        }
        customScope.end()
//        commandBuffer.waitUntilCompleted()
    }
}
