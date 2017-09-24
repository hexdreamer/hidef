//
//  ViewController.swift
//  HiDef
//
//  Created by Kenny Leung on 9/22/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var audioPlayer :PDAudioPlayer?;
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        guard let audioFileURL = Bundle.main.url(forResource:"Vocalise", withExtension:"m4a"),
            let audioSource = PDFileAudioSource(url:audioFileURL) else {
            return
        }
        self.audioPlayer = PDAudioPlayer(source:audioSource)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

