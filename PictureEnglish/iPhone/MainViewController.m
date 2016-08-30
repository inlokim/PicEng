//
//  MainViewController.m
//  PictureEnglish
//
//  Created by 김인로 on 2016. 8. 18..
//  Copyright © 2016년 김인로. All rights reserved.
//

#import "MainViewController.h"


#define PLAY YES
#define STOP NO
#define DEFAULT_SPEED 0.3

#define ENGLISH 1
#define KOREAN 2
#define CHINESE 3
#define JAPANESE 4




@interface MainViewController ()
{
    
    BOOL speechPlaying;
    
    NSUInteger transStatus;
    
    AVSpeechSynthesizer *synthesizer;
    AVSpeechUtterance *synUtt;

    NSUInteger totalPage;
    NSUInteger currentPage;
    NSUInteger indexOfRow;
    NSUInteger prevPage;
    
    AVAudioRecorder *recorder;
    AVAudioPlayer *player;

}

@property (weak, nonatomic) IBOutlet UIButton *recordPauseButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;

@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UILabel *pageNumber;
@property (strong, nonatomic) IBOutlet UIButton *speakButton;
@property (strong, nonatomic) IBOutlet UIButton *transButton;
@property (strong, nonatomic) IBOutlet UIButton *leftArrow;
@property (strong, nonatomic) IBOutlet UIButton *rightArrow;

@property (readwrite, nonatomic, copy) NSString *utteranceString;
@property (readwrite, nonatomic, copy) NSString *translatedString;


@property (nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic, strong) NSMutableArray *arrNeighboursData;
@property (nonatomic, strong) NSMutableDictionary *dictTempDataStorage;
@property (nonatomic, strong) NSMutableString *foundValue;
@property (nonatomic, strong) NSString *currentElement;

@end

@implementation MainViewController


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    
    synthesizer = [[AVSpeechSynthesizer alloc] init];

    
    transStatus = ENGLISH;

    //XML
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"sample" ofType:@"xml"];
    self.xmlParser = [[NSXMLParser alloc] initWithData:[NSData dataWithContentsOfFile:path]];
    self.foundValue = [[NSMutableString alloc] init];
    self.xmlParser.delegate = self;
    [self.xmlParser parse];


    currentPage = 1;
    
    
    //Arrow
    
   // self.leftArrow.alpha = 0.0;
   // self.rightArrow.alpha = 0.0;
    
    if (currentPage == 1) [self.leftArrow setHidden:YES];
    if (currentPage == totalPage) [self.rightArrow setHidden:YES];
    
    
    //pageNumber
    totalPage = [self.arrNeighboursData count];
    [self makePageNumber];
    
    
    //ImageView

    [self makeImageView];

    
    //Label
    [self makeLabel:@"English"];
    
    //Swipe
    
    [self.imageView setUserInteractionEnabled:YES];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    
    // Setting the swipe direction.
    [swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    
    // Adding the swipe gesture on image view
    [self.view addGestureRecognizer:swipeLeft];
    [self.view addGestureRecognizer:swipeRight];
    
    // Image Tap
 /*   UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDetected)];
    singleTap.numberOfTapsRequired = 1;
    [self.view setUserInteractionEnabled:YES];
    [self.view addGestureRecognizer:singleTap];*/
    
    
    speechPlaying = STOP;
    
    
    //RECORDING
    
    // Disable Stop/Play button when application launches
  
    [self.playButton setEnabled:NO];
    [self.playButton setAlpha:0.0];
    
    
    // Set the audio file
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               @"MyAudioMemo.m4a",
                               nil];
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];
    
    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    //[session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    
    // Define the recorder setting
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    
    // Initiate and prepare the recorder
    recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:NULL];
    recorder.delegate = self;
    recorder.meteringEnabled = YES;
    [recorder prepareToRecord];
}
//ImageView

-(void)initButtons {
    [self.speakButton setImage:[UIImage imageNamed:@"speaker_off"] forState:UIControlStateNormal];
    [self.transButton setImage:[UIImage imageNamed:@"translation_off"] forState:UIControlStateNormal];
}

-(void)makeLabel:(NSString *)language {
    indexOfRow = currentPage - 1;
    self.label.text = [[self.arrNeighboursData objectAtIndex:indexOfRow] objectForKey:language];
    self.utteranceString = self.label.text;
}

-(void)makeImageView {
    
    NSString *prefix = @"e1";
    NSString *imageName;
    
    if (currentPage < 10) imageName = [NSString stringWithFormat:@"%@_00%lu",prefix,(unsigned long)currentPage];
    else if (currentPage > 9 && currentPage < 100) imageName = [NSString stringWithFormat:@"%@_0%lu",prefix,(unsigned long)currentPage];
    else if (currentPage > 99) imageName = [NSString stringWithFormat:@"%@_%lu",prefix,(unsigned long)currentPage];
    
    self.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png",imageName]];
}

