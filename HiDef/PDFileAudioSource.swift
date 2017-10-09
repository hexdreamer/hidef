//
//  FileAudioSource.swift
//  HiDef
//
//  Created by Kenny Leung on 9/23/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import AudioToolbox
import Foundation

class PDFileAudioSource : PDAudioSource {

    let fileURL :URL
    let mAudioFile :AudioFileID
    let cookie :UnsafeMutableRawPointer?
    let cookieSize :UInt32?
    
    init?(url:URL) {
        var status :OSStatus = 0
        
        var tmpAudioFileID :AudioFileID?
        status = AudioFileOpenURL(url as CFURL, .readPermission, 0, &tmpAudioFileID)
        if ( status != 0 ) {
            return nil
        }
        guard let audioFileID = tmpAudioFileID else {
            return nil
        }
        
        var dataFormat :AudioStreamBasicDescription = AudioStreamBasicDescription()
        var dataFormatSize :UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &dataFormatSize, &dataFormat);
        if ( status != 0 ) {
            return nil
        }
        
        var tmpCookieSize :UInt32 = UInt32(MemoryLayout<UInt32>.size)
        status = AudioFileGetPropertyInfo ( audioFileID, kAudioFilePropertyMagicCookieData, &tmpCookieSize, nil);
        
        if ( status == 0 && tmpCookieSize != 0 ) {
            var magicCookie = malloc(Int(tmpCookieSize));
            AudioFileGetProperty(audioFileID, kAudioFilePropertyMagicCookieData, &tmpCookieSize, &magicCookie);
            self.cookie = magicCookie
            self.cookieSize = tmpCookieSize
        } else {
            self.cookie = nil
            self.cookieSize = nil
        }

        self.fileURL = url
        self.mAudioFile = audioFileID
        super.init(dataFormat:dataFormat)
    }
    
    override func fillBuffer(_ buffer:PDAudioBuffer) {
        var bytesRead :UInt32 = buffer.bufferCapacity
        var packetsRead :UInt32 = buffer.packetDescriptionCapacity
        
        let status = AudioFileReadPacketData(self.mAudioFile, false, &bytesRead, buffer.packetDescriptions, self.mCurrentPacket, &packetsRead, buffer.bufferPointer)
        if status != 0 {
            print("Error filling buffer")
            return
        }
        buffer.bufferBytesRead = bytesRead
        buffer.packetDescriptionsRead = packetsRead
        self.mCurrentPacket += Int64(packetsRead)
        print("current packet: \(self.mCurrentPacket)")
    }

}
