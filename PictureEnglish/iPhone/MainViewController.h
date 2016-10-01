//
//  MainViewController.h
//  PictureEnglish
//
//  Created by 김인로 on 2016. 8. 18..
//  Copyright © 2016년 김인로. All rights reserved.
//

#import <UIKit/UIKit.h>

@import AVFoundation;

@interface MainViewController : UIViewController <AVSpeechSynthesizerDelegate, NSXMLParserDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate, NSURLSessionDelegate>

@end
