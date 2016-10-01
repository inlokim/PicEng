//
//  MainViewController.m
//  PictureEnglish
//
//  Created by 김인로 on 2016. 8. 18..
//  Copyright © 2016년 김인로. All rights reserved.
//

#import "MainViewController.h"
#import "FileDownloadInfo.h"
#import "Utils.h"
#import "AppDelegate.h"
#import "SSZipArchive.h"
#import "StoreManager.h"
#import "StoreObserver.h"
#import "MyModel.h"

#define PLAY YES
#define STOP NO
#define DEFAULT_SPEED 0.4

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
    
    SKProductsRequest *productsRequest;
    SKProduct *validProduct;
    SKPayment *payment;
    NSString *appStoreProductId;
    
    
    
    NSString *lessonFile;
    
    BOOL xmlExists;
}

//@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) IBOutlet UIButton *purchaseButton;
@property (strong, nonatomic) IBOutlet UIButton *restoreButton;


@property (strong, nonatomic) IBOutlet UIButton *recordPauseButton;
//@property (strong, nonatomic) IBOutlet UIButton *stopButton;
@property (strong, nonatomic) IBOutlet UIButton *playButton;

@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UILabel *progressLabel;
@property (strong, nonatomic) IBOutlet UILabel *pageNumber;
@property (strong, nonatomic) IBOutlet UIButton *speakButton;
@property (strong, nonatomic) IBOutlet UIButton *transButton;
@property (strong, nonatomic) IBOutlet UIButton *leftArrow;
@property (strong, nonatomic) IBOutlet UIButton *rightArrow;

@property (strong, nonatomic) IBOutlet UIStackView *progressStackView;
@property (strong, nonatomic) IBOutlet UIStackView *purchaseStackView;


@property (strong, nonatomic) IBOutlet UIProgressView *progressView;

@property (readwrite, nonatomic, copy) NSString *utteranceString;
@property (readwrite, nonatomic, copy) NSString *translatedString;


@property (nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic, strong) NSMutableArray *arrNeighboursData;
@property (nonatomic, strong) NSMutableDictionary *dictTempDataStorage;
@property (nonatomic, strong) NSMutableString *foundValue;
@property (nonatomic, strong) NSString *currentElement;


@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableArray *arrFileDownloadData;
@property (nonatomic, strong) NSURL *docDirectoryURL;

@property (nonatomic, strong) NSMutableArray *products;



-(void)initializeFileDownloadDataArray;
-(int)getFileDownloadInfoIndexWithTaskIdentifier:(unsigned long)taskIdentifier;


@end

@implementation MainViewController


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    //Locale
    
    NSLocale *locale = [NSLocale currentLocale];
    NSString *countryCode = [locale objectForKey: NSLocaleCountryCode];
    
    NSLog(@"countryCode : %@",countryCode);
    
    if ([countryCode isEqualToString:@"KR"]) [self.transButton setHidden:NO];
    else [self.transButton setHidden:YES];
    
    lessonFile = @"lesson1";
    
    //Download
    
    
    self.progressLabel.text=@"";
    self.progressView.progress = 0.0;
    
    [self initializeFileDownloadDataArray];
    
    NSArray *URLs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    self.docDirectoryURL = [URLs objectAtIndex:0];
    
    NSLog(@"docDirectoryURL : %@",[self.docDirectoryURL path] );
    
    
    NSURLSessionConfiguration *sessionConfiguration
        = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"kr.co.highwill.PictureEnglish"];
    sessionConfiguration.HTTPMaximumConnectionsPerHost = 5;
    
    
    self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                 delegate:self
                                            delegateQueue:nil];

    
    
    //Speech
    
    synthesizer = [[AVSpeechSynthesizer alloc] init];

    [self.progressStackView setHidden:YES];


    transStatus = ENGLISH;

    
    
    /**********  
      XML
    ***********/
    
    [self XMLSetup];
    [self pageNumberSetup];
    
    
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
    [self.playButton setHidden:YES];
    
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
    
    
    //Purchse Display
    
    if (xmlExists == true) [self.purchaseStackView setHidden:YES];
    else
    {
        if (currentPage == totalPage)[self.purchaseStackView setHidden:NO];
        else [self.purchaseStackView setHidden:YES];
    }
    
    self.products = [[NSMutableArray alloc] initWithCapacity:0];

    //[[SKPaymentQueue defaultQueue] addTransactionObserver: self];
    
    //appStoreProductId =  @"PicEng_lesson1";
    
    
    //self.activityIndicator.hidden = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleProductRequestNotification:)
                                                 name:IAPProductRequestNotification
                                               object:[StoreManager sharedInstance]];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handlePurchasesNotification:)
                                                 name:IAPPurchaseNotification
                                               object:[StoreObserver sharedInstance]];
    
    
    // Fetch information about our products from the App Store
    [self fetchProductInformation];
    
}

