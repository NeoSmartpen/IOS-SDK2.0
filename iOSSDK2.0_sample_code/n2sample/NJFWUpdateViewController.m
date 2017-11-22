//
//  NJFWUpdateViewController.m
//  n2sample
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJFWUpdateViewController.h"
#import "NJAppDelegate.h"
#import <NISDK/NISDK.h>

NSString *kURL_NEOLAB_FW20 =         @"http://one.neolab.kr/resource/fw20";
NSString *kURL_NEOLAB_ALL_JSON =     @"/firmware_all.json";

@interface NJFWUpdateViewController () <UIAlertViewDelegate, NJFWUpdateDelegate, NSURLSessionDataDelegate, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSString *penFWVersion;
@property (nonatomic) int counter;

@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSString *fwVerServer;
@property (nonatomic, strong) NSString *fwLoc;


@property (nonatomic, strong) NSMutableData *dataToDownload;
@property (nonatomic) float downloadSize;

@end

@implementation NJFWUpdateViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initVC];
    [self updatePenFWVerision];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self requestPage];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    
    [super viewWillDisappear:animated];
    
    [self cancelTask];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)initVC
{
    _penFWVersion = nil;
    _progressView.alpha = 0.0f;
    _progressViewLabel.text = @"";
    [self animateProgressView:YES withString:@""];
    _progressBar.progress = 0.0f;
    [[NJPenCommManager sharedInstance] setFWUpdateDelegate:self];
}

- (void)updatePenFWVerision
{
    
    NSString *internalFWVersion = [[NJPenCommManager sharedInstance] getFWVersion];
    NSArray * array = [internalFWVersion componentsSeparatedByString:@"."];
    _penFWVersion = [NSString stringWithFormat:@"%@.%@", array[0], array[1]];
    
    self.penVersionLabel.text = [NSString stringWithFormat:@"Current Version :   v.%@",_penFWVersion];

}

- (void)cancelTask
{
    [NJPenCommManager sharedInstance].cancelFWUpdate = YES;
    
    _progressBar.progress = 0.0f;

}

- (void)fwUpdateDataReceiveStatus:(FW_UPDATE_DATA_STATUS)status percent:(float)percent
{
    if(status == FW_UPDATE_DATA_RECEIVE_END) {

        [_indicator stopAnimating];
        [self animateProgressView:YES withString:nil];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Firmware Update"
                                                        message:@"Firmware Update has been completed successfully!"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        
        [alert show];
        
    } else if(status == FW_UPDATE_DATA_RECEIVE_FAIL) {
        
        [self animateProgressView:YES withString:@""];
        [self cancelTask];
        [_indicator stopAnimating];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Firmware Update"
                                                        message:@"Firmware Update has been failed! Please try it again."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        
        [alert show];
        
    } else {
        _progressBar.progress = (percent/100.0f);
        
        _progressViewLabel.text = [NSString stringWithFormat:@"Updating pen firmware (%.2f%%)",percent];
    }
}


-(void)animateProgressView:(BOOL)hide withString:(NSString *)message
{
    if(!hide) {
        _progressViewLabel.text = message;
        
    }
    
    [UIView animateWithDuration:0.3f
                          delay:(0.1f)
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         
                         if(!hide)
                             _progressView.alpha = 1.0f;
                         else
                             _progressView.alpha = 0.0f;
                         
                     }
                     completion:^(BOOL finished) {
                         
                         
                     }
     ];
}

