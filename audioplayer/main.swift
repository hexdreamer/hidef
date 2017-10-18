/*	Copyright � 2007 Apple Inc. All Rights Reserved.
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by
 Apple Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc.
 may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */
// TODO: CoreFlat include defines...
//#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
//    #include <AudioToolbox/AudioQueue.h>
//    #include <AudioToolbox/AudioFile.h>
//    #include <AudioToolbox/AudioFormat.h>
//#else
//    #include "AudioQueue.h"
//    #include "AudioFile.h"
//    #include "AudioFormat.h"
//#endif
//#if TARGET_OS_WIN32
//    #include "QTML.h"
//#endif
// helpers
//#include "CAXException.h"
//#include "CAStreamBasicDescription.h"
//#include "CAAudioFileFormats.h"

import AudioToolbox

let kNumberBuffers = 3;
var gIsRunning :Bool = false;

class AQTestInfo {
    var mAudioFile:AudioFileID!
    var mDataFormat:AudioStreamBasicDescription!
    var mChannelLayout:UnsafeMutablePointer<AudioChannelLayout>!
    var mChannelLayoutSize:UInt32 = 0
    var mQueue:AudioQueueRef!
    var mBuffers:[AudioQueueBufferRef] = [AudioQueueBufferRef]()
    var mCurrentPacket:Int64 = 0
    var mNumPacketsToRead:UInt32 = 0
    var mPacketDescs:UnsafeMutablePointer<AudioStreamPacketDescription>!
    var mDone:Bool = false
	
    init()
//        : mChannelLayout (NULL),
//          mPacketDescs(NULL)
          {}
	
//    ~AQTestInfo ()
//    {
//        delete [] mChannelLayout;
//        delete [] mPacketDescs;
//    }
}

func AQTestBufferCallback(_ inUserData:UnsafeMutableRawPointer?,
                          _ inAQ:AudioQueueRef,
                          _ inCompleteAQBuffer:AudioQueueBufferRef)
{
    let info = inUserData!.load(as:AQTestInfo.self)
    if info.mDone { return };
    
    var numBytes :UInt32 = 0
    var nPackets :UInt32 = info.mNumPacketsToRead
    
    var result :OSStatus = AudioFileReadPackets(info.mAudioFile!, false, &numBytes, info.mPacketDescs, info.mCurrentPacket, &nPackets,
                                                inCompleteAQBuffer.pointee.mAudioData)
    if result != 0 {
        print("Error reading from file: \(result)\n")
        exit(1)
    }
    
    if (nPackets > 0) {
        inCompleteAQBuffer.pointee.mAudioDataByteSize = numBytes
        
        AudioQueueEnqueueBuffer(inAQ, inCompleteAQBuffer, (info.mPacketDescs != nil ? nPackets : UInt32(0)), info.mPacketDescs)
        
        info.mCurrentPacket += Int64(nPackets)
    } else {
        result = AudioQueueStop(info.mQueue!, false)
        if result != 0 {
            print ("AudioQueueStop(false) failed: \(result)")
            exit(1)
        }
        // reading nPackets == 0 is our EOF condition
        info.mDone = true;
    }
}
    
func usage()
{
//    #if !TARGET_OS_WIN32
//        const char *progname = getprogname();
//    #else
        let progname = "aqplay"
//    #endif
    print(
        """
        Usage:
        \(progname) [option...] audio_file
        
        Options: (may appear before or after arguments)
          {-v | --volume} VOLUME
            set the volume for playback of the file
          {-h | --help}
            print help
          {-t | --time} TIME
            play for TIME seconds
          {-r | --rate} RATE
            play at playback rate
          {-q | --rQuality} QUALITY
            set the quality used for rate-scaled playback (default is 0 - low quality, 1 - high quality)
          {-d | --debug}
            debug print output
        """
        )
    exit(1)
}
    
func MissingArgument()
{
    print("Missing argument\n")
    usage();
}
    
func MyAudioQueuePropertyListenerProc(_ inUserData:UnsafeMutableRawPointer?,
                                      _ inAQ:AudioQueueRef,
                                      _ inID:AudioQueuePropertyID)
{
    var size :UInt32 = UInt32(MemoryLayout<UInt32>.size)
    let err :OSStatus = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &gIsRunning, &size)
    if err != 0 {
        gIsRunning = false
    }
}
    