#pragma mark - ViewDisplay

- (void)XMLSetup
{
    xmlExists = false;
    
    NSString *xmlFile = [NSString stringWithFormat:@"%@/out/%@",[Utils homeDir], @"lesson1.xml" ];
    NSString *path;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:xmlFile])
    {
        path = xmlFile;
        xmlExists = true;
    }
    else {
        //use Sample file
        path = [[NSBundle mainBundle] pathForResource:@"sample" ofType:@"xml"];
    }
    
    self.xmlParser = [[NSXMLParser alloc] initWithData:[NSData dataWithContentsOfFile:path]];
    self.foundValue = [[NSMutableString alloc] init];
    self.xmlParser.delegate = self;
    [self.xmlParser parse];
}


- (void)pageNumberSetup
{
    //persistence data
    currentPage = [self pPageNumber];
    totalPage = [self.arrNeighboursData count] ;
    
    //Arrow
    
    // self.leftArrow.alpha = 0.0;
    // self.rightArrow.alpha = 0.0;
    
    if (currentPage > totalPage) currentPage = totalPage;
    
    NSLog(@"current Page : %lu, totalPage : %lu", currentPage, (unsigned long)totalPage);
    
    if (currentPage == 1) {
        [self.leftArrow setHidden:YES];
    }
    else if (currentPage == totalPage) {
        [self.rightArrow setHidden:YES];
        
        if (xmlExists == true) [self.purchaseStackView setHidden:YES];
        else  [self.purchaseStackView setHidden:NO];
    }
    else
    {
        [self.purchaseStackView setHidden:YES];
    }
    
    //pageNumber
    
    [self makePageNumber];
}

#pragma mark - Display message

-(void)alertWithTitle:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}



#pragma mark Fetch product information

// Retrieve product information from the App Store
-(void)fetchProductInformation
{
    // Query the App Store for product information if the user is is allowed to make purchases.
    // Display an alert, otherwise.
    if([SKPaymentQueue canMakePayments])
    {
        // Load the product identifiers fron ProductIds.plist
        NSURL *plistURL = [[NSBundle mainBundle] URLForResource:@"ProductIds" withExtension:@"plist"];
        NSArray *productIds = [NSArray arrayWithContentsOfURL:plistURL];
        
        
        NSLog(@"product Id %@",[productIds objectAtIndex:0]);
        
        [[StoreManager sharedInstance] fetchProductInformationForIds:productIds];
    }
    else
    {
        // Warn the user that they are not allowed to make purchases.
        [self alertWithTitle:@"Warning" message:@"Purchases are disabled on this device."];
    }
}


#pragma mark Handle product request notification

// Update the UI according to the product request notification result
-(void)handleProductRequestNotification:(NSNotification *)notification
{
    
    NSLog(@"handleProductRequestNotification");
    
    
    StoreManager *productRequestNotification = (StoreManager*)notification.object;
    IAPProductRequestStatus result = (IAPProductRequestStatus)productRequestNotification.status;
    
    if (result == IAPProductRequestResponse)
    {
        // Switch to the iOSProductsList view controller and display its view
     //   [self cycleFromViewController:self.currentViewController toViewController:self.productsList];
        
        // Set the data source for the Products view
       // [self.productsList reloadUIWithData:productRequestNotification.productRequestResponse];
       
        self.products = productRequestNotification.productRequestResponse;
        
         NSLog(@"self.products count = %lu", (unsigned long)[self.products count]);
/*
        
        MyModel *model = (self.products)[0];
        NSArray *productRequestResponse = model.elements;
        
        if ([self.products count] > 0)
        {
            SKProduct *aProduct = productRequestResponse[0];
            
            NSString *title = aProduct.localizedTitle;
            
            NSString *price = [NSString stringWithFormat:@"%@ %@",[aProduct.priceLocale objectForKey:NSLocaleCurrencySymbol],aProduct.price];
            
            self.purchaseButton.titleLabel.text = [NSString stringWithFormat:@"%@ %@", title, price];
        }*/
    }
}


#pragma mark Handle purchase request notification

