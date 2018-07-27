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

// We'd like all of this stuff to be static members of PDAudioPlayer, but you can't pass a static method to a C function pointer for AudioQueueAddPropertyListener
private let _audioQueue:DispatchQueue = DispatchQueue(label:"AudioPlayer", qos:.default, attributes:[.concurrent], autoreleaseFrequency:.workItem, target:nil)
private let _serialQueue:DispatchQueue = DispatchQueue(label:"AudioPlayer_serial", qos:.default, attributes:[], autoreleaseFrequency:.workItem, target:nil)
private var _zombieAudioQueues = Set<AudioQueueRef>()

func MyAudioQueuePropertyListenerProc(_ inUserData:UnsafeMutableRawPointer?, _ inAQ:AudioQueueRef, _ inID:AudioQueuePropertyID) {
    _serialQueue.async {
        _disposeAudioQueueIfNecessary(inAQ)
    }
}

func _disposeAudioQueueIfNecessary(_ audioQueue: AudioQueueRef) {
    var isRunning:UInt32 = 0
    var size :UInt32 = UInt32(MemoryLayout<UInt32>.size)
    let err :OSStatus = AudioQueueGetProperty(audioQueue, kAudioQueueProperty_IsRunning, &isRunning, &size)
    print("checking for disposal audioQueue:\(audioQueue) isRunning:\(isRunning) zombie:\(_zombieAudioQueues.contains(audioQueue)) err:\(err)")
    if err == 0 {
        if isRunning == 0 && _zombieAudioQueues.contains(audioQueue) {
            print("disposing of audio queue \(audioQueue)...")
            AudioQueueReset(audioQueue)
            AudioQueueDispose(audioQueue, true)
            print("... audio queue \(audioQueue) disposed")
            _zombieAudioQueues.remove(audioQueue)
        }
    }
}

class PDAudioPlayer {
    
    // This is not great architecture, but just a trick to help us get around initialization order problesm. Mostly because we are not fully initialized before we have to capture stuff for AudioQueueNewOutputWithDispatchQueue
    private class InternalData {
        let source :PDAudioSource
        var audioBuffers = [PDAudioBuffer]()
        var playing: Bool = false
        
        init(source:PDAudioSource) {
            self.source = source
        }
    }
    
    private let audioQueue :AudioQueueRef
    private let data       :InternalData
    
    static let kNumberBuffers :Int = 3
    var bufferByteSize :UInt32
    var mNumPacketsToRead :UInt32
    
    var isPlaying:Bool {return data.playing}
    
    init?(source:PDAudioSource) {
        var status:OSStatus
        
        let tmpData = InternalData(source:source)
        
        var tmpAudioQueue :AudioQueueRef?
        var dataFormat = source.mDataFormat
        status = AudioQueueNewOutputWithDispatchQueue(&tmpAudioQueue, &dataFormat, 0, _audioQueue) {
            (baqQueue, baqBuffer) in
            for audioBuffer in tmpData.audioBuffers {
                if audioBuffer.audioQueueBuffer == baqBuffer {
                    if audioBuffer.priming || tmpData.playing {
                        tmpData.source.fillBuffer(audioBuffer);
                        audioBuffer.priming = false
                        AudioQueueEnqueueBuffer(baqQueue, baqBuffer, 0, nil)
                    } else {
                        print("Skipping...")
                    }
                }
            }
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
        
        AudioQueueAddPropertyListener (nnAudioQueue, kAudioQueueProperty_IsRunning, MyAudioQueuePropertyListenerProc, nil)

        self.data = tmpData
        self.audioQueue = nnAudioQueue
        
        (self.bufferByteSize, self.mNumPacketsToRead) = PDAudioPlayer.computeBufferSizeAndPacketCount(format:source.mDataFormat, maxPacketSize:0x100, seconds:1)
        for _ in 0..<30 {
            guard let buffer = PDAudioBuffer(audioQueue:self.audioQueue, bufferSize:self.bufferByteSize, numberOfPacketDescriptions:self.mNumPacketsToRead) else {
                return nil
            }
            buffer.priming = true
            self.data.audioBuffers.append(buffer)
            self.data.source.fillBuffer(buffer);
            AudioQueueEnqueueBuffer(self.audioQueue, buffer.audioQueueBuffer, 0, nil)
        }
        AudioQueuePrime(self.audioQueue, 0, nil)
    }
    
    deinit {
        let aq = self.audioQueue
        _serialQueue.async {
            _zombieAudioQueues.insert(aq)
            _disposeAudioQueueIfNecessary(aq)
        }
    }
    
    public func play() {
        print("\(self) requestPlay")
        _serialQueue.async {
            self.data.playing = true
            AudioQueueStart(self.audioQueue, nil)
            print("\(self) play")
        }
    }
    
    public func pause() {
        print("\(self) requestPause")
        _serialQueue.async {
            AudioQueuePause(self.audioQueue)
            print("\(self) pause")
        }
    }
    
    public func stop() {
        print("\(self) requestStop")
        self.data.playing = false
        _serialQueue.async {
            print("\(self) stopping...")
            AudioQueueStop(self.audioQueue, false)
            //AudioQueueReset(self.audioQueue)
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

}