// we only use time here as a guideline
// we're really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it
func CalculateBytesForTime(_ inDesc:AudioStreamBasicDescription, _ inMaxPacketSize:UInt32, _ inSeconds:Float64) -> (UInt32,UInt32)
{
    let maxBufferSize:UInt32 = 0x10000; // limit size to 64K
    let minBufferSize:UInt32 = 0x4000; // limit size to 16K
    var outBufferSize, outNumPackets :UInt32
    if inDesc.mFramesPerPacket > 0 {
        let numPacketsForTime:Float64 = inDesc.mSampleRate / Float64(inDesc.mFramesPerPacket) * inSeconds
        outBufferSize = UInt32(numPacketsForTime * Float64(inMaxPacketSize))
    } else {
        // if frames per packet is zero, then the codec has no predictable packet == time
        // so we can't tailor this (we don't know how many Packets represent a time period
        // we'll just return a default buffer size
        outBufferSize = maxBufferSize > inMaxPacketSize ? maxBufferSize : inMaxPacketSize;
    }
    
    // we're going to limit our size to our default
    if outBufferSize > maxBufferSize && outBufferSize > inMaxPacketSize {
        outBufferSize = maxBufferSize;
    } else {
        // also make sure we're not too small - we don't want to go the disk for too small chunks
        if outBufferSize < minBufferSize {
            outBufferSize = minBufferSize;
        }
    }
    outNumPackets = outBufferSize / inMaxPacketSize;
    return (outBufferSize, outNumPackets)
}
    
    
func main(_ argc:Int, _ argv:[String]) -> Int
{
    //    #if TARGET_OS_WIN32
    //        InitializeQTML(0L);
    //    #endif
    var tmpfpath:String?
    var volume:Float32 = 1
    var duration:Float32 = 0
    var currentTime:Float32 = 0.0
    var rate:Float32? = 0
    var rQuality:Int? = 0
    
    var doPrint:Bool = false
    var i = 1 ; while i < argc { defer{i+=1}
        var arg = argv[i];
        if arg.first != "-" {
            if tmpfpath != nil {
                print("may only specify one file to play\n")
                usage()
            }
            tmpfpath = arg
        } else {
            arg = String(arg.dropFirst())
            if arg.first == "v" || arg == "-volume" {
                i+=1; if i == argc {
                    MissingArgument()
                }
                arg = argv[i]
                volume = Float32(arg)!
            } else if arg.first == "t" || arg == "-time" {
                i+=1; if i == argc {
                    MissingArgument()
                }
                arg = argv[i];
                duration = Float32(arg)!
            } else if arg.first == "r" || arg == "-rate" {
                i+=1; if i == argc {
                    MissingArgument()
                }
                arg = argv[i];
                rate = Float32(arg)
            } else if arg.first == "q" || arg == "-rQuality" {
                i+=1; if i == argc {
                    MissingArgument()
                }
                arg = argv[i];
                rQuality = Int(arg)
            } else if arg.first == "h" || arg == "-help" {
                usage()
            } else if arg.first == "d" || arg == "-debug" {
                doPrint = true
            } else {
                print("unknown argument: \(arg)\n\n")
                usage()
            }
        }
    }
    
    guard let fpath = tmpfpath else {
        usage(); fatalError()
    }
    
    if doPrint {
        print("Playing file: \(fpath)\n")
    }
    
    //    do {
    var myInfo:AQTestInfo = AQTestInfo()
    
    let sndFile:URL = URL(fileURLWithPath:fpath)
    //if (!sndFile) XThrowIfError (!sndFile, "can't parse file path");
    var fileID:AudioFileID?
    var result:OSStatus = AudioFileOpenURL(sndFile as CFURL, AudioFilePermissions.readPermission, 0/*inFileTypeHint*/, &fileID)
    myInfo.mAudioFile = fileID
    //CFRelease (sndFile);
    
    XThrowIfError(result, "AudioFileOpen failed")
    
    var size:UInt32 = 0
    XThrowIfError(AudioFileGetPropertyInfo(myInfo.mAudioFile!,
                                           kAudioFilePropertyFormatList, &size, nil), "couldn't get file's format list info")
    var numFormats:UInt32 = size / UInt32(MemoryLayout<AudioFormatListItem>.size)
    var formatList = UnsafeMutablePointer<AudioFormatListItem>.allocate(capacity:Int(numFormats))
    
    XThrowIfError(AudioFileGetProperty(myInfo.mAudioFile!,
                                       kAudioFilePropertyFormatList, &size, formatList), "couldn't get file's data format");
    numFormats = size / UInt32(MemoryLayout<AudioFormatListItem>.size) // we need to reassess the actual number of formats when we get it
    if numFormats == 1 {
        // this is the common case
        myInfo.mDataFormat = formatList[0].mASBD;
        
        // see if there is a channel layout (multichannel file)
        result = AudioFileGetPropertyInfo(myInfo.mAudioFile, kAudioFilePropertyChannelLayout, &myInfo.mChannelLayoutSize, nil);
        if result == noErr && myInfo.mChannelLayoutSize > 0 {
            myInfo.mChannelLayout = UnsafeMutableRawPointer.allocate(bytes:Int(myInfo.mChannelLayoutSize), alignedTo:0).assumingMemoryBound(to: AudioChannelLayout.self)
            XThrowIfError(AudioFileGetProperty(myInfo.mAudioFile!, kAudioFilePropertyChannelLayout, &myInfo.mChannelLayoutSize, myInfo.mChannelLayout!), "get audio file's channel layout")
        }
    } else {
        if (doPrint) {
            print("File has a \(numFormats) layered data format:\n")
            for i in 0..<numFormats {
                let format = formatList[Int(i)].mASBD
                //print("\(format.)%s %s\n", indent, name, AsString(buf, sizeof(buf)));
            }
        }
        // now we should look to see which decoders we have on the system
        XThrowIfError(AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, nil, &size), "couldn't get decoder id's");
        var numDecoders:UInt32 = size / UInt32(MemoryLayout<OSType>.size)
        var decoderIDs = UnsafeMutablePointer<OSType>.allocate(capacity:Int(numDecoders))
        XThrowIfError(AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, nil, &size, decoderIDs), "couldn't get decoder id's")
        var i:Int = 0
        while i < numFormats { defer {i+=1}
            let decoderID:OSType = formatList[i].mASBD.mFormatID
            var found:Bool = false
            for j in 0..<numDecoders {
                if (decoderID == decoderIDs[Int(j)]) {
                    found = true;
                    break;
                }
            }
            if found { break }
        }
        //delete [] decoderIDs;
        
        if (i >= numFormats) {
            print("Cannot play any of the formats in this file\n")
            fatalError()
        }
        myInfo.mDataFormat = formatList[i].mASBD;
        myInfo.mChannelLayoutSize = UInt32(MemoryLayout<AudioChannelLayout>.size)
        myInfo.mChannelLayout = UnsafeMutableRawPointer.allocate(bytes:Int(myInfo.mChannelLayoutSize), alignedTo:0).assumingMemoryBound(to: AudioChannelLayout.self)
        myInfo.mChannelLayout?.pointee.mChannelLayoutTag = formatList[i].mChannelLayoutTag
        myInfo.mChannelLayout?.pointee.mChannelBitmap = []
        myInfo.mChannelLayout?.pointee.mNumberChannelDescriptions = 0
    }
    //delete [] formatList;
    
    if (doPrint) {
        print("Playing format: ")
        //myInfo.mDataFormat.Print();
    }
    var audioQueue:AudioQueueRef?
    XThrowIfError(AudioQueueNewOutput(&myInfo.mDataFormat!, AQTestBufferCallback, &myInfo,
                                      CFRunLoopGetCurrent(), RunLoopMode.commonModes as CFString, 0, &audioQueue), "AudioQueueNew failed")
    myInfo.mQueue = audioQueue
    var bufferByteSize:UInt32
    // we need to calculate how many packets we read at a time, and how big a buffer we need
    // we base this on the size of the packets in the file and an approximate duration for each buffer
    //        {
    let isFormatVBR:Bool = (myInfo.mDataFormat!.mBytesPerPacket == 0 || myInfo.mDataFormat!.mFramesPerPacket == 0);
    
    // first check to see what the max size of a packet is - if it is bigger
    // than our allocation default size, that needs to become larger
    var maxPacketSize:UInt32 = 0
    size = UInt32(MemoryLayout<UInt32>.size)
    XThrowIfError(AudioFileGetProperty(myInfo.mAudioFile!,
                                       kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize), "couldn't get file's max packet size");
    
    // adjust buffer size to represent about a half second of audio based on this format
    (bufferByteSize, myInfo.mNumPacketsToRead) = CalculateBytesForTime(myInfo.mDataFormat, maxPacketSize, 0.5/*seconds*/)
    
    if isFormatVBR {
        myInfo.mPacketDescs = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity:Int(myInfo.mNumPacketsToRead))
    } else {
        myInfo.mPacketDescs = nil // we don't provide packet descriptions for constant bit rate formats (like linear PCM)
    }
    
    if doPrint {
        print("Buffer Byte Size: \(bufferByteSize), Num Packets to Read: \(myInfo.mNumPacketsToRead)\n")
    }
    //        }
    
    // (2) If the file has a cookie, we should get it and set it on the AQ
    size = UInt32(MemoryLayout<UInt32>.size)
    result = AudioFileGetPropertyInfo (myInfo.mAudioFile!, kAudioFilePropertyMagicCookieData, &size, nil)
    
    if result == noErr && size > 0 {
        let cookie = UnsafeMutableRawPointer.allocate(bytes: Int(size), alignedTo: 0)
        XThrowIfError (AudioFileGetProperty (myInfo.mAudioFile!, kAudioFilePropertyMagicCookieData, &size, cookie), "get cookie from file");
        XThrowIfError (AudioQueueSetProperty(myInfo.mQueue!, kAudioQueueProperty_MagicCookie, cookie, size), "set cookie on queue");
        //delete [] cookie;
    }
    
    // set ACL if there is one
    if myInfo.mChannelLayout != nil {
        XThrowIfError(AudioQueueSetProperty(myInfo.mQueue!, kAudioQueueProperty_ChannelLayout, myInfo.mChannelLayout!, myInfo.mChannelLayoutSize), "set channel layout on queue")
    }
    // prime the queue with some data before starting
    myInfo.mDone = false
    myInfo.mCurrentPacket = 0
    for i in 0..<kNumberBuffers {
        var buffer:AudioQueueBufferRef?
        XThrowIfError(AudioQueueAllocateBuffer(myInfo.mQueue!, bufferByteSize, &buffer), "AudioQueueAllocateBuffer failed")
        myInfo.mBuffers.append(buffer!)
        AQTestBufferCallback (&myInfo, myInfo.mQueue!, myInfo.mBuffers[i]);
        
        if myInfo.mDone { break }
    }
    // set the volume of the queue
    XThrowIfError (AudioQueueSetParameter(myInfo.mQueue!, kAudioQueueParam_Volume, volume), "set queue volume")
    
    XThrowIfError (AudioQueueAddPropertyListener (myInfo.mQueue!, kAudioQueueProperty_IsRunning, MyAudioQueuePropertyListenerProc, nil), "add listener")
    
    #if !TARGET_OS_IPHONE
        if rate! > 0 {
            var propValue:UInt32 = 1
            XThrowIfError (AudioQueueSetProperty (myInfo.mQueue!, kAudioQueueProperty_EnableTimePitch, &propValue, UInt32(MemoryLayout<UInt32>.size)), "enable time pitch")
            
            propValue = (rQuality != nil) ? kAudioQueueTimePitchAlgorithm_Spectral : kAudioQueueTimePitchAlgorithm_TimeDomain;
            XThrowIfError (AudioQueueSetProperty (myInfo.mQueue!, kAudioQueueProperty_TimePitchAlgorithm, &propValue, UInt32(MemoryLayout<UInt32>.size)), "time pitch algorithm")
            
            propValue = (rate == 1.0 ? 1 : 0); // bypass rate if 1.0
            XThrowIfError (AudioQueueSetProperty (myInfo.mQueue!, kAudioQueueProperty_TimePitchBypass, &propValue, UInt32(MemoryLayout<UInt32>.size)), "bypass time pitch");
            if rate != 1 {
                XThrowIfError (AudioQueueSetParameter (myInfo.mQueue!, kAudioQueueParam_PlayRate, rate!), "set playback rate")
            }
            
            if doPrint {
                print("Enable rate-scaled playback (rate = \(rate!) using \(((rQuality != nil) ? "Spectral": "Time Domain")) algorithm\n")
            }
        }
    #endif
    // lets start playing now - stop is called in the AQTestBufferCallback when there's
    // no more to read from the file
    XThrowIfError(AudioQueueStart(myInfo.mQueue!, nil), "AudioQueueStart failed")
    
    repeat {
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.25, false)
        currentTime += 0.25
        if duration > 0 && currentTime >= duration {
            break
        }
    } while (gIsRunning)
    
    CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
    
    XThrowIfError(AudioQueueDispose(myInfo.mQueue!, true), "AudioQueueDispose(true) failed");
    XThrowIfError(AudioFileClose(myInfo.mAudioFile!), "AudioQueueDispose(false) failed");
    //    }
    //    catch (CAXException e) {
    //        char buf[256];
    //        fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
    //    }
    //    catch (...) {
    //        fprintf(stderr, "Unspecified exception\n");
    //    }
    
    return 0
}

func XThrowIfError(_ status:OSStatus, _ message:String) {
    if status != noErr {
        fatalError(message)
    }
}


let result = main(Int(CommandLine.argc), CommandLine.arguments)
print("result: \(result)")