-(void) startFirmwareUpdate
{
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
    
    if(isEmpty(_fwLoc)) return;
    
    NSString *urlStr;
    
    urlStr = [NSString stringWithFormat:@"%@%@",kURL_NEOLAB_FW20,_fwLoc];
    
    NSURL *url = [NSURL URLWithString:urlStr];

    NSURLSessionDataTask *dataTask = [defaultSession dataTaskWithURL: url];
    
    [dataTask resume];
    
    _progressBar.progress = 0.0f;
    
    [self animateProgressView:NO withString:@"Downloading from the server..."];
    [_indicator startAnimating];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    completionHandler(NSURLSessionResponseAllow);
    
    _progressBar.progress=0.0f;
    _downloadSize=[response expectedContentLength];
    _dataToDownload=[[NSMutableData alloc]init];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [_dataToDownload appendData:data];
    _progressBar.progress=[_dataToDownload length ]/_downloadSize;
    
    if (_progressBar.progress == 1.0f) {
        
        [_indicator stopAnimating];
        
        NSURL *documentsDirectoryPath = [NSURL fileURLWithPath:NSTemporaryDirectory()];
        NSURL *fileURL = [documentsDirectoryPath URLByAppendingPathComponent:@"NEO1.zip"];
        NSString *filePath = [fileURL path];
        
        [_dataToDownload writeToFile:filePath options:NSDataWritingAtomic error:nil];
        
        [[NJPenCommManager sharedInstance] sendUpdateFileInfoAtUrlToPen:fileURL];
        
        [self animateProgressView:NO withString:@"Start updating pen firmware..."];
        [_indicator startAnimating];
        
    }
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error{
    //download 100% complete
    if(error != nil){
        NSLog(@"error %@", error);
        if (error.code == -1009) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                            message:@"There is a problem with a network connection."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            
            [alert show];
            
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                            message:@"Error occurs. Please try it again."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            
            [alert show];
        }
        [self animateProgressView:YES withString:nil];
        [_indicator stopAnimating];
    }
}

-(void) requestPage{
    _responseData = [NSMutableData data];
    
    NSString *url;

    url = [NSString stringWithFormat:@"%@%@",kURL_NEOLAB_FW20,kURL_NEOLAB_ALL_JSON];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:
                             [NSURL URLWithString:url]];
    _connection =[[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    [self animateProgressView:NO withString:@"Checking firmware version from the server..."];
    [_indicator startAnimating];
}
#pragma mark
#pragma mark -- NSURLConnection Delegate Mehods
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"didReceiveResponse");
    [_responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"didFailWithError");
    NSLog(@"error %@", error);
    if (error.code == -1009) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:@"There is a problem with a network connection."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        
        [alert show];
        
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:@"Error occurs. Please try it again."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        
        [alert show];
    }
    [self animateProgressView:YES withString:nil];
    [_indicator stopAnimating];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"connectionDidFinishLoading");
    NSError *e = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:_responseData options:NSJSONReadingMutableLeaves error:nil];

    NSDictionary *value; NSString *loc; NSString *ver;
    if ([NJPenCommManager sharedInstance].isPenSDK2){
        NSString *name = [NJPenCommManager sharedInstance].deviceName;
        if ([name isEqualToString:@"NWP-F120"])
            value = [json objectForKey:@"NWP-F120"];
        else if ([name isEqualToString:@"NWP-F121"])
            value = [json objectForKey:@"NWP-F121"];
        else if ([name isEqualToString:@"NWP-F50"])
            value = [json objectForKey:@"NWP-F50"];
        
        loc = [value objectForKey:@"location"];
        ver = [value objectForKey:@"version"];
        
    }else{
        value = [json objectForKey:@"NWP-F110"];

        loc = [value objectForKey:@"location"];
        ver = [value objectForKey:@"version"];
    }
    
    _fwLoc = loc;
    _fwVerServer = ver;
    
    [NJPenCommManager sharedInstance].fwVerServer = _fwVerServer;
    
    if (!json) {
        NSLog(@"Error parsing JSON: %@", e);
    }
    
    if(isEmpty(_penFWVersion) || isEmpty(_fwVerServer)) return;
    
    [self animateProgressView:YES withString:@""];
    [_indicator stopAnimating];
    
    if([_penFWVersion compare:_fwVerServer] == NSOrderedAscending) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Firmware Update"
                                                        message:@"Would you like to update the firmware?"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"OK", nil];
        
        alert.tag = 0;
        [alert show];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                        message:@"Pen Firmware version is up-to-date"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil, nil];

        alert.tag = 1;
        [alert show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    if(alertView.tag == 0) {
        
        if (buttonIndex == [alertView firstOtherButtonIndex]) {
            
            [self startFirmwareUpdate];
            
        } else if (buttonIndex == [alertView cancelButtonIndex]) {
            
            
        }
        
        
    } else if(alertView.tag == 1) {

    }
    
}

@end

