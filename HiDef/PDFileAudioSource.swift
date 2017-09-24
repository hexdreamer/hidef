//
//  FileAudioSource.swift
//  HiDef
//
//  Created by Kenny Leung on 9/23/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import AudioToolbox

class PDFileAudioSource : PDAudioSource {

    let fileURL :URL
    let mAudioFile :AudioFileID
    
    init?(url:URL) {
        var audioFileID :AudioFileID?
        let status = AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFileID)
        if ( status != 0 ) {
            return nil
        }
        guard let nnAudioFileID = audioFileID else {
            return nil
        }
        
        self.fileURL = url
        self.mAudioFile = nnAudioFileID
    }
    
}
