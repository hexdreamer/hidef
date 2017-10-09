//
//  PDAudioBuffer.swift
//  HiDef
//
//  Created by Kenny Leung on 9/23/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

/*
 public struct AudioQueueBuffer {
     public var mAudioDataBytesCapacity: UInt32
     public var mAudioData: UnsafeMutableRawPointer
     public var mAudioDataByteSize: UInt32
     public var mUserData: UnsafeMutableRawPointer?
     public var mPacketDescriptionCapacity: UInt32
     public var mPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?
     public var mPacketDescriptionCount: UInt32
 }
 */

import AudioToolbox

class PDAudioBuffer {

    public let audioQueueBuffer :AudioQueueBufferRef
    
    public var bufferCapacity :UInt32 {
        get {return self.audioQueueBuffer.pointee.mAudioDataBytesCapacity}
    }
    
    public var bufferPointer :UnsafeMutableRawPointer {
        get {return self.audioQueueBuffer.pointee.mAudioData}
    }
    
    public var bufferBytesRead :UInt32 {
        get {return self.audioQueueBuffer.pointee.mAudioDataByteSize}
        set(value) {self.audioQueueBuffer.pointee.mAudioDataByteSize = value}
    }
    
    public var packetDescriptionCapacity :UInt32 {
        get {return self.audioQueueBuffer.pointee.mPacketDescriptionCapacity}
    }
    
    public var packetDescriptions :UnsafeMutablePointer<AudioStreamPacketDescription>? {
        get {return self.audioQueueBuffer.pointee.mPacketDescriptions}
    }
    
    public var packetDescriptionsRead :UInt32 {
        get {return self.audioQueueBuffer.pointee.mPacketDescriptionCount}
        set(value) {self.audioQueueBuffer.pointee.mPacketDescriptionCount = value}
    }
    
    init?(audioQueue:AudioQueueRef, bufferSize:UInt32, numberOfPacketDescriptions:UInt32) {
        var tmpAQBuffer :AudioQueueBufferRef?
        var status :OSStatus = 0
        if numberOfPacketDescriptions == 0 {
            status = AudioQueueAllocateBuffer(audioQueue, bufferSize, &tmpAQBuffer)
        } else {
            status = AudioQueueAllocateBufferWithPacketDescriptions(audioQueue, bufferSize, numberOfPacketDescriptions, &tmpAQBuffer);
        }
        if status != 0 {
            return nil
        }
        guard let nnAQBuffer = tmpAQBuffer else {
            return nil
        }
        
        self.audioQueueBuffer = nnAQBuffer
    }
}
