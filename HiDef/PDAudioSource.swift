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
    var mCurrentPacket :Int64 = 0

    let mPacketDescs :UnsafeMutablePointer<AudioStreamPacketDescription>?  // 9

    init(dataFormat:AudioStreamBasicDescription) {
        self.mDataFormat = dataFormat
        self.mPacketDescs = nil
    }
    
    func fillBuffer(_ buffer:PDAudioBuffer) {}
}
