//
//  KIMVideoSession.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/8.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMMediaSession.h"
#import "KIMUser.h"

@protocol KIMVideoSessionDelegate;
@interface KIMVideoSession :KIMMediaSession
@property(nonatomic,weak)NSObject<KIMVideoSessionDelegate> * delegate;
@end

@class RTCCameraVideoCapturer;
@class RTCFileVideoCapturer;
@class RTCVideoTrack;

@protocol KIMVideoSessionDelegate <KIMMediaSessionDelegate>
@optional
/**
 * 视频捕捉器已经创建
 */
-(void)videoSessionDidCreateLocalVideoCapture:(RTCCameraVideoCapturer *)localVideoCapturer;
-(void)videoSessionDidCreateLocalFileCapturer:(RTCFileVideoCapturer*)localFileVideoCapturer;
-(void)videoSessionDidReceiveLocalVideoTrack:(RTCVideoTrack*)localVideoTrack;
-(void)videoSessionDidReceiveRemoteVideoTrack:(RTCVideoTrack*)remoteVideoTrack;
-(void)videoSessionDidRemovedRemoteVideoTrack:(RTCVideoTrack*)remoteVideoTrack;
@end
