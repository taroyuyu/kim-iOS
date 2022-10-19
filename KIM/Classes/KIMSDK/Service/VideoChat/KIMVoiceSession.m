//
//  KIMVoiceSession.m
//  HUTLife
//
//  Created by taroyuyu on 2018/5/5.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMVoiceSession.h"
#import "KIMVideoChatModule+MediaSession.h"
#import <WebRTC/RTCIceServer.h>
#import <WebRTC/RTCIceCandidate.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCMediaStream.h>
#import <WebRTC/RTCSessionDescription.h>
typedef NS_ENUM(NSUInteger,KIMVoiceSessionMode)
{
    KIMVoiceSessionMode_Initiative,
    KIMVoiceSessionMode_Passive,
};

@interface KIMVoiceSession()<KIMVideoChatModuleSignalDelegate,RTCPeerConnectionDelegate>
@property(nonatomic,assign)uint64_t offerId;
@property(nonatomic,assign)KIMVoiceSessionMode mode;
@property(nonatomic,strong)NSArray<RTCIceServer*> *iceServerList;
@property(nonatomic,strong)RTCPeerConnection * peerConnection;
@property(nonatomic,strong)NSMutableArray<RTCIceCandidate*> * localICECandidateList;
@property(nonatomic,strong)NSMutableArray<RTCIceCandidate*> * remoteICECandidateList;
@property(nonatomic,strong)RTCPeerConnectionFactory *peerConnectionFactory;
@end

@implementation KIMVoiceSession
@synthesize sessionState = _sessionState;
static NSString * const OfferToReceiveAudio = @"true";
static NSString * const OfferToReceiveVideo = @"false";
-(instancetype)initWithOfferId:(uint64_t)offerId opponent:(KIMUser*)opponent videoChatModule:(KIMVideoChatModule*)videoChatModule iceServerList:(NSArray<RTCIceServer*>*)iceServerList peerConnectionFactory:(RTCPeerConnectionFactory*) peerConnectionFactory
{
    self = [super init];
    
    if (self) {
        [self setOfferId:offerId];
        [self setOpponent:opponent];
        [self setVideoChatModule:videoChatModule];
        [self setIceServerList:iceServerList];
        [self setPeerConnectionFactory:peerConnectionFactory];
        [self.videoChatModule addSignalDelegate:self];
        [self setSessionState:KIMMediaSessionState_New];
    }
    
    return self;
}

-(void)dealloc
{
    [self.videoChatModule removeSignalDelegate:self];
}

-(NSMutableArray<RTCIceCandidate*> *)localICECandidateList
{
    if (self->_localICECandidateList) {
        return self->_localICECandidateList;
    }
    
    self->_localICECandidateList = [NSMutableArray<RTCIceCandidate*>  array];
    
    return self->_localICECandidateList;
}
-(NSMutableArray<RTCIceCandidate*> *)remoteICECandidateList
{
    if (self->_remoteICECandidateList) {
        return self->_remoteICECandidateList;
    }
    
    self->_remoteICECandidateList = [NSMutableArray<RTCIceCandidate*> array];
    
    return self->_remoteICECandidateList;
}

-(void)setSessionState:(KIMMediaSessionState)sessionState
{
    
    if (sessionState == self.sessionState) {
        return;
    }
    self->_sessionState = sessionState;
    
    switch (self->_sessionState) {
        case KIMMediaSessionState_Negotiating:
        {
            if ([self.delegate respondsToSelector:@selector(mediaSessionStartedNegotiation:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate mediaSessionStartedNegotiation:self];
                });
            }
        }
            break;
        case KIMMediaSessionState_NegotiationFailed:
        {
            [self.videoChatModule sendNegotiationResult:NO offerId:self.offerId];
            if ([self.delegate respondsToSelector:@selector(mediaSessionNegotiationFailed:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate mediaSessionNegotiationFailed:self];
                });
            }
        }
            break;
        case KIMMediaSessionState_NegotiationSuccess:
        {
            [self.videoChatModule sendNegotiationResult:YES offerId:self.offerId];
            if ([self.delegate respondsToSelector:@selector(mediaSessionNegotiationSuccess:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate mediaSessionNegotiationSuccess:self];
                });
            }
            RTCIceCandidate * candidate = [self.localICECandidateList firstObject];
            while (candidate) {
                [[self videoChatModule] sendICECandidate:candidate offerId:self.offerId];
                [[self localICECandidateList] removeObjectAtIndex:0];
                candidate = [self.localICECandidateList firstObject];
            }
            candidate = [self.remoteICECandidateList firstObject];
            while (candidate) {
                [self.peerConnection addIceCandidate:candidate];
                candidate = [self.remoteICECandidateList firstObject];
            }
        }
            break;
        case KIMMediaSessionState_Connected:
        {
            if ([self.delegate respondsToSelector:@selector(mediaSessionConnected:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate mediaSessionConnected:self];
                });
            }
        }
            break;
        case KIMMediaSessionState_DisConnected:
        {
            //1.通知Delegate
            if ([self.delegate respondsToSelector:@selector(mediaSessionDisconnected:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate mediaSessionDisconnected:self];
                });
            }
            //2.销毁会话
            [self destorySession];
        }
            break;
        case KIMMediaSessionState_Bye:
        {
            if ([self.delegate respondsToSelector:@selector(mediaSessionDidHangUp:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate mediaSessionDidHangUp:self];
                });
            }
        }
        default:
            break;
    }
}

