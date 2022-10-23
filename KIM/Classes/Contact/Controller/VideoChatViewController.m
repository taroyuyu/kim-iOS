//
//  VideoChatViewController.m
//  HUTLife
//
//  Created by Kakawater on 2018/5/2.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "VideoChatViewController.h"
#import <WebRTC/RTCCameraPreviewView.h>
#import <WebRTC/RTCEAGLVideoView.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCCameraVideoCapturer.h>
#import <WebRTC/RTCFileVideoCapturer.h>
#import <WebRTC/RTCDispatcher.h>
#import <WebRTC/RTCAudioSession.h>
#import "KIMVoiceSession.h"
#import "KIMVideoSession.h"
#import <AVFoundation/AVFoundation.h>
typedef NS_ENUM(NSUInteger,VideoChatViewControllerMode)
{
    VideoChatViewControllerMode_Calling,//正在呼叫
    VideoChatViewControllerMode_Ring,//正在响铃，即等待当前用户接收来自对方的呼叫
    VideoChatViewControllerMode_Talking,//正在通话
};

@interface VideoChatViewController ()<RTCVideoViewDelegate,KIMMediaSessionDelegate,KIMVideoSessionDelegate>
@property (weak, nonatomic) IBOutlet RTCEAGLVideoView *remoteView;
@property (strong, nonatomic) RTCVideoTrack *remoteVideoTrack;
@property (weak, nonatomic) IBOutlet RTCEAGLVideoView *localView;
@property (strong, nonatomic) RTCVideoTrack *localVideoTrack;
@property(nonatomic,strong)RTCCameraVideoCapturer * localVideoCapturer;
@property(nonatomic,strong)RTCFileVideoCapturer * localFileVideoCapturer;
@property(nonatomic,assign)AVCaptureDevicePosition localCameraPostion;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *localViewMarginLeft;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *localViewMarginTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *localViewMarginRight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *localViewMarginBottom;
@property (weak, nonatomic) IBOutlet UILabel *callTypeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *peerAvatar;
@property (weak, nonatomic) IBOutlet UILabel *peerNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *conversationTimeLabel;
@property (nonatomic,strong)NSDate * conversationBeginDate;
@property (nonatomic,strong)NSTimer * conversationTimer;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UILabel *cancelBtnLabel;
@property (weak, nonatomic) IBOutlet UIButton *acceptButton;
@property (weak, nonatomic) IBOutlet UILabel *acceptBtnLabel;
@property(nonatomic,assign)VideoChatViewControllerMode mode;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancleButtonMarginLeft;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *acceptButtonMarginRight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancelButtonMarginBottom;
@property(nonatomic,strong)KIMVideoChatRequest * proccessingRequest;
@property(nonatomic,strong)KIMMediaSession * processingMediaSession;
@end

@implementation VideoChatViewController
+(instancetype)callToFriend:(KIMUser*)peerUser sessionType:(KIMVideoChatRequestSessionType)sessionType;
{
    VideoChatViewController * viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"videoChatViewController"];
    [viewController setPeerUser:peerUser];
    [viewController setSessionType:sessionType];
    [viewController setMode:VideoChatViewControllerMode_Calling];
    return viewController;
}

+(instancetype)ringFrom:(KIMVideoChatRequest*)videoChatRequest
{
    VideoChatViewController * viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"videoChatViewController"];
    [viewController setPeerUser:videoChatRequest.sponsor];
    [viewController setSessionType:videoChatRequest.sessionType];
    [viewController setProccessingRequest:videoChatRequest];
    [viewController setMode:VideoChatViewControllerMode_Ring];
    return viewController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //默认为前置摄像头
    [self setLocalCameraPostion:AVCaptureDevicePositionFront];
    
    [[[self peerAvatar] layer] setCornerRadius:self.peerAvatar.bounds.size.width/2];
    [[self peerAvatar] setClipsToBounds:YES];
    
    
    switch (self.sessionType) {
        case KIMVideoChatRequestSessionType_Voice:
        {
            [self.callTypeLabel setText:@"语音通话"];
        }
            break;
        case KIMVideoChatRequestSessionType_Video:
        {
            [self.callTypeLabel setText:@"视频通话"];
        }
            break;
        default:{
            [self.callTypeLabel setText:@"未知类型的通话"];
        }
            break;
    }
    
    [self.peerNameLabel setText:self.peerUser.account];
    
    KIMRosterModule * rosterModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] rosterModule];
    
    KIMUserVCard * peerUserVCard = [rosterModule retriveUserVCardFromLocalCache:self.peerUser];
    
    if (peerUserVCard) {
        if (peerUserVCard.avatar) {
            [[self peerAvatar] setImage:[UIImage imageWithData:peerUserVCard.avatar]];
        }
        if ([[peerUserVCard nickName] length]) {
            [self.peerNameLabel setText:peerUserVCard.nickName];
        }
    }else{
    }
    
    switch (self.mode) {
        case VideoChatViewControllerMode_Calling:
        {
            [self adjustToCallingMode];
        }
            break;
        case VideoChatViewControllerMode_Ring:
        {
            [self adjustToRingMode];
        }
            break;
        default:
            break;
    }
    
    //    [[self remoteView] setDelegate:self];
    