// Update the UI according to the purchase request notification result
-(void)handlePurchasesNotification:(NSNotification *)notification
{
     NSLog(@"handlePurchasesNotification");

    
    StoreObserver *purchasesNotification = (StoreObserver *)notification.object;
    IAPPurchaseNotificationStatus status = (IAPPurchaseNotificationStatus)purchasesNotification.status;
    
    switch (status)
    {
            
        case IAPPurchaseSucceeded:
        {
            NSLog(@"IAPPurchaseSucceeded !!!");
            [self startDownload];
        }
            break;
        case IAPPurchaseFailed:
        {
            [self alertWithTitle:@"Purchase Status" message:purchasesNotification.message];
        }
            break;
            // Switch to the iOSPurchasesList view controller when receiving a successful restore notification
        case IAPRestoredSucceeded:
        {
            
            NSLog(@"IAPRestoredSucceeded");
            
            [self startDownload];

        }
            break;
        case IAPRestoredFailed:
        {
            NSLog(@"IAPRestoredFailed");
            
            [self alertWithTitle:@"Purchase Status" message:purchasesNotification.message];
        }
            break;
            // Notify the user that downloading is about to start when receiving a download started notification
        case IAPDownloadStarted:
        {
            NSLog(@"IAPDownloadStarted");
          //  self.hasDownloadContent = YES;
          //  [self.view addSubview:self.statusMessage];
        }
            break;
            // Display a status message showing the download progress
        case IAPDownloadInProgress:
        {
            NSLog(@"IAPDownloadInProgress");
            
          //  self.hasDownloadContent = YES;
          //  NSString *title = [[StoreManager sharedInstance] titleMatchingProductIdentifier:purchasesNotification.purchasedID];
          //  NSString *displayedTitle = (title.length > 0) ? title : purchasesNotification.purchasedID;
           // self.statusMessage.text = [NSString stringWithFormat:@" Downloading %@   %.2f%%",displayedTitle, purchasesNotification.downloadProgress];
        }
            break;
            // Downloading is done, remove the status message
        case IAPDownloadSucceeded:
        {
            NSLog(@"IAPDownloadSucceeded");
            
            
          //  self.hasDownloadContent = NO;
          //  self.statusMessage.text = @"Download complete: 100%";
            
            // Remove the message after 2 seconds
            //[self performSelector:@selector(hideStatusMessage) withObject:nil afterDelay:2];
        }
            break;
        default:
            break;
    }
}




- (void)dealloc
{

    // Unregister for StoreManager's notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IAPProductRequestNotification
                                                  object:[StoreManager sharedInstance]];
    
    // Unregister for StoreObserver's notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IAPPurchaseNotification
                                                  object:[StoreObserver sharedInstance]];}



#pragma mark - Download

-(void)initializeFileDownloadDataArray {
    self.arrFileDownloadData = [[NSMutableArray alloc] init];
    
    [self.arrFileDownloadData addObject:[[FileDownloadInfo alloc] initWithFileTitle:lessonFile andDownloadSource:@"http://inlokim.com/textAudioBooks/PicEnglish/lesson1.zip"]];
}

-(int)getFileDownloadInfoIndexWithTaskIdentifier:(unsigned long)taskIdentifier{
    int index = 0;
    for (int i=0; i<[self.arrFileDownloadData count]; i++) {
        FileDownloadInfo *fdi = [self.arrFileDownloadData objectAtIndex:i];
        if (fdi.taskIdentifier == taskIdentifier) {
            index = i;
            break;
        }
    }
    
    return index;
}

- (void) startDownload {
    
    [self.purchaseStackView setHidden:YES];
    [self.progressStackView setHidden:NO];
    
    
    // Access all FileDownloadInfo objects using a loop.
    for (int i=0; i<[self.arrFileDownloadData count]; i++) {
        FileDownloadInfo *fdi = [self.arrFileDownloadData objectAtIndex:i];
        
        // Check if a file is already being downloaded or not.
        if (!fdi.isDownloading) {
            // Check if should create a new download task using a URL, or using resume data.
            if (fdi.taskIdentifier == -1) {
                fdi.downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:fdi.downloadSource]];
            }
            else{
                fdi.downloadTask = [self.session downloadTaskWithResumeData:fdi.taskResumeData];
            }
            
            // Keep the new taskIdentifier.
            fdi.taskIdentifier = fdi.downloadTask.taskIdentifier;
            
            // Start the download.
            [fdi.downloadTask resume];
            
            // Indicate for each file that is being downloaded.
            fdi.isDownloading = YES;
        }
    }
}