- (void)startSession
{
    
    [self setMode:KIMVoiceSessionMode_Initiative];
    
    //1.初始化peerConnection对象
    //1.1设置本次对等连接的相关约束:仅支持语音通话，不支持视频通话。开启安全实时传输
    RTCMediaConstraints* peerConnectionConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":OfferToReceiveAudio,@"OfferToReceiveVideo":OfferToReceiveAudio} optionalConstraints:@{@"internalSctpDataChannels":@"true",@"DtlsSrtpKeyAgreement":@"true"}];
    //1.2创建peerConnection对象
    RTCConfiguration *peerConnectionConfig = [[RTCConfiguration alloc] init];
    peerConnectionConfig.iceServers = self.iceServerList;
    self.peerConnection = [[self peerConnectionFactory] peerConnectionWithConfiguration:peerConnectionConfig constraints:peerConnectionConstraints delegate:self];
    
    //2.添加本地媒体流
    //2.1构建本地媒体流对象
    RTCMediaStream *localMediaStream = [[self peerConnectionFactory] mediaStreamWithStreamId:@"LocalMediaStream"];
    //2.2添加音频轨道
    RTCMediaConstraints *localAudioStreamConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                                             optionalConstraints:nil];
    RTCAudioSource *localAudioSource = [[self peerConnectionFactory] audioSourceWithConstraints:localAudioStreamConstraints];
    RTCAudioTrack *localAudioTrack = [[self peerConnectionFactory] audioTrackWithSource:localAudioSource trackId:@"localAudioTrack"];
    [localMediaStream addAudioTrack:localAudioTrack];

    [self.peerConnection addStream:localMediaStream];
    //3.进行创建offer,进行媒体协商
    RTCMediaConstraints* mediaConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":OfferToReceiveAudio,@"OfferToReceiveVideo":OfferToReceiveAudio} optionalConstraints:nil];
    __weak KIMVoiceSession *weakSelf = self;
    [self.peerConnection offerForConstraints:mediaConstraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error) {
            //创建提议失败
            [weakSelf setSessionState:KIMMediaSessionState_NegotiationFailed];
        }else{
            //创建提议成功
            [weakSelf.peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                if (error) {
                    //设置本地SDP失败
                    [weakSelf setSessionState:KIMMediaSessionState_NegotiationFailed];
                }else{
                    //设置本地SDP成功,通过信令消息发送此会话描述符
                    [[weakSelf videoChatModule] sendOffer:self.peerConnection.localDescription offerId:self.offerId];
                }
            }];
        }
    }];
    
    [self setSessionState:KIMMediaSessionState_Negotiating];
}


-(void)didVideoChatModuleReceivedAnswer:(RTCSessionDescription*)sdp
{
    if (KIMVoiceSessionMode_Initiative  == self.mode) {
        //接收到对方的应答,设置对方的会话描述符
        
        __weak KIMVoiceSession *weakSelf = self;
        [self.peerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
            if (error) {
                //设置对方的SDP会话描述符失败
                [weakSelf setSessionState:KIMMediaSessionState_NegotiationFailed];
            }else{
                //设置对方的SDP会话描述符成功,协商成功
                [weakSelf setSessionState:KIMMediaSessionState_NegotiationSuccess];
            }
        }];
    }else{
        [self setSessionState:KIMMediaSessionState_NegotiationFailed];
    }
}

-(void)waitSession
{
    
    [self setMode:KIMVoiceSessionMode_Passive];
    //1.初始化peerConnection对象
    //1.1设置本次对等连接的相关约束:仅支持语音通话，不支持视频通话。开启安全实时传输
    RTCMediaConstraints* peerConnectionConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":OfferToReceiveAudio,@"OfferToReceiveVideo":OfferToReceiveAudio} optionalConstraints:@{@"internalSctpDataChannels":@"true",@"DtlsSrtpKeyAgreement":@"true"}];
    
    //1.2创建peerConnection对象
    RTCConfiguration *peerConnectionConfig = [[RTCConfiguration alloc] init];
    peerConnectionConfig.iceServers = self.iceServerList;
    self.peerConnection = [[self peerConnectionFactory] peerConnectionWithConfiguration:peerConnectionConfig constraints:peerConnectionConstraints delegate:self];
    
    //2.添加本地媒体流
    //2.1构建本地媒体流对象
    RTCMediaStream *localMediaStream = [[self peerConnectionFactory] mediaStreamWithStreamId:@"LocalMediaStream"];
    //2.2添加音频轨道
    RTCMediaConstraints *localAudioStreamConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                                             optionalConstraints:nil];
    RTCAudioSource *localAudioSource = [[self peerConnectionFactory] audioSourceWithConstraints:localAudioStreamConstraints];
    RTCAudioTrack *localAudioTrack = [[self peerConnectionFactory] audioTrackWithSource:localAudioSource trackId:@"localAudioTrack"];
    [localMediaStream addAudioTrack:localAudioTrack];
    
    [self.peerConnection addStream:localMediaStream];
    
    [self setSessionState:KIMMediaSessionState_Pending];
}

