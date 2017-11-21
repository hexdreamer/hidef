//
//  PDAudioPlayer.swift
//  HiDef
//
//  Created by Kenny Leung on 9/22/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation

class PDAudioPlayer {
    
    // This is not great architecture, but just a trick to help us get around initialization order problesm. Mostly because we are not fully initialized before we have to capture stuff for AudioQueueNewOutputWithDispatchQueue
    private class InternalData {
        let source :PDAudioSource
        var audioBuffers = [PDAudioBuffer]()
        var mIsRunning: Bool = false
        
        init(source:PDAudioSource) {
            self.source = source
        }
    }
    
    let dispatchQueue :DispatchQueue
    let audioQueue :AudioQueueRef                                      // 3
    private let data :InternalData
    
    static let kNumberBuffers :Int = 3                              // 1
    //var mDataFormat:AudioStreamBasicDescription                     // 2
    //var mBuffers :[AudioQueueBufferRef]                            // 4
    //var mAudioFile :AudioFileID?                                    // 5
    var bufferByteSize :UInt32                                     // 6
    //var mCurrentPacket :Int64?                                      // 7
    var mNumPacketsToRead :UInt32                                  // 8
    //var mPacketDescs :UnsafePointer<AudioStreamPacketDescription>?  // 9
    
    var isPlaying:Bool {return data.mIsRunning}
    
    init?(source:PDAudioSource) {
        var status:OSStatus
        
        let tmpData = InternalData(source:source)
        let tmpDispatchQueue = DispatchQueue(label:"AudioPlayer", qos:.default, attributes:[], autoreleaseFrequency:.workItem, target:nil)
        
        var tmpAudioQueue :AudioQueueRef?
        var dataFormat = source.mDataFormat
        status = AudioQueueNewOutputWithDispatchQueue(&tmpAudioQueue, &dataFormat, 0, tmpDispatchQueue) { (baqQueue, baqBuffer) in
            if !tmpData.mIsRunning {
                return  // block
            }
            for audioBuffer in tmpData.audioBuffers {
                if audioBuffer.audioQueueBuffer == baqBuffer {
                    tmpData.source.fillBuffer(audioBuffer);
                }
            }
            AudioQueueEnqueueBuffer(baqQueue, baqBuffer, 0, nil)
        }
        if status != noErr {
            return nil
        }
        guard let nnAudioQueue = tmpAudioQueue else {
            return nil
        }
        if  let cookie = source.cookie,
            let cookieSize = source.cookieSize {
            status = AudioQueueSetProperty(nnAudioQueue, kAudioQueueProperty_MagicCookie, cookie, cookieSize)
            if status != noErr {
                return nil
            }
        }
        if  let channelLayout = source.channelLayout,
            let channelLayoutSize = source.channelLayoutSize {
            status = AudioQueueSetProperty(nnAudioQueue, kAudioQueueProperty_ChannelLayout, channelLayout, channelLayoutSize)
        }
        
        self.dispatchQueue = tmpDispatchQueue
        self.data = tmpData
        self.audioQueue = nnAudioQueue
        
        (self.bufferByteSize, self.mNumPacketsToRead) = PDAudioPlayer.computeBufferSizeAndPacketCount(format:source.mDataFormat, maxPacketSize:0x100, seconds:1)
        for _ in 0..<30 {
            guard let buffer = PDAudioBuffer(audioQueue:self.audioQueue, bufferSize:self.bufferByteSize, numberOfPacketDescriptions:self.mNumPacketsToRead) else {
                return nil
            }
            self.data.audioBuffers.append(buffer)
            self.data.source.fillBuffer(buffer);
            AudioQueueEnqueueBuffer(self.audioQueue, buffer.audioQueueBuffer, 0, nil)
        }
        AudioQueuePrime(self.audioQueue, 0, nil)
        
        /*
        let gain :Float32 = 1.0;                                       // 1
        // Optionally, allow user to override gain setting here
        AudioQueueSetParameter (                                  // 2
            self.audioQueue,                                        // 3
            kAudioQueueParam_Volume,                              // 4
            gain                                                  // 5
        );
        
        do {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(source.mDataFormat.mSampleRate)
        } catch {
            print("Error")
        }
         */
    }
    
    public func play() {
        print("\(self) requestPlay")
        self.dispatchQueue.async {
            self.data.mIsRunning = true
            AudioQueueStart(self.audioQueue, nil)
            print("\(self) play")
        }
    }
    
    public func pause() {
        print("\(self) requestPause")
        self.dispatchQueue.async {
            AudioQueuePause(self.audioQueue)
            print("\(self) pause")
        }
    }
    
    public func stop() {
        print("\(self) requestStop")
        self.data.mIsRunning = false
        self.dispatchQueue.async {
            print("\(self) stopping...")
            AudioQueueReset(self.audioQueue)
            print("\(self) stopped")
        }
    }
    
    static private func computeBufferSizeAndPacketCount(format:AudioStreamBasicDescription, maxPacketSize:UInt32, seconds:Float64) -> (UInt32,UInt32) {
        let maxBufferSize :UInt32 = 0x50000
        let minBufferSize :UInt32 = 0x4000
        
        var outBufferSize :UInt32
        var outNumPacketsToRead :UInt32
        
        if ( format.mFramesPerPacket != 0 ) {
            let numPacketsForTime :Float64 = format.mSampleRate / Float64(format.mFramesPerPacket) * seconds
            outBufferSize = UInt32(numPacketsForTime * Float64(maxPacketSize))
        } else {
            outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
        }
        
        if ( outBufferSize > maxBufferSize && outBufferSize > maxPacketSize ) {
            outBufferSize = maxBufferSize
        } else {
            if (outBufferSize < minBufferSize) {
                outBufferSize = minBufferSize
            }
        }
        
        outNumPacketsToRead = outBufferSize / maxPacketSize
        
        return (outBufferSize, outNumPacketsToRead)
    }

    deinit {
        AudioQueueDispose(self.audioQueue, false)
        print("\(self) deinitting")
    }
}