//    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
//
//    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
//
//                            sizeof(sessionCategory),
//
//                            &sessionCategory);
//
//
//
//    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
//
//    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute,
//
//                             sizeof (audioRouteOverride),
//
//                             &audioRouteOverride);
    
    
#if !TARGET_OS_MACCATALYST
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    //默认情况下扬声器播放
    
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    [audioSession setActive:YES error:nil];
    
    UInt32 audioRouteOverride = kAudioSessionProperty_OverrideCategoryDefaultToSpeaker;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute,sizeof(audioRouteOverride),&audioRouteOverride);
#else
#endif
}

#pragma mark 通话配置
-(void)adjustToCallingMode
{
    //1.隐藏acceptButton和acceptBtnLabel
    [[self acceptButton] setHidden:YES];
    [[self acceptBtnLabel] setHidden:YES];
    //2.隐藏通话时间Label
    [self.conversationTimeLabel setHidden:YES];
    //3.调整cancleButton的位置为居中
    self.cancleButtonMarginLeft.constant = self.cancleButtonMarginLeft.constant + (self.view.center.x - self.cancelButton.center.x);
    //4.隐藏RmoteView和LocalView
    
    switch (self.sessionType) {
        case KIMVideoChatRequestSessionType_Video:
        {
            [[self remoteView] setHidden:NO];
            [[self localView] setHidden:NO];
            //3.1添加添加本地视频源
        }
            break;
        case KIMVideoChatRequestSessionType_Voice:
        {
            [[self remoteView] setHidden:YES];
            [[self localView] setHidden:NO];
        }
            break;
        default:
            break;
    }
}
-(void)adjustToRingMode
{
    //1.隐藏通话时间Label
    [self.conversationTimeLabel setHidden:YES];
}

-(void)adjustToTakingMode
{
    //1.隐藏peerAvatar、peerNameLabel和callTypeLabel
    [self.peerAvatar setHidden:YES];
    [self.peerNameLabel setHidden:YES];
    [self.callTypeLabel setHidden:YES];
    
    //2.显示通话时间Label
    [[self conversationTimeLabel] setText:@"00:00"];
    [self.conversationTimeLabel setHidden:NO];
    [self setConversationBeginDate:[NSDate date]];
    //启动定时器，用于更新此会话时间
    [self.conversationTimer invalidate];
    __weak VideoChatViewController * weakSelf = self;
    self.conversationTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSUInteger time = [[NSDate date] timeIntervalSinceDate:weakSelf.conversationBeginDate];
        NSInteger hours = time/3600;
        NSInteger minutes = (time / 60) % 60;
        NSInteger seconds = time % 60;
        [weakSelf.conversationTimeLabel setText:[NSString stringWithFormat:@"%02li:%02li:%02li",hours,minutes,seconds]];
    }];
    switch (self.mode) {
        case VideoChatViewControllerMode_Calling:
        {
            self.cancelButtonMarginBottom.constant = -(self.cancelButton.bounds.size.height);
            [self.cancelButton setNeedsUpdateConstraints];
            [UIView animateWithDuration:0.5 animations:^{
                [self.cancelButton.superview layoutIfNeeded];
            }];
        }
            break;
        case VideoChatViewControllerMode_Ring:
        {
            self.cancleButtonMarginLeft.constant = -(self.cancelButton.bounds.size.width);
            self.acceptButtonMarginRight.constant = - (self.acceptButton.bounds.size.width);
            [self.cancelButton setNeedsUpdateConstraints];
            [self.acceptButton setNeedsUpdateConstraints];
            [UIView animateWithDuration:0.5 animations:^{
                [self.acceptButton.superview layoutIfNeeded];
                [self.cancelButton.superview layoutIfNeeded];
            }];
        }
            break;
        default:
            break;
    }
    
    //为屏幕添加Tap手势
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleButtonContainer)];
    [tapGestureRecognizer setNumberOfTapsRequired:1];
    [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)toggleButtonContainer {
    [UIView animateWithDuration:0.3f animations:^{
        self.cancleButtonMarginLeft.constant = self.cancleButtonMarginLeft.constant + (self.view.center.x - self.cancelButton.center.x);
        
        if (self.cancelButtonMarginBottom.constant <= 0.0f) {//当前cancelButton已经隐藏
            self.cancelButtonMarginBottom.constant = 120.0f;
            self.cancelButton.alpha = 1.0f;
        }else{//当前cancnelButton已经显示
            self.cancelButtonMarginBottom.constant = -(self.cancelButton.bounds.size.height);
            self.cancelButton.alpha = 0.0f;
        }
        [self.view layoutIfNeeded];
    }];
}