-(void)makePageNumber {
    self.pageNumber.text = [NSString stringWithFormat:@"%lu/%lu",(unsigned long)currentPage,(unsigned long)totalPage];
}


#pragma mark - Recording


//Mic button

- (IBAction)recordPauseTapped:(id)sender {
    // Stop the audio player before recording
    [self.playButton setEnabled:NO];
    [self.playButton setAlpha:0.0];
    
    if (player.playing) {
        [player stop];
    }
    
    if (!recorder.recording) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        
        // Start recording
        [recorder record];
        [self.recordPauseButton setImage:[UIImage imageNamed:@"mic_on"] forState:UIControlStateNormal];
        [self.playButton setEnabled:NO];
    }
    else {
        // Pause recording
        [recorder stop];
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];
        [self.recordPauseButton setImage:[UIImage imageNamed:@"mic_off"] forState:UIControlStateNormal];
        [self.playButton setEnabled:YES];
    }
    
   // [self.stopButton setEnabled:YES];
    
}

- (void) audioRecorderDidFinishRecording:(AVAudioRecorder *)avrecorder successfully:(BOOL)flag{
    [self.recordPauseButton setTitle:@"Record" forState:UIControlStateNormal];
   // [self.stopButton setEnabled:NO];
    [self.playButton setEnabled:YES];
    [self.playButton setAlpha:1.0];
    [self.playButton setImage:[UIImage imageNamed:@"play_off"] forState:UIControlStateNormal];

}


//Play Button

- (IBAction)playTapped:(id)sender {
    if (!recorder.recording){
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:recorder.url error:nil];
        [player setDelegate:self];
        [player play];
        
        [self.playButton setImage:[UIImage imageNamed:@"play_on"] forState:UIControlStateNormal];
    }
}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
   /* UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Done"
                                                    message: @"Finish playing the recording!"
                                                   delegate: nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];*/
    
   // [self.playButton setAlpha:0.0];
    
    [self.playButton setImage:[UIImage imageNamed:@"play_off"] forState:UIControlStateNormal];
}




#pragma mark - NSXMLParser

-(void)parserDidStartDocument:(NSXMLParser *)parser{
    // Initialize the neighbours data array.
    self.arrNeighboursData = [[NSMutableArray alloc] init];
}

-(void)parserDidEndDocument:(NSXMLParser *)parser{
    // When the parsing has been finished then simply reload the table view.
    //[self.tblNeighbours reloadData];
}


-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict{
    
    // If the current element name is equal to "geoname" then initialize the temporary dictionary.
    if ([elementName isEqualToString:@"row"]) {
        self.dictTempDataStorage = [[NSMutableDictionary alloc] init];
    }
    
    // Keep the current element.
    self.currentElement = elementName;
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    
    if ([elementName isEqualToString:@"row"]) {
        // If the closing element equals to "geoname" then the all the data of a neighbour country has been parsed and the dictionary should be added to the neighbours data array.
        [self.arrNeighboursData addObject:[[NSDictionary alloc] initWithDictionary:self.dictTempDataStorage]];
    }
    else if ([elementName isEqualToString:@"FIELD1"]){
        
        //NSLog(@"English : %@", [NSString stringWithString:self.foundValue]);
        
        // If the country name element was found then store it.
        [self.dictTempDataStorage setObject:[NSString stringWithString:self.foundValue] forKey:@"English"];
    }
    else if ([elementName isEqualToString:@"FIELD2"]){
        
        NSLog(@"Korean : %@", [NSString stringWithString:self.foundValue]);
        
        // If the toponym name element was found then store it.
        [self.dictTempDataStorage setObject:[NSString stringWithString:self.foundValue] forKey:@"Korean"];
    }
    else if ([elementName isEqualToString:@"FIELD3"]){
        
       // NSLog(@"Chinese : %@", [NSString stringWithString:self.foundValue]);
        
        // If the toponym name element was found then store it.
        [self.dictTempDataStorage setObject:[NSString stringWithString:self.foundValue] forKey:@"Chinese"];
    }
    else if ([elementName isEqualToString:@"FIELD4"]){
        
       // NSLog(@"Chinese : %@", [NSString stringWithString:self.foundValue]);
        
        // If the toponym name element was found then store it.
        [self.dictTempDataStorage setObject:[NSString stringWithString:self.foundValue] forKey:@"Japanese"];
    }
    // Clear the mutable string.
    [self.foundValue setString:@""];
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
    // Store the found characters if only we're interested in the current element.
    if ([self.currentElement isEqualToString:@"FIELD1"] ||
        [self.currentElement isEqualToString:@"FIELD2"] ||
        [self.currentElement isEqualToString:@"FIELD3"] ||
        [self.currentElement isEqualToString:@"FIELD4"]) {
        
        if (![string isEqualToString:@"\n"]) {
            
            string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [self.foundValue appendString:string];
        }
    }
}


