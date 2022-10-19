//
//  KIMVideoSession+Private.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/9.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMVideoSession.h"
@class RTCIceServer;
@class RTCPeerConnectionFactory;

@interface KIMMediaSession ()
@property(nonatomic,assign)uint64_t offerId;
@property(nonatomic,strong)NSArray<RTCIceServer*> *iceServerList;
-(instancetype)initWithOfferId:(uint64_t)offerId opponent:(KIMUser*)opponent videoChatModule:(KIMVideoChatModule*)videoChatModule iceServerList:(NSArray<RTCIceServer*>*)iceServerList peerConnectionFactory:(RTCPeerConnectionFactory*) peerConnectionFactory;
- (void)startSession;
-(void)waitSession;
@end
