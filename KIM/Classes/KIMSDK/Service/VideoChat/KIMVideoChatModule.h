//
//  KIMVideoChatModule.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/3.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebRTC/RTCIceServer.h>
#import "KIMClientService.h"
#import "KIMVideoChatRequest.h"
#import "KIMVideoChatRequestReply.h"
#import "KIMMediaSession.h"

extern NSErrorDomain const KIMVideoChatModuleErrorDomain;

@class KIMVideoChatModule;
@protocol KIMVideoChatModuleDelegate;

typedef void(^KIMVideoChatModuleSendFriendRequestCompletionCallback)(KIMVideoChatModule * videoChatModule,KIMVideoChatRequest * request,NSError * error,KIMVideoChatRequestReply * reply,KIMMediaSession * mediaSession);

@interface KIMVideoChatModule : NSObject<KIMClientService>
-(instancetype)initWithIceServers:(NSArray<RTCIceServer*>*)iceServers;
-(void)addDelegate:(NSObject<KIMVideoChatModuleDelegate>*)delegate;
-(void)removeDelegate:(NSObject<KIMVideoChatModuleDelegate>*)delegate;
-(void)sendRequest:(KIMVideoChatRequest*)request withDelegate:(NSObject<KIMMediaSessionDelegate>*)mediaSessionDelegate completion:(KIMVideoChatModuleSendFriendRequestCompletionCallback)completionCallback;
-(void)cancelRequest:(KIMVideoChatRequest*)request;
-(KIMMediaSession*)acceptRequest:(KIMVideoChatRequest*)request withDelegate:(NSObject<KIMMediaSessionDelegate>*)voiceSessionDelegate;
-(void)rejectRequest:(KIMVideoChatRequest*)request;
@end

@protocol KIMVideoChatModuleDelegate
@optional
-(void)didKIMVideoChatModule:(KIMVideoChatModule*)videoChatModule receivedVideoChatRequest:(KIMVideoChatRequest*)videoChatRequest;
-(void)didKIMVideoChatModule:(KIMVideoChatModule*)videoChatModule receivedVideoChatRequestCancel:(KIMVideoChatRequest*)videoChatRequest;
@end
