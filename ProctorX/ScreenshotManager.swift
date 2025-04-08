//
//  ScreenshotManager.swift
//  ProctorX
//
//  Created by Eddie Gao on 6/4/25.
//

// Swift
import AVFoundation
import Cocoa
import VideoToolbox

class ScreenshotManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let telegramManager: TelegramManager
    private var session: AVCaptureSession?
    private var continuation: CheckedContinuation<NSImage, Error>?
    private let outputQueue = DispatchQueue(label: "com.example.screenshotOutputQueue")
    
    init(telegramManager: TelegramManager) {
        self.telegramManager = telegramManager
    }
    
    func takeScreenshot() {
        Task {
            do {
                let image = try await captureScreen()
                telegramManager.sendPhoto(image: image) { result in
                    switch result {
                    case .success:
                        print("Screenshot sent successfully")
                    case .failure(let error):
                        print("Failed to send screenshot: \(error)")
                    }
                }
            } catch {
                print("Failed to capture screenshot: \(error)")
            }
        }
    }
    
    private func captureScreen() async throws -> NSImage {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        guard let screenInput = AVCaptureScreenInput(displayID: CGMainDisplayID()) else {
            throw NSError(domain: "ScreenshotError", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to create screen input"])
        }
        if session.canAddInput(screenInput) {
            session.addInput(screenInput)
            print("Screen input added")
        } else {
            throw NSError(domain: "ScreenshotError", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to add screen input"])
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            print("Video output added")
        } else {
            throw NSError(domain: "ScreenshotError", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to add video output"])
        }
        
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        session.commitConfiguration()
        self.session = session
        print("Session configuration complete. Starting session...")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.startRunning()
            print("Session started")
        }
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate method
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        print("Frame captured")
        if let continuation = self.continuation,
           let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            session?.stopRunning()
            print("Session stopped after capturing a frame")
            self.session = nil
            
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(imageBuffer, options: nil, imageOut: &cgImage)
            
            if let cgImg = cgImage {
                let image = NSImage(cgImage: cgImg,
                                    size: NSSize(width: cgImg.width, height: cgImg.height))
                print("CGImage created successfully")
                continuation.resume(returning: image)
            } else {
                print("Failed to create CGImage")
                continuation.resume(throwing: NSError(domain: "ScreenshotError", code: 4,
                                                        userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"]))
            }
            self.continuation = nil
        } else {
            print("No valid continuation or image buffer found")
        }
    }
}