-(void)switchToRingState
{
    [[self acceptButton] setHidden:NO];
}

- (void)videoView:(RTCEAGLVideoView*)videoView didChangeVideoSize:(CGSize)size
{
    
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[self navigationController] setNavigationBarHidden:YES animated:YES];
    
    [self setLocalVideoTrack:nil];
    [self setRemoteVideoTrack:nil];
    
    if (VideoChatViewControllerMode_Calling == self.mode){
        //2.发送视频会话请求
        KIMClient * imClient = [(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient];
        self.proccessingRequest = [[KIMVideoChatRequest alloc]initWithSponsor:imClient.currentUser target:self.peerUser andSessionType:self.sessionType];
        [imClient.videoChatModule sendRequest:self.proccessingRequest withDelegate:self completion:^(KIMVideoChatModule *videoChatModule, KIMVideoChatRequest *request, NSError *error, KIMVideoChatRequestReply *reply,KIMMediaSession * mediaSession) {
            if (error) {
                [self dismissViewControllerAnimated:YES completion:^{
                    
                }];
                return;
            }
            
            switch (reply.reply) {
                case KIMVideoChatRequestReplyType_Accept:
                {
                    NSLog(@"%s 对方接收此视频通话邀请",__FUNCTION__);
                    self.processingMediaSession = mediaSession;
                }
                    break;
                case KIMVideoChatRequestReplyType_Reject:
                {
                    [self dismissViewControllerAnimated:YES completion:^{
                        
                    }];
                    NSLog(@"%s 对方拒绝了此视频通话邀请",__FUNCTION__);
                }
                    break;
                case KIMVideoChatRequestReplyType_NoAnser:
                {
                    [self dismissViewControllerAnimated:YES completion:^{
                        
                    }];
                    NSLog(@"%s 暂时无人接听",__FUNCTION__);
                }
                    break;
            }
        }];
    }
}

- (IBAction)cancleButtonClicked:(UIButton*)button {
    
    KIMVideoChatModule * videoChatModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] videoChatModule];
    switch (self.mode) {
        case VideoChatViewControllerMode_Calling:
        {
            if (self.proccessingRequest) {
                [videoChatModule cancelRequest:self.proccessingRequest];
            }
        }
            break;
        case VideoChatViewControllerMode_Ring:
        {
            if (self.proccessingRequest) {
                [videoChatModule rejectRequest:self.proccessingRequest];
            }
        }
            break;
        case VideoChatViewControllerMode_Talking:
        {
            if (self.processingMediaSession) {
                [self.processingMediaSession hangup];
            }
            [self dismissViewControllerAnimated:YES completion:nil];
        }
            break;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
    [self setProccessingRequest:nil];
}
- (IBAction)acceptButtonClicked:(UIButton *)sender {
    if (VideoChatViewControllerMode_Ring == self.mode) {
        KIMVideoChatModule * videoChatModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] videoChatModule];
        self.processingMediaSession = [videoChatModule acceptRequest:self.proccessingRequest withDelegate:self];
    }
}

-(void)videoSessionDidCreateLocalVideoCapture:(RTCCameraVideoCapturer *)localVideoCapturer
{
    self.localVideoCapturer = localVideoCapturer;
    //配置会话
    //1.选择前置\后置摄像头
    AVCaptureDevice *cameraDevice = [self findDeviceForPosition:self.localCameraPostion];
    //2选择分辨率
    AVCaptureDeviceFormat *videoFormat = [self selectFormatForDevice:cameraDevice];
    NSInteger fps = [self selectFpsForFormat:videoFormat];
    
    //2.3.3启动视频捕捉器
    [self.localVideoCapturer startCaptureWithDevice:cameraDevice format:videoFormat fps:fps];
}

- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position {
    
    if (position == AVCaptureDevicePositionUnspecified) {
        return nil;
    }
    
    NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
    for (AVCaptureDevice *device in captureDevices) {
        if (device.position == position) {
            return device;
        }
    }
    return [captureDevices firstObject];
}

- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device {
    
    if (!device) {
        return nil;
    }
    
    NSArray<AVCaptureDeviceFormat *> *formats =
    [RTCCameraVideoCapturer supportedFormatsForDevice:device];
    int targetWidth = 640;
    int targetHeight = 480;
    AVCaptureDeviceFormat *selectedFormat = nil;
    int currentDiff = INT_MAX;
    
    for (AVCaptureDeviceFormat *format in formats) {
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
        if (diff < currentDiff) {
            selectedFormat = format;
            currentDiff = diff;
        } else if (diff == currentDiff && pixelFormat == [self.localVideoCapturer preferredOutputPixelFormat]) {
            selectedFormat = format;
        }
    }
    return selectedFormat;
}

- (NSInteger)selectFpsForFormat:(AVCaptureDeviceFormat *)format {
    Float64 maxFramerate = 0;
    for (AVFrameRateRange *fpsRange in format.videoSupportedFrameRateRanges) {
        maxFramerate = fmax(maxFramerate, fpsRange.maxFrameRate);
    }
    return maxFramerate;
}
-(void)videoSessionDidCreateLocalFileCapturer:(RTCFileVideoCapturer*)localFileVideoCapturer
{
    self.localFileVideoCapturer = localFileVideoCapturer;
#if defined(__IPHONE_11_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0)
    if (@available(iOS 10, *)) {
        [self.localFileVideoCapturer startCapturingFromFileNamed:@"goodNight.mp4"
                                                         onError:^(NSError *_Nonnull error) {
                                                             NSLog(@"Error %@", error.userInfo);
                                                         }];
    }
#endif
}



/**
 * 正在进行协商
 */
-(void)mediaSessionStartedNegotiation:(KIMMediaSession *)mediaSession
{
    
}
/**
 * 协商失败
 */
-(void)mediaSessionNegotiationFailed:(KIMMediaSession*)mediaSession
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}
/**
 * 协商成功
 */
-(void)mediaSessionNegotiationSuccess:(KIMMediaSession*)mediaSession
{
    
}
/**
 * 对等连接建立
 */
-(void)mediaSessionConnected:(KIMMediaSession*)mediaSession
{
    [self adjustToTakingMode];
    [self setMode:VideoChatViewControllerMode_Talking];
}

-(void)videoSessionDidReceiveLocalVideoTrack:(RTCVideoTrack*)localVideoTrack
{
    self.localVideoTrack = localVideoTrack;
}
/**
 * 接收到对方的媒体流
 */
-(void)videoSessionDidReceiveRemoteVideoTrack:(RTCVideoTrack*)remoteVideoTrack
{
    self.remoteVideoTrack = remoteVideoTrack;
    
    //1.调整localView的大小
    const CGSize localViewSize = CGSizeMake(120, 120);
    const CGFloat localViewMarginEdge = 20;
    self.localViewMarginLeft.constant = localViewMarginEdge;
    self.localViewMarginRight.constant = self.view.bounds.size.width - (localViewSize.width + localViewMarginEdge);
    self.localViewMarginBottom.constant = localViewMarginEdge;
    self.localViewMarginTop.constant = self.view.bounds.size.height - (localViewSize.height + localViewMarginEdge);
    [self.localView setBackgroundColor:[UIColor clearColor]];
    [self.localView setNeedsUpdateConstraints];
    
    [UIView animateWithDuration:0.5 animations:^{
        [self.localView.superview layoutIfNeeded];
    }];
}

/**
 * 对方移除了媒体流
 */
-(void)videoSessionDidRemovedRemoteVideoTrack:(RTCVideoTrack*)remoteVideoTrack
{
    self.remoteVideoTrack = nil;
}

/**
 * 连接断开
 */
-(void)mediaSessionDisconnected:(KIMMediaSession*)mediaSession
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}
/**
 * 会话结束
 */
-(void)mediaSessionDidHangUp:(KIMMediaSession*)mediaSession
{
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

-(void)setRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack
{
    if(self->_remoteVideoTrack == remoteVideoTrack) {
        return;
    }
    [self->_remoteVideoTrack removeRenderer:self.remoteView];
    self->_remoteVideoTrack = nil;
    [self.remoteView renderFrame:nil];
    self->_remoteVideoTrack = remoteVideoTrack;
    [self->_remoteVideoTrack addRenderer:self.remoteView];
}

-(void)setLocalVideoTrack:(RTCVideoTrack *)localVideoTrack
{
    if (self->_localVideoTrack == localVideoTrack) {
        return;
    }
    [self->_localVideoTrack removeRenderer:self.localView];
    self->_localVideoTrack = nil;
    [self.localView renderFrame:nil];
    self->_localVideoTrack = localVideoTrack;
    [self->_localVideoTrack addRenderer:self.localView];
}

@end