#pragma mark - NSURLSession Delegate method implementation

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *destinationFilename = downloadTask.originalRequest.URL.lastPathComponent;
    NSURL *destinationURL = [self.docDirectoryURL URLByAppendingPathComponent:destinationFilename];
    
    if ([fileManager fileExistsAtPath:[destinationURL path]]) {
        [fileManager removeItemAtURL:destinationURL error:nil];
    }
    
    BOOL success = [fileManager copyItemAtURL:location
                                        toURL:destinationURL
                                        error:&error];
    
    if (success) {
        // Change the flag values of the respective FileDownloadInfo object.
        int index = [self getFileDownloadInfoIndexWithTaskIdentifier:downloadTask.taskIdentifier];
        FileDownloadInfo *fdi = [self.arrFileDownloadData objectAtIndex:index];
        
        fdi.isDownloading = NO;
        fdi.downloadComplete = YES;
        
        // Set the initial value to the taskIdentifier property of the fdi object,
        // so when the start button gets tapped again to start over the file download.
        fdi.taskIdentifier = -1;
        
        // In case there is any resume data stored in the fdi object, just make it nil.
        fdi.taskResumeData = nil;
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // Reload the respective table view row using the main thread.
            //  [self.tblFiles reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
            //                       withRowAnimation:UITableViewRowAnimationNone];
            
        }];
        
    }
    else{
        NSLog(@"Unable to copy temp file. Error: %@", [error localizedDescription]);
    }
}


-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error != nil) {
        NSLog(@"Download completed with error: %@", [error localizedDescription]);
    }
    else{
        [self unZipping];
        [self deleteFile];
        NSLog(@"Download finished successfully.");

            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self viewDidLoad];
                [self viewWillAppear:YES];
                [self.rightArrow setHidden:NO];
            });

        //[self.view setNeedsDisplay];
    }
}


- (void)unZipping {
    
    NSString *filePath = [NSString stringWithFormat:@"%@/%@.zip",[Utils homeDir],lessonFile];
    NSString *zipPath = filePath;
    
    [SSZipArchive unzipFileAtPath:zipPath toDestination:[Utils homeDir]];
}

- (void)deleteFile {

    NSLog(@"Delete Zip Files");

    NSString *zipFile = [NSString stringWithFormat:@"%@/%@.zip",[Utils homeDir],lessonFile];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:zipFile error:NULL];
}


-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    
    if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown) {
        NSLog(@"Unknown transfer size");
    }
    else{
        // Locate the FileDownloadInfo object among all based on the taskIdentifier property of the task.
        int index = [self getFileDownloadInfoIndexWithTaskIdentifier:downloadTask.taskIdentifier];
        FileDownloadInfo *fdi = [self.arrFileDownloadData objectAtIndex:index];
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // Calculate the progress.
            fdi.downloadProgress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
            
            // Get the progress view of the appropriate cell and update its progress.
            //            UITableViewCell *cell = [self.tblFiles cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
            //            UIProgressView *progressView = (UIProgressView *)[cell viewWithTag:CellProgressBarTagValue];
            self.progressView.progress = fdi.downloadProgress;
            
            double value = (double)totalBytesWritten / (double)totalBytesExpectedToWrite * 100;
            self.progressLabel.text = [NSString stringWithFormat:@"%.1f %%", value];
            
        }];
    }
}


-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    // Check if all download tasks have been finished.
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        
        if ([downloadTasks count] == 0) {
            if (appDelegate.backgroundTransferCompletionHandler != nil) {
                // Copy locally the completion handler.
                void(^completionHandler)() = appDelegate.backgroundTransferCompletionHandler;
                
                // Make nil the backgroundTransferCompletionHandler.
                appDelegate.backgroundTransferCompletionHandler = nil;
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    // Call the completion handler to tell the system that there are no other background transfers.
                    completionHandler();
                    
                    // Show a local notification when all downloads are over.
                    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
                    localNotification.alertBody = @"All files have been downloaded!";
                    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
                }];
            }
        }
    }];
}

#pragma mark - Init View

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
    
    
    if (xmlExists) {
        NSString *fullPath = [NSString stringWithFormat:@"%@/out/%@", [Utils homeDir], imageName];
       self.imageView.image = [UIImage imageWithContentsOfFile:fullPath];
    }
    else {
        self.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png",imageName]];
    }
}

-(void)makePageNumber {
    self.pageNumber.text = [NSString stringWithFormat:@"%lu/%lu",(unsigned long)currentPage,(unsigned long)totalPage];
}



#pragma mark - Persitence Data


