//
//  PDAudioPlayer.swift
//  HiDef
//
//  Created by Kenny Leung on 9/22/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import Foundation
import AudioToolbox

class PDAudioPlayer {
    static let kNumberBuffers :Int = 3                              // 1
    var mDataFormat:AudioStreamBasicDescription                     // 2
    var mQueue :AudioQueueRef?                                      // 3
    //var mBuffers :[AudioQueueBufferRef]                            // 4
    //var mAudioFile :AudioFileID?                                    // 5
    var bufferByteSize :UInt32?                                     // 6
    var mCurrentPacket :Int64?                                      // 7
    var mNumPacketsToRead :UInt32?                                  // 8
    var mPacketDescs :UnsafePointer<AudioStreamPacketDescription>?  // 9
    var mIsRunning: Bool = false                                    // 10
    
    let dispatchQueue :DispatchQueue
    let source :PDFileAudioSource
    var audioBuffers :[PDAudioBuffer]
    
    init?(source:PDFileAudioSource) {
        self.source = source
        self.mDataFormat = source.mDataFormat
        self.dispatchQueue = DispatchQueue(label:"AudioPlayer", qos:.default, attributes:[], autoreleaseFrequency:.workItem, target:nil)
        self.audioBuffers = [PDAudioBuffer]()

        var newAudioQueue :AudioQueueRef?
        let status = AudioQueueNewOutputWithDispatchQueue(&newAudioQueue, &self.mDataFormat, 0, self.dispatchQueue) { [weak self] (queue, buffer) in
            guard let this = self else {
                return
            }
            guard let audioBuffer = this.audioBufferForAudioQueueBuffer(aqBuffer:buffer) else {
                return
            }
            this.source.fillBuffer(audioBuffer)
        }
        if status != 0 || newAudioQueue == nil {
            return nil
        }
    }

    private func audioBufferForAudioQueueBuffer(aqBuffer:AudioQueueBufferRef) -> PDAudioBuffer? {
        for buffer in self.audioBuffers {
            if buffer.audioQueueBuffer == aqBuffer {
                return buffer
            }
        }
        return nil
    }
}