-(void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError{
    NSLog(@"%@", [parseError localizedDescription]);
}

/*
-(void)tapDetected {
    NSLog(@"single Tap on imageview");
    
    
    if (currentPage == totalPage) {
       [self showHideArrow:self.leftArrow];
    }
    else if (currentPage == 1) {
        [self showHideArrow:self.rightArrow];
    }
    else
    {
        [self showHideArrow:self.leftArrow];
        [self showHideArrow:self.rightArrow];
    }
}
 */
/*
-(void)showHideArrow:(UIButton *) button {
    //to Show
    [UIView animateWithDuration:0.5
                          delay:1.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         button.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Done!");
                     }];
    
    //to Hide
    [UIView animateWithDuration:0.5
                          delay:1.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         button.alpha = 0.0;
                     }
                     completion:^(BOOL finished){
                         NSLog(@"Done!");
                     }];
}
*/

#pragma mark - UISwipeGestureRecognizer

- (void)handleSwipe:(UISwipeGestureRecognizer *)swipe {
    
    [self initButtons];
    
    [self.playButton setEnabled:NO];
    [self.playButton setAlpha:0.0];
    
    [self.leftArrow setHidden:NO];
    [self.rightArrow setHidden:NO];
    
    self.leftArrow.alpha = 1.0;
    self.rightArrow.alpha = 1.0;
    //direction <--
    
    if (swipe.direction == UISwipeGestureRecognizerDirectionLeft) {
        NSLog(@"Left Swipe");
        
        if (currentPage == totalPage) {
         //  [self showHideArrow:self.rightArrow];
            [self.rightArrow setHidden:YES];
        }
        else {
            
            if (currentPage == totalPage - 1) {
                [self.rightArrow setHidden:YES];
            }
            else {
            
 //            [self showHideArrow:self.leftArrow];
 //            [self showHideArrow:self.rightArrow];
            }
            
            currentPage = currentPage + 1;
            [self makePageNumber];
            [self makeImageView];
            [self makeLabel:@"English"];
        }
    }
    
    // direction -->
    
    if (swipe.direction == UISwipeGestureRecognizerDirectionRight) {
        NSLog(@"Right Swipe");
        
        
        if (currentPage == 1) {
            
            [self.leftArrow setHidden:YES];
        }
        else {
            
            if (currentPage == 2) {
                [self.leftArrow setHidden:YES];
            }
            else {
//                [self showHideArrow:self.leftArrow];
//                [self showHideArrow:self.rightArrow];
            }
                currentPage = currentPage - 1;
                [self makePageNumber];
                [self makeImageView];
                [self makeLabel:@"English"];
            
        }
    }
}


#pragma mark - Arrow Pressed

- (IBAction)rightButtonPressed:(UIButton *)sender {
    
}

- (IBAction)leftButtonPressed:(UIButton *)sender {
}



#pragma mark - Translate

- (IBAction)transButtonPressed:(UIButton *)sender {
    
    if (transStatus == ENGLISH) {
        [self makeLabel:@"Korean"];
        [self.transButton setImage:[UIImage imageNamed:@"translation_on"] forState:UIControlStateNormal];
        transStatus = KOREAN;
    }
    else if (transStatus == KOREAN) {
        [self makeLabel:@"English"];
        [self.transButton setImage:[UIImage imageNamed:@"translation_off"] forState:UIControlStateNormal];
        transStatus = ENGLISH;
    }
}

#pragma mark - Speaker

- (IBAction)speakButtonPressed:(UIButton *)sender {
    
    if (!speechPlaying)
    {
        NSLog(@"#speakButtonPressed");
        [self initButtons];
        [self makeLabel:@"English"];
        
               [synthesizer setDelegate:self];
        
        
        float speechSpeed = DEFAULT_SPEED;
        synUtt = [[AVSpeechUtterance alloc] initWithString:self.label.text];
        [synUtt setRate:speechSpeed];
        [synUtt setVolume:1.0];
        [synUtt setVoice:[AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"]];
        
        [synthesizer speakUtterance:synUtt];
    }
}


#pragma mark - AVSpeechSynthesizerDelegate

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
willSpeakRangeOfSpeechString:(NSRange)characterRange
                utterance:(AVSpeechUtterance *)utterance
{
    NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:utterance.speechString];
    [mutableAttributedString addAttribute:NSForegroundColorAttributeName
                                    value:[UIColor redColor] range:characterRange];
    self.label.attributedText = mutableAttributedString;
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
  didStartSpeechUtterance:(nonnull AVSpeechUtterance *)utterance
{
    [self.speakButton setImage:[UIImage imageNamed:@"speaker_on"] forState:UIControlStateNormal];
    speechPlaying = PLAY;
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
 didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
    self.label.attributedText = [[NSAttributedString alloc] initWithString:self.utteranceString];
    [self.speakButton setImage:[UIImage imageNamed:@"speaker_off"] forState:UIControlStateNormal];
    speechPlaying = STOP;
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
 didPauseSpeechUtterance:(nonnull AVSpeechUtterance *)utterance
{
    speechPlaying = STOP;
}



@end
