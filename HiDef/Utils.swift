//
//  Utils.swift
//  HiDef
//
//  Created by Kenny Leung on 10/18/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import Foundation
import AudioToolbox

func debugDescription(channelLayoutRef:UnsafeMutablePointer<AudioChannelLayout>) {
    print("AudioChannelLayout: \(channelLayoutRef)")
    print("    mChannelLayoutTag:          \(channelLayoutRef.pointee.mChannelLayoutTag)")
    print("    mChannelBitmap:             \(channelLayoutRef.pointee.mChannelBitmap)")
    print("    mNumberChannelDescriptions: \(channelLayoutRef.pointee.mNumberChannelDescriptions)")
    print("    mChannelDescriptions:       \(channelLayoutRef.pointee.mChannelDescriptions)")
}
