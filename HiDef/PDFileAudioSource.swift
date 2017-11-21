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

    public enum PDError : Error {
        case SomeError
    }
    
    let fileURL:URL
    let mAudioFile:AudioFileID

    init?(url:URL) {
        var status :OSStatus
        
        var tmpAudioFileID :AudioFileID?
        status = AudioFileOpenURL(url as CFURL, .readPermission, 0, &tmpAudioFileID)
        if ( status != noErr ) {
            return nil
        }
        guard let audioFileID = tmpAudioFileID else {
            return nil
        }
        
        self.fileURL = url
        self.mAudioFile = audioFileID
        do {
            let dataFormat = try PDFileAudioSource.readDataFormat(fileID:audioFileID)
            let (channelLayout,channelLayoutSize) = try PDFileAudioSource.readChannelLayout(fileID:audioFileID)
            let (cookie,cookieSize) = try PDFileAudioSource.readCookie(fileID:audioFileID)
            super.init(dataFormat:dataFormat, channelLayout:channelLayout, channelLayoutSize:channelLayoutSize, cookie:cookie, cookieSize:cookieSize)
        } catch {
            return nil
        }
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
        //print("\(self.fileURL.lastPathComponent) current packet: \(self.mCurrentPacket)")
    }

    // MARK: - Private static functions
    static func readDataFormat(fileID:AudioFileID) throws -> AudioStreamBasicDescription {
        var status:OSStatus

        var tmpDataFormat :AudioStreamBasicDescription? = AudioStreamBasicDescription()
        var dataFormatSize :UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &dataFormatSize, &tmpDataFormat)
        if status != noErr {
            throw PDError.SomeError
        }
        guard let dataFormat = tmpDataFormat else {
            throw PDError.SomeError
        }
        return dataFormat
    }
    
    static func readChannelLayout(fileID:AudioFileID) throws -> (UnsafeMutablePointer<AudioChannelLayout>?,UInt32?) {
        var status:OSStatus
        
        var size:UInt32 = 0
        
        /*
        AudioFileGetPropertyInfo(fileID,kAudioFilePropertyFormatList, &size, nil)
        var numFormats:UInt32 = size / UInt32(MemoryLayout<AudioFormatListItem>.size)
        var formatList = UnsafeMutablePointer<AudioFormatListItem>.allocate(capacity:Int(numFormats))
        AudioFileGetProperty(fileID, kAudioFilePropertyFormatList, &size, formatList)
        */
        
        status = AudioFileGetPropertyInfo(fileID, kAudioFilePropertyChannelLayout, &size, nil);
        if status != noErr || size == 0 {
            return (nil,nil)
        }
        
        let channelLayout = UnsafeMutableRawPointer.allocate(bytes:Int(size), alignedTo:0).assumingMemoryBound(to: AudioChannelLayout.self)
        status = AudioFileGetProperty(fileID, kAudioFilePropertyChannelLayout, &size, channelLayout)
        debugDescription(channelLayoutRef:channelLayout)
        if status != noErr {
            throw PDError.SomeError
        }
        
        return (channelLayout,size)
    }
    
    static func readCookie(fileID:AudioFileID) throws -> (UnsafeMutableRawPointer?,UInt32?) {
        var status:OSStatus
        
        var size = UInt32(MemoryLayout<UInt32>.size)
        status = AudioFileGetPropertyInfo(fileID, kAudioFilePropertyMagicCookieData, &size, nil)
        if status != noErr || size == 0 {
            return (nil,nil)
        }
        
        let cookie = UnsafeMutableRawPointer.allocate(bytes:Int(size), alignedTo:0)
        status = AudioFileGetProperty(fileID, kAudioFilePropertyMagicCookieData, &size, cookie)
        if status != noErr {
            throw PDError.SomeError
        }
        
        return (cookie,size)
    }
}