// 接收到对方发送过来的offer
-(void)didVideoChatModuleReceivedOffer:(RTCSessionDescription*)sdp
{
    if (KIMVoiceSessionMode_Passive == self.mode) {
        __weak KIMVoiceSession *weakSelf = self;
        
        [self.peerConnection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
            if (error) {
                //设置对方的SDP会话描述符失败
                [weakSelf setSessionState:KIMMediaSessionState_NegotiationFailed];
            }else{
                //设置对方的SDP会话描述符成功，请求创建本地SDP
                //创建answer,进行媒体协商
                RTCMediaConstraints* peerConnectionConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":OfferToReceiveAudio,@"OfferToReceiveVideo":OfferToReceiveAudio} optionalConstraints:@{@"internalSctpDataChannels":@"true",@"DtlsSrtpKeyAgreement":@"true"}];
                [weakSelf.peerConnection answerForConstraints:peerConnectionConstraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
                    if (error) {
                        //创建响应失败
                        [weakSelf setSessionState:KIMMediaSessionState_NegotiationFailed];
                    }else{
                        //设置本地会话描述符
                        [weakSelf.peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                            if (error) {
                                //设置本地的SDP会话描述符失败
                                [weakSelf setSessionState:KIMMediaSessionState_NegotiationFailed];
                            }else{
                                //设置本地的SDP会话描述符成功,通过信令消息发送此会话描述符
                                [[weakSelf videoChatModule] sendAnswer:weakSelf.peerConnection.localDescription offerId:weakSelf.offerId];
                            }
                        }];
                    }
                }];
            }
        }];
        [self setSessionState:KIMMediaSessionState_Negotiating];
    }else{
        [self setSessionState:KIMMediaSessionState_NegotiationFailed];
    }
}


-(void)didVideoChatModuleReceivedNegotiationResult:(BOOL)isScucess
{

    if (isScucess) {
         [self setSessionState:KIMMediaSessionState_NegotiationSuccess];
    }else{
         [self setSessionState:KIMMediaSessionState_NegotiationFailed];
    }
}

// 信令状态发生改变
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged
{
    
}

//收到一个来对方的新的媒体流
- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream
{
    //接收到来自对方的媒体流
}

//对方移除了一个媒体流
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream
{
}

//需要重新进行协商,例如ICE重启
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection
{
}
//接收到来自对方的ICE候选项
-(void)didVideoChatModuleReceivedCandidateAddress:(RTCIceCandidate*)iceCandidate
{
    if (KIMMediaSessionState_NegotiationSuccess == self.sessionState) {
        [self.peerConnection addIceCandidate:iceCandidate];
    }else if (KIMMediaSessionState_Negotiating) {
        [self.remoteICECandidateList addObject:iceCandidate];
    }
    
}

//ICE连接状态发生改变
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState
{
    if (newState == RTCIceConnectionStateConnected)
    {
        [self setSessionState:KIMMediaSessionState_Connected];
    }
    else if (newState == RTCIceConnectionStateDisconnected)
    {
        [self setSessionState:KIMMediaSessionState_DisConnected];
    }
}

//ICE收集状态发生改变
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState
{
    
}
//找到新的ICE候选项
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate
{
    if (KIMMediaSessionState_NegotiationSuccess == self.sessionState) {
        [self.videoChatModule sendICECandidate:candidate offerId:self.offerId];
    }else if (KIMMediaSessionState_Pending == self.sessionState || KIMMediaSessionState_Negotiating == self.sessionState) {
        [self.localICECandidateList addObject:candidate];
    }
    
}

//当前自身(本地)的一些ICE候选项已经不再适用，已被移除
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates
{
    
}

//新的数据通道被打开
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel;
{
    
}


-(void)hangup
{
    if (KIMMediaSessionState_Bye == self.sessionState) {
        return;
    }
    
    //1.发送Bye
    [self.videoChatModule sendByeToOffer:self.offerId];
    //2.修改状态
    [self setSessionState:KIMMediaSessionState_Bye];
    //3.释放相关资源
    [self destorySession];
}

-(void)didVideoChatModuleReceivedBye
{
    if (KIMMediaSessionState_Bye == self.sessionState) {
        return;
    }
    
    //1.设置状态
    [self setSessionState:KIMMediaSessionState_Bye];
    //2.释放相关资源
    [self destorySession];
}

-(void)destorySession
{
    //1.关闭对等连接,即终止所有媒体流并关闭传输
    [self.peerConnection close];
    [self setPeerConnection:nil];
    
    //2.释放相关资源
    [self setIceServerList:nil];
    [self setLocalICECandidateList:nil];
    [self setRemoteICECandidateList:nil];
    //3.移除对offer的监听
    [self.videoChatModule removeSignalDelegate:self];
}

@end
