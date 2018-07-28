//
//  ViewController.swift
//  HiDef
//
//  Created by Kenny Leung on 9/22/17.
//  Copyright © 2017 PepperDog Enterprises. All rights reserved.
//

import UIKit

class ViewController: UIViewController,
                      UITableViewDataSource, UITableViewDelegate {

    var _songs = [URL]()
    var audioSource :PDFileAudioSource?
    var audioPlayer :PDAudioPlayer?
    
    @IBOutlet var songsTableView:UITableView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self._songs.removeAll()
        
        if let aifs = Bundle.main.urls(forResourcesWithExtension:".aif", subdirectory:nil) {
            self._songs.append(contentsOf:aifs)
        }
        if let m4as = Bundle.main.urls(forResourcesWithExtension:".m4a", subdirectory:nil) {
            self._songs.append(contentsOf:m4as)
        }
        //self._songs.append(contentsOf:Bundle.main.urls(forResourcesWithExtension:".aif", subPath:nil))
        //self._songs.append(contentsOf:Bundle.main.urls(forResourcesWithExtension:".m4a", subPath:nil))

        /*
        guard let audioFileURL = Bundle.main.url(forResource:"AnvilOfCrom", withExtension:"aif"),
        //guard let audioFileURL = Bundle.main.url(forResource:"Vocalise", withExtension:"m4a"),
            let audioSource = PDFileAudioSource(url:audioFileURL) else {
            return
        }
        self.audioPlayer = PDAudioPlayer(source:audioSource)
        self.audioPlayer?.play()
         */
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UITableViewDataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self._songs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let i = indexPath.last,
              let cell = tableView.dequeueReusableCell(withIdentifier:"AudioFileCell") else {
            fatalError()
        }
        
        let url = self._songs[i]
        let filename = url.lastPathComponent
        cell.textLabel?.text = filename
        return cell
    }

    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView:UITableView, didSelectRowAt indexPath:IndexPath) {
        guard let i = indexPath.last else {
            return
        }
        
        let url = self._songs[i]
        if  let currentAudioSource = self.audioSource,
            let currentAudioPlayer = self.audioPlayer {
            if currentAudioSource.fileURL == url {
                if !currentAudioPlayer.isPlaying {
                    currentAudioPlayer.play()
                }
                return
            } else {
                if currentAudioPlayer.isPlaying {
                    currentAudioPlayer.pause()
                }
            }
        }
        
        guard let newAudioSource = PDFileAudioSource(url:url) else {
            let alert = UIAlertController(title:"Error", message:"Error reading audio file", preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:NSLocalizedString("Continue", comment:""), style:.default, handler:nil))
            self.present(alert, animated:true, completion: nil)
            return
        }
        
        guard let newAudioPlayer = PDAudioPlayer(source:newAudioSource) else {
            let alert = UIAlertController(title:"Error", message:"Error initializing audio player", preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:NSLocalizedString("Continue", comment:""), style:.default, handler:nil))
            self.present(alert, animated:true, completion: nil)
            return
        }
        
        if let currentAudioPlayer = self.audioPlayer {
            currentAudioPlayer.stop()
        }
        self.audioSource = newAudioSource
        self.audioPlayer = newAudioPlayer
        newAudioPlayer.play()
    }
    
    // MARK: - Action Methods
    @IBAction func play(sender:UIButton) {
        guard let audioPlayer = self.audioPlayer else {
            return
        }
        audioPlayer.play()
    }
    
    @IBAction func pause(sender:UIButton) {
        guard let audioPlayer = self.audioPlayer else {
            return
        }
        audioPlayer.pause()
    }

}

