//
//  PDAudioSource.swift
//  HiDef
//
//  Created by Kenny Leung on 9/23/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import AudioToolbox

class PDAudioSource {

    let mDataFormat:AudioStreamBasicDescription
    let cookie:UnsafeMutableRawPointer?
    let cookieSize:UInt32?
    let channelLayout:UnsafeMutablePointer<AudioChannelLayout>?
    let channelLayoutSize:UInt32?
    var mCurrentPacket :Int64 = 0

    init(dataFormat:AudioStreamBasicDescription,
         channelLayout:UnsafeMutablePointer<AudioChannelLayout>?,
         channelLayoutSize:UInt32?,
         cookie:UnsafeMutableRawPointer?,
         cookieSize:UInt32?
        ) {
        self.mDataFormat = dataFormat
        self.channelLayout = channelLayout
        self.channelLayoutSize = channelLayoutSize
        self.cookie = cookie
        self.cookieSize = cookieSize
    }
    
    func fillBuffer(_ buffer:PDAudioBuffer) {}
}
