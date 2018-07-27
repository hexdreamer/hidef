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
            let (nDataFormat,_) = try PDFileAudioSource.getPropertyValue(AudioStreamBasicDescription.self, kAudioFilePropertyDataFormat, audioFileID)
            let (channelLayout,channelLayoutSize) = try PDFileAudioSource.getPropertyTypedPointer(AudioChannelLayout.self, kAudioFilePropertyChannelLayout, audioFileID)
            let (cookie,cookieSize) = try PDFileAudioSource.getPropertyPointer(kAudioFilePropertyMagicCookieData, audioFileID)
            guard let dataFormat = nDataFormat else {
                return nil
            }
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
    }

    // MARK: - Static Private functions
    static private func getPropertyValue<T>(_ propertyType:T.Type, _ propertyID:AudioFilePropertyID, _ fileID:AudioFileID) throws -> (T?,UInt32?) {
        let (prop,size) = try getPropertyTypedPointer(propertyType, propertyID, fileID)
        guard let nnprop = prop else {
            return (nil, nil)
        }
        let value = nnprop.pointee
        return (value,size)
    }
    
    static private func getPropertyTypedPointer<T>(_ propertyType:T.Type, _ propertyID:AudioFilePropertyID, _ fileID:AudioFileID) throws -> (UnsafePointer<T>?,UInt32?) {
        let (prop,size) = try getPropertyPointer(propertyID, fileID)
        guard let nnprop = prop else {
            return (nil, nil)
        }
        let typedProp = nnprop.assumingMemoryBound(to: propertyType)
        return (typedProp,size)
    }
    
    static private func getPropertyPointer(_ propertyID:AudioFilePropertyID, _ fileID:AudioFileID) throws -> (UnsafeRawPointer?,UInt32?) {
        var status:OSStatus
        
        var size = UInt32(MemoryLayout<UInt32>.size)
        status = AudioFileGetPropertyInfo(fileID, propertyID, &size, nil)
        if status != noErr {
            throw PDError.SomeError
        }
        if size == 0 {
            return (nil,nil)
        }
        
        let prop = UnsafeMutableRawPointer.allocate(bytes:Int(size), alignedTo:0)
        status = AudioFileGetProperty(fileID, propertyID, &size, prop)
        if status != noErr {
            throw PDError.SomeError
        }
        
        return (UnsafeRawPointer(prop),size)
    }

}
