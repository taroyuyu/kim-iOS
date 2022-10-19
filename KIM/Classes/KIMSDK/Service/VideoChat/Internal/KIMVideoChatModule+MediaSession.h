//
//  KIMVideoChatModule+MediaSession.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/9.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMVideoChatModule.h"

@class RTCSessionDescription;
@class RTCIceCandidate;
@protocol KIMVideoChatModuleSignalDelegate;

@interface KIMVideoChatModule (MediaSession)
-(void)addSignalDelegate:(NSObject<KIMVideoChatModuleSignalDelegate>*)signalDelegate;
-(void)removeSignalDelegate:(NSObject<KIMVideoChatModuleSignalDelegate>*)signalDelegate;
-(void)sendOffer:(RTCSessionDescription*)sdp offerId:(uint64_t)offerId;
-(void)sendAnswer:(RTCSessionDescription*)sdp offerId:(uint64_t)offerId;
-(void)sendNegotiationResult:(BOOL)isNegotiationSuccess offerId:(uint64_t)offerId;
-(void)sendICECandidate:(RTCIceCandidate*)iceCandidate offerId:(uint64_t)offerId;
-(void)sendByeToOffer:(uint64_t)offerId;
@end

@protocol KIMVideoChatModuleSignalDelegate
-(uint64_t)offerId;
-(void)didVideoChatModuleReceivedOffer:(RTCSessionDescription*)sdp;
-(void)didVideoChatModuleReceivedAnswer:(RTCSessionDescription*)sdp;
-(void)didVideoChatModuleReceivedNegotiationResult:(BOOL)isScucess;
-(void)didVideoChatModuleReceivedCandidateAddress:(RTCIceCandidate*)iceCandidate;
-(void)didVideoChatModuleReceivedBye;
@end