-(NSString *)plistFile
{
    NSString *lessonName = @"lesson1";
    
    NSString *homeDir = [Utils homeDir];
    NSString *fileName = [NSString stringWithFormat:@"%@.plist", lessonName];
    
    return [homeDir stringByAppendingPathComponent:fileName];
}

//Persitence Page Number

-(NSUInteger)pPageNumber {
    
    NSString *plistFile = [self plistFile];
    
    NSLog(@"plistFile = %@", plistFile);
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:plistFile]) {
        NSArray *array = [[NSArray alloc] initWithContentsOfFile:plistFile];
        return [[array objectAtIndex:0] intValue];
    }
    else {
        return 1;
    }
}

-(void) savePersistData
{
    NSString *plistFile = [self plistFile];
    NSMutableArray *array = [[NSMutableArray alloc] init];
    [array addObject:[NSString stringWithFormat:@"%lu",(unsigned long)currentPage ]];
    [array writeToFile:plistFile atomically:YES];
}


#pragma mark - Recording


//Mic button

- (IBAction)recordPauseTapped:(id)sender {
    // Stop the audio player before recording
    [self.playButton setHidden:YES];
    
    if (player.playing) {
        [player stop];
    }
    
    if (!recorder.recording) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        
        // Start recording
        [recorder record];
        [self.recordPauseButton setImage:[UIImage imageNamed:@"mic_on"] forState:UIControlStateNormal];
        [self.playButton setHidden:YES];
    }
    else {
        // Pause recording
        [recorder stop];
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];
        [self.recordPauseButton setImage:[UIImage imageNamed:@"mic_off"] forState:UIControlStateNormal];
        [self.playButton setHidden:NO];
    }
    
    // [self.stopButton setEnabled:YES];
    
}

- (void) audioRecorderDidFinishRecording:(AVAudioRecorder *)avrecorder successfully:(BOOL)flag{
    [self.recordPauseButton setTitle:@"Record" forState:UIControlStateNormal];
    // [self.stopButton setEnabled:NO];
    [self.playButton setHidden:NO];
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
        
       // NSLog(@"Korean : %@", [NSString stringWithString:self.foundValue]);
        
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
    
     // direction <--
    
    if (swipe.direction == UISwipeGestureRecognizerDirectionLeft) {
        NSLog(@"Left Swipe");

            if (totalPage > currentPage) currentPage = currentPage + 1;
            [self paging:@"English"];
    }
    
    // direction -->
    
    if (swipe.direction == UISwipeGestureRecognizerDirectionRight) {
        NSLog(@"Right Swipe");

                if (currentPage > 1) currentPage = currentPage - 1;
                [self paging:@"English"];
            
       // }
    }
}


#pragma mark - Arrow Pressed

- (IBAction)rightButtonPressed:(UIButton *)sender {
    currentPage = currentPage + 1;
    [self paging:@"English"];
}

- (IBAction)leftButtonPressed:(UIButton *)sender {
    currentPage = currentPage - 1;
    [self paging:@"English"];
}

-(void)paging:(NSString *)language {
    
    [self initButtons];
    
    NSLog(@"XML Exist : %d", xmlExists);
    
    if (currentPage == 1) {
        [self.leftArrow setHidden:YES];
    }
    else if (currentPage == totalPage) {
        
        if (xmlExists == true) [self.purchaseStackView setHidden:YES];
        else  [self.purchaseStackView setHidden:NO];
        
        [self.rightArrow setHidden:YES];
    }
    else {
        [self.rightArrow setHidden:NO];
        [self.leftArrow setHidden:NO];
        
        [self.purchaseStackView setHidden:YES];
    }
    
    [self.playButton setHidden:YES];
    
    [self makePageNumber];
    [self makeImageView];
    [self makeLabel:language];
    
    [self savePersistData];
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



#pragma mark - Purchase

- (IBAction)purchaseButtonPressed:(id)sender {

    MyModel *model = (self.products)[0];
    
    NSLog(@"model %@",model.name);
    
    // Only available products can be bought
    if([model.name isEqualToString:@"AVAILABLE PRODUCTS"])
    {
        NSArray *productRequestResponse = model.elements;
        SKProduct *product = (SKProduct *)productRequestResponse[0];
        // Attempt to purchase the tapped product
        [[StoreObserver sharedInstance] buy:product];
    }
}


- (IBAction)restoreButtonPressed:(id)sender {
    
    MyModel *model = (self.products)[0];
    NSLog(@"model %@",model.name);
    
    // Only available products can be bought
    if([model.name isEqualToString:@"AVAILABLE PRODUCTS"])
    {
        [[StoreObserver sharedInstance] restore];
    }
    
}

@end
