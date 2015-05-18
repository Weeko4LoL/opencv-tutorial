//
//  ViewController.swift
//  OpenCVTutorial
//
//  Created by 小林 孝稔 on 2015/05/15.
//  Copyright (c) 2015年 小林 孝稔. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var imageView: UIImageView!
    
    var mySession: AVCaptureSession!
    var myDevice: AVCaptureDevice!
    var myOutput: AVCaptureVideoDataOutput!
    
    // 顔検出オブジェクト
    let detector = Detector()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if initCamera() {
            mySession.startRunning()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initCamera() -> Bool {
        mySession = AVCaptureSession()
        
        if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Phone {
            mySession.sessionPreset = AVCaptureSessionPreset640x480
        } else {
            mySession.sessionPreset = AVCaptureSessionPresetPhoto
        }
        
        for device in AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) {
            if (device.position == AVCaptureDevicePosition.Front) {
                myDevice = device as! AVCaptureDevice
            }
        }
        if myDevice == nil {
            return false
        }
        
        let myInput = AVCaptureDeviceInput.deviceInputWithDevice(myDevice, error: nil) as! AVCaptureDeviceInput
        
        if mySession.canAddInput(myInput) {
            mySession.addInput(myInput)
        } else {
            return false
        }
        
        var lockError: NSError?
        if myDevice.lockForConfiguration(&lockError) {
            if let error = lockError {
                println("lock error: \(error.localizedDescription)")
                return false
            } else {
                myDevice.activeVideoMinFrameDuration = CMTimeMake(1, 8)
                myDevice.unlockForConfiguration()
            }
        }
        
        myOutput = AVCaptureVideoDataOutput()
        myOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
        myOutput.alwaysDiscardsLateVideoFrames = true
        
        if mySession.canAddOutput(myOutput) {
            mySession.addOutput(myOutput)
        } else {
            return false
        }
        
        let queue: dispatch_queue_t = dispatch_queue_create("myqueue", DISPATCH_QUEUE_SERIAL)
        myOutput.setSampleBufferDelegate(self, queue: queue)
        
        for connection in myOutput.connections {
            if let conn = connection as? AVCaptureConnection {
                if conn.supportsVideoOrientation {
                    conn.videoOrientation = CameraUtil.videoOrientationFromDeviceOrientation(UIDevice.currentDevice().orientation)

                }
            }
        }
        
        return true
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        dispatch_sync(dispatch_get_main_queue(), {
            // UIImageへ変換
            var image: UIImage = CameraUtil.imageFromSampleBuffer(sampleBuffer)
            
            // 顔認識
            image = self.detector.recognizeGesture(image)
            
            // 表示
            self.imageView.image = image
        })
    }
}

