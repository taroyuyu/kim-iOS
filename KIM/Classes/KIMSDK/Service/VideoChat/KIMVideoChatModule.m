//
//  KIMVideoChatModule.m
//  HUTLife
//
//  Created by taroyuyu on 2018/5/3.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMVideoChatModule.h"
#import "KIMClient+Service.h"
#import "KIMClient+VideoChatModule.h"
#import "KakaImmessage.pbobjc.h"
#import <sys/time.h>
#import "KIMVideoChatRequest+KIMVideoChatModule.h"
#import "KIMVideoChatModule+MediaSession.h"
#import "KIMMediaSession+Private.h"
#import "KIMVoiceSession.h"
#import "KIMVideoSession.h"
#import <WebRTC/RTCSessionDescription.h>
#import <WebRTC/RTCIceServer.h>
#import <WebRTC/RTCIceCandidate.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCDefaultVideoDecoderFactory.h>
#import <WebRTC/RTCDefaultVideoEncoderFactory.h>

NSErrorDomain const KIMVideoChatModuleErrorDomain = @"KIMVideoChatModule";

typedef NS_ENUM(NSUInteger,KIMVideoChatModuleState)
{
    KIMVideoChatModuleState_Stop,//停止运作
    KIMVideoChatModuleState_Runing,//正在运作
};

@interface KIMVideoChatModule()
#pragma mark - 模块相关
@property(nonatomic,strong)NSLock * moduleStateLock;
@property(nonatomic,assign)KIMVideoChatModuleState moduleState;
@property(nonatomic,weak)KIMClient * imClient;
@property(nonatomic,strong)NSSet<NSString*>* messageTypes;
@property(nonatomic,strong)NSDateFormatter *dateFormatter;
@property(nonatomic,strong)NSArray<RTCIceServer*> * iceServerList;
@property(nonatomic,strong)RTCPeerConnectionFactory *peerConnectionFactory;
#pragma mark - 用户相关
@property(nonatomic,strong)KIMUser * currentUser;
@property(nonatomic,strong)NSMutableSet<NSObject<KIMVideoChatModuleDelegate>*> * delegateSet;
@property(nonatomic,strong)NSMutableDictionary<NSObject<NSCopying>*,id> * callbackHub;
@property(nonatomic,strong)NSMutableDictionary<NSObject<NSCopying>*,KIMVideoChatRequest*> * pendingRequestSet;
@property(nonatomic,strong)NSMutableDictionary<NSString*,KIMVideoChatRequest*> * canceldRequestSet;
@property(nonatomic,strong)NSMutableDictionary<NSNumber*,NSObject<KIMVideoChatModuleSignalDelegate>*> * signalDelegateSet;
@end

@implementation KIMVideoChatModule
-(instancetype)initWithIceServers:(NSArray<RTCIceServer*>*)iceServers
{
    if(!iceServers.count){
        return nil;
    }
    self = [super init];
    if (self) {
        //模块相关
        self.moduleState = KIMVideoChatModuleState_Stop;
        self.moduleStateLock = [[NSLock alloc] init];
        NSMutableSet<NSString*> * messageTypeSet = [[NSMutableSet<NSString*> alloc] init];
        [messageTypeSet addObject:[[KIMProtoVideoChatRequestMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoVideoChatReplyMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoVideoChatRequestCancelMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoVideoChatOfferMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoVideoChatAnswerMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoVideoChatNegotiationResultMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoVideoChatCandidateAddressMessage descriptor]fullName]];
        [messageTypeSet addObject:[[KIMProtoVideoChatByeMessage descriptor]fullName]];
        self.messageTypes = [messageTypeSet copy];
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.dateFormatter.dateFormat = @"YYYY-MM-dd HH:mm:ss";
        self.dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        
        self.iceServerList = iceServers;
        
        RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
        RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
        self.peerConnectionFactory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory
                                                                                 decoderFactory:decoderFactory];
        
        //用户相关
        self.delegateSet = [[NSMutableSet<NSObject<KIMVideoChatModuleDelegate>*> alloc] init];
        self.signalDelegateSet = [NSMutableDictionary<NSNumber*,NSObject<KIMVideoChatModuleSignalDelegate>*> dictionary];
        self.callbackHub = [NSMutableDictionary<NSObject<NSCopying>*,id> dictionary];
        self.pendingRequestSet = [NSMutableDictionary<NSObject<NSCopying>*,KIMVideoChatRequest*> dictionary];
        self.canceldRequestSet = [NSMutableDictionary<NSString*,KIMVideoChatRequest*> dictionary];
    }
    return self;
}

#pragma mark KIMVideoChatModuleDelegate
-(void)addDelegate:(NSObject<KIMVideoChatModuleDelegate>*)delegate
{
    [[self delegateSet] addObject:delegate];
}
-(void)removeDelegate:(NSObject<KIMVideoChatModuleDelegate>*)delegate
{
    [[self delegateSet] removeObject:delegate];
}

#pragma mark - KIMClientService
-(void)setIMClient:(KIMClient*)imClient
{
    self.imClient = imClient;
}
-(NSSet<NSString*>*)messageTypeSet
{
    return self.messageTypes;
}

-(void)handleMessage:(GPBMessage *)message
{
    NSString * const messageType = [[message descriptor] fullName];
    if(![self->_messageTypes containsObject:messageType]){
        return;
    }
    
    if ([messageType isEqualToString: [[KIMProtoVideoChatRequestMessage descriptor] fullName]]) {
        [self handleVideoChatRequestMessage:(KIMProtoVideoChatRequestMessage*)message];
    }else if ([messageType isEqualToString: [[KIMProtoVideoChatReplyMessage descriptor] fullName]]) {
        [self handleVideoChatRequestReplyMessage:(KIMProtoVideoChatReplyMessage*)message];
    }else if([messageType isEqualToString:[[KIMProtoVideoChatRequestCancelMessage descriptor]fullName]]){
        [self handleVideoChatRequestCancelMessage:(KIMProtoVideoChatRequestCancelMessage*)message];
    }else if([messageType isEqualToString:[[KIMProtoVideoChatOfferMessage descriptor]fullName]]){
        [self handleVideoChatOfferMessage:(KIMProtoVideoChatOfferMessage *)message];
    }else if([messageType isEqualToString:[[KIMProtoVideoChatAnswerMessage descriptor]fullName]]){
        [self handleVideoChatAnswerMessage:(KIMProtoVideoChatAnswerMessage *)message];
    }else if([messageType isEqualToString:[[KIMProtoVideoChatNegotiationResultMessage descriptor]fullName]]){
        [self handleVideoChatNegotiationResultMessage:((KIMProtoVideoChatNegotiationResultMessage *)message)];
    }else if([messageType isEqualToString:[[KIMProtoVideoChatCandidateAddressMessage descriptor]fullName]]){
        [self handleVideoChatICECandidateAddressMessage:(KIMProtoVideoChatCandidateAddressMessage *)message];
    }else if([messageType isEqualToString:[[KIMProtoVideoChatByeMessage descriptor]fullName]]){
        [self handleVideoChatByeMessage:(KIMProtoVideoChatByeMessage *)message];
    }
}

#pragma mark 消息签名
-(NSString*)nextMessageIdentifier
{
    //1.获取设备标识符
    NSString * deviceIdentifier = [[self imClient] currentDeviceIdentifier];
    //2.获取当前时间，以毫秒为单位
    struct timeval tv;
    gettimeofday(&tv, 0);
    uint64_t timestamp = (uint64_t) tv.tv_sec * 1000 + (uint64_t) tv.tv_usec / 1000;
    return [NSString stringWithFormat:@"%@ - %llu",deviceIdentifier,timestamp];
}


-(void)sendRequest:(KIMVideoChatRequest*)request withDelegate:(NSObject<KIMMediaSessionDelegate>*)mediaSessionDelegate completion:(KIMVideoChatModuleSendFriendRequestCompletionCallback)completionCallback
{
    if (!completionCallback) {
        return;
    }
    
    [request setMediaSessionDelegate:mediaSessionDelegate];
    
    KIMProtoVideoChatRequestMessage * requestMessage = [[KIMProtoVideoChatRequestMessage alloc] init];
    switch (request.sessionType) {
        case KIMVideoChatRequestSessionType_Voice:
        {
            [requestMessage setChatType:KIMProtoVideoChatRequestMessage_ChatType_Voice];
        }
            break;
        case KIMVideoChatRequestSessionType_Video:
        {
            [requestMessage setChatType:KIMProtoVideoChatRequestMessage_ChatType_Video];
        }
            break;
        default:
        {
            NSError * error = [NSError errorWithDomain:KIMVideoChatModuleErrorDomain code:-1 userInfo:nil];
            completionCallback(self,request,error,nil,nil);
            return;
        }
            break;
    }
    [requestMessage setSponsorAccount:request.sponsor.account];
    [requestMessage setTargetAccount:request.target.account];
    [requestMessage setSponsorSessionId:self.imClient.currentSessionId];
    [requestMessage setTimestamp:[self.dateFormatter stringFromDate:[NSDate new]]];
    NSString * messageIdentifier = [self nextMessageIdentifier];
    [requestMessage setSign:messageIdentifier];
    [request setIsAcked:NO];
    [request setRequestIdentifier:messageIdentifier];
    [request setSponsorSessionId:requestMessage.sponsorSessionId];
    [self.callbackHub setObject:completionCallback forKey:messageIdentifier];
    [self.pendingRequestSet setObject:request forKey:messageIdentifier];
    [[self imClient] sendMessage:requestMessage];
}

-(void)handleVideoChatRequestMessage:(KIMProtoVideoChatRequestMessage*)requestMessage
{
    if ([requestMessage.sponsorAccount isEqualToString:self.currentUser.account]) {
        if ([[requestMessage sign] hasPrefix:[self.imClient currentDeviceIdentifier]]) {//服务器收到此次提出的请求
            //此视频通话请求正式当前设备所发出的
            KIMVideoChatModuleSendFriendRequestCompletionCallback requestCompletionCallback = [self.callbackHub objectForKey:requestMessage.sign];
            [self.callbackHub removeObjectForKey:requestMessage.sign];
            KIMVideoChatRequest * request = [[self pendingRequestSet] objectForKey:requestMessage.sign];
            [[self pendingRequestSet] removeObjectForKey:requestMessage.sign];
            NSAssert(requestCompletionCallback, @"%s,requestCompletionCallback不存在",__FUNCTION__);
            NSAssert(request, @"%s,request不存在",__FUNCTION__);
            [request setOfferId:requestMessage.offerId];
            [request setIsAcked:YES];
            if ([self.canceldRequestSet objectForKey:request.requestIdentifier]) {//取消此通话请求
                KIMProtoVideoChatRequestCancelMessage * cancelMessage = [[KIMProtoVideoChatRequestCancelMessage alloc] init];
                [cancelMessage setOfferId:request.offerId];
                [[self imClient] sendMessage:cancelMessage];
                [[self canceldRequestSet] removeObjectForKey:request.requestIdentifier];
            }else{
                [self.callbackHub setObject:requestCompletionCallback forKey:[NSNumber numberWithUnsignedLongLong:requestMessage.offerId]];
                [self.pendingRequestSet setObject:request forKey:[NSNumber numberWithUnsignedLongLong:requestMessage.offerId]];
            }
        }else{//其它设备正在以该用户向其它用户发起视频通话请求
            
        }
    }else if([requestMessage.targetAccount isEqualToString:self.currentUser.account]){//收到来自好友发来的视频通话请求
        KIMVideoChatRequest * videoChatRequest = [[KIMVideoChatRequest alloc] init];
        switch (requestMessage.chatType) {
            case KIMProtoVideoChatRequestMessage_ChatType_Voice://语音通话
            {
                videoChatRequest.sessionType = KIMVideoChatRequestSessionType_Voice;
                
            }
                break;
            case KIMProtoVideoChatRequestMessage_ChatType_Video://视频通话
            {
                videoChatRequest.sessionType = KIMVideoChatRequestSessionType_Video;
            }
                break;
            default:
                return;
        }
        [videoChatRequest setOfferId:requestMessage.offerId];
        [videoChatRequest setSponsor:[[KIMUser alloc]initWithUserAccount:requestMessage.sponsorAccount]];
        [videoChatRequest setTarget:[[KIMUser alloc]initWithUserAccount:requestMessage.targetAccount]];
        [videoChatRequest setSubmissionTime:[self.dateFormatter dateFromString:requestMessage.timestamp]];
        [videoChatRequest setSponsorSessionId:requestMessage.sponsorSessionId];
        for (NSObject<KIMVideoChatModuleDelegate> * delegate in self.delegateSet) {
            if ([delegate respondsToSelector:@selector(didKIMVideoChatModule:receivedVideoChatRequest:)]) {
                dispatch_block_t block = ^(void){
                    [delegate didKIMVideoChatModule:self receivedVideoChatRequest:videoChatRequest];
                };
                dispatch_async(dispatch_get_main_queue(), block);
            }
        }
    }
}

-(void)cancelRequest:(KIMVideoChatRequest*)request
{
    if (!request) {
        return;
    }
    if (![request isAcked]) {
        //此请求还未被确认，稍后再取消
        if (request.requestIdentifier) {
            [[self canceldRequestSet] setObject:request forKey:request.requestIdentifier];
        }
    }else{
        //取消此请求
         KIMProtoVideoChatRequestCancelMessage * cancelMessage = [[KIMProtoVideoChatRequestCancelMessage alloc] init];
        [cancelMessage setOfferId:request.offerId];
        [[self imClient] sendMessage:cancelMessage];
    }
}

-(void)handleVideoChatRequestCancelMessage:(KIMProtoVideoChatRequestCancelMessage*)cancel
{
    KIMVideoChatRequest * videoChatRequest = [[KIMVideoChatRequest alloc] init];
    [videoChatRequest setOfferId:cancel.offerId];
    
    for (NSObject<KIMVideoChatModuleDelegate> * delegate in self.delegateSet) {
        if ([delegate respondsToSelector:@selector(didKIMVideoChatModule:receivedVideoChatRequestCancel:)]) {
            dispatch_block_t block = ^(void){
                [delegate didKIMVideoChatModule:self receivedVideoChatRequestCancel:videoChatRequest];
            };
            dispatch_async(dispatch_get_main_queue(), block);
        }
    }
}
-(KIMMediaSession*)acceptRequest:(KIMVideoChatRequest*)request withDelegate:(NSObject<KIMMediaSessionDelegate>*)voiceSessionDelegate
{
    
    //1.创建voiceSession
    KIMMediaSession * mediaSession = nil;
    switch (request.sessionType) {
        case KIMVideoChatRequestSessionType_Voice:
        {
            mediaSession = [[KIMVoiceSession alloc] initWithOfferId:request.offerId opponent:request.target videoChatModule:self iceServerList:[self.iceServerList copy] peerConnectionFactory:self.peerConnectionFactory];
        }
            break;
        case KIMVideoChatRequestSessionType_Video:
        {
            mediaSession = [[KIMVideoSession alloc] initWithOfferId:request.offerId opponent:request.target videoChatModule:self iceServerList:[self.iceServerList copy] peerConnectionFactory:self.peerConnectionFactory];
        }
            break;
        default:
            return nil;
    }
    [mediaSession setDelegate:voiceSessionDelegate];
    //2.启动会话
    [mediaSession waitSession];
    
    //3.回复
    KIMProtoVideoChatReplyMessage * replyMessage = [[KIMProtoVideoChatReplyMessage alloc] init];
    [replyMessage setOfferId:request.offerId];
    [replyMessage setSponsorAccount:request.sponsor.account];
    [replyMessage setTargetAccount:request.target.account];
    [replyMessage setAnswerSessionId:self.imClient.currentSessionId];
    [replyMessage setReply:KIMProtoVideoChatReplyMessage_VideoChatReply_VideoChatReplyAllow];
    [replyMessage setTimestamp:[self.dateFormatter stringFromDate:[NSDate date]]];
    [replyMessage setSign:[self nextMessageIdentifier]];
    [[self imClient] sendMessage:replyMessage];
    
    return mediaSession;
}
-(void)rejectRequest:(KIMVideoChatRequest*)request
{
    KIMProtoVideoChatReplyMessage * replyMessage = [[KIMProtoVideoChatReplyMessage alloc] init];
    [replyMessage setOfferId:request.offerId];
    [replyMessage setSponsorAccount:request.sponsor.account];
    [replyMessage setTargetAccount:request.target.account];
    [replyMessage setAnswerSessionId:self.imClient.currentSessionId];
    [replyMessage setReply:KIMProtoVideoChatReplyMessage_VideoChatReply_VideoChatReplyReject];
    [replyMessage setTimestamp:[self.dateFormatter stringFromDate:[NSDate date]]];
    [replyMessage setSign:[self nextMessageIdentifier]];
    [[self imClient] sendMessage:replyMessage];
}


-(void)handleVideoChatRequestReplyMessage:(KIMProtoVideoChatReplyMessage*)replyMessage
{
    if ([replyMessage.targetAccount isEqualToString:self.currentUser.account]) {
        //我方设备对请求进行了答复
        if (![replyMessage.answerSessionId isEqualToString:self.imClient.currentSessionId]) {
            KIMVideoChatRequest * videoChatRequest = [[KIMVideoChatRequest alloc] init];
            [videoChatRequest setOfferId:replyMessage.offerId];
            
            for (NSObject<KIMVideoChatModuleDelegate> * delegate in self.delegateSet) {
                if ([delegate respondsToSelector:@selector(didKIMVideoChatModule:receivedVideoChatRequestCancel:)]) {
                    dispatch_block_t block = ^(void){
                        [delegate didKIMVideoChatModule:self receivedVideoChatRequestCancel:videoChatRequest];
                    };
                    dispatch_async(dispatch_get_main_queue(), block);
                }
            }
        }else{
            //本设备对请求进行了回复
        }
    }else if([replyMessage.sponsorAccount isEqualToString:self.currentUser.account]){
        //收到对方的答复
        
        if ([[replyMessage sponsorSessionId] isEqualToString:[self.imClient currentSessionId]]) {//服务器收到此次提出的请求
            //此请求为我方设备提出的
            KIMVideoChatModuleSendFriendRequestCompletionCallback requestCompletionCallback = [self.callbackHub objectForKey:[NSNumber numberWithUnsignedLongLong:replyMessage.offerId]];
            NSAssert(requestCompletionCallback, @"%s,requestCompletionCallback不存在",__FUNCTION__);
            
            KIMVideoChatRequest * request = [self.pendingRequestSet objectForKey:[NSNumber numberWithUnsignedLongLong:replyMessage.offerId]];
            [self.pendingRequestSet removeObjectForKey:[NSNumber numberWithUnsignedLongLong:replyMessage.offerId]];
            KIMVideoChatRequestReply * reply = [[KIMVideoChatRequestReply alloc] init];
            [reply setOfferId:replyMessage.offerId];
            [reply setSponsor:[[KIMUser alloc]initWithUserAccount:replyMessage.sponsorAccount]];
            [reply setTarget:[[KIMUser alloc]initWithUserAccount:replyMessage.targetAccount]];
            
            KIMMediaSession * mediaSession = nil;
            
            switch (replyMessage.reply) {
                case KIMProtoVideoChatReplyMessage_VideoChatReply_VideoChatReplyAllow:
                {
                    [reply setReply:KIMVideoChatRequestReplyType_Accept];
                    
                    //1.创建voiceSession对象
                    switch (request.sessionType) {
                        case KIMVideoChatRequestSessionType_Voice:
                        {
                            mediaSession = [[KIMVoiceSession alloc] initWithOfferId:reply.offerId opponent:reply.target videoChatModule:self iceServerList:[self.iceServerList copy] peerConnectionFactory:self.peerConnectionFactory];
                            [mediaSession setDelegate:request.mediaSessionDelegate];
                        }
                            break;
                        case KIMVideoChatRequestSessionType_Video:
                        {
                            mediaSession = [[KIMVideoSession alloc] initWithOfferId:reply.offerId opponent:reply.target videoChatModule:self iceServerList:[self.iceServerList copy] peerConnectionFactory:self.peerConnectionFactory];
                            [mediaSession setDelegate:request.mediaSessionDelegate];

                        }
                            break;
                        default:
                            return;
                    }
                    
                    //2.启动会话
                    [mediaSession startSession];
                }
                    break;
                case KIMProtoVideoChatReplyMessage_VideoChatReply_VideoChatReplyReject:
                {
                    [reply setReply:KIMVideoChatRequestReplyType_Reject];
                }
                    break;
                case KIMProtoVideoChatReplyMessage_VideoChatReply_VideoChatReplyNoAnswer:
                {
                    [reply setReply:KIMVideoChatRequestReplyType_NoAnser];
                }
                default:
                {
                    [reply setReply:KIMVideoChatRequestReplyType_NoAnser];
                    NSLog(@"%s 收到答复，但是答复类型不能识别",__FUNCTION__);
                }
                    break;
            }
            [reply setSubmissionTime:reply.submissionTime];
            dispatch_block_t block = ^(void){
                requestCompletionCallback(self,request,nil,reply,mediaSession);
            };
            dispatch_async(dispatch_get_main_queue(), block);
        }else{
            NSLog(@"%s,此请求不是我方设备提出的",__FUNCTION__);
        }
    }
}

-(void)addSignalDelegate:(NSObject<KIMVideoChatModuleSignalDelegate>*)signalDelegate
{
    [self.signalDelegateSet setObject:signalDelegate forKey:[NSNumber numberWithUnsignedLongLong:signalDelegate.offerId]];
}
-(void)removeSignalDelegate:(NSObject<KIMVideoChatModuleSignalDelegate>*)signalDelegate
{
    [self.signalDelegateSet removeObjectForKey:[NSNumber numberWithUnsignedLongLong:signalDelegate.offerId]];
}
-(void)sendOffer:(RTCSessionDescription*)sdp offerId:(uint64_t)offerId
{
    KIMProtoVideoChatOfferMessage * offerMessage = [[KIMProtoVideoChatOfferMessage alloc] init];
    [offerMessage setOfferId:offerId];
    [offerMessage setSessionDescription:sdp.sdp];
    [[self imClient] sendMessage:offerMessage];
}

-(void)handleVideoChatOfferMessage:(KIMProtoVideoChatOfferMessage*)offerMessage
{
    NSObject<KIMVideoChatModuleSignalDelegate> * signalDelegate = [[self signalDelegateSet] objectForKey:[NSNumber numberWithUnsignedLongLong:offerMessage.offerId]];
    
    if (!signalDelegate) {
        return;
    }
    RTCSessionDescription * offer = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:offerMessage.sessionDescription];
    
    [signalDelegate didVideoChatModuleReceivedOffer:offer];
}

-(void)sendAnswer:(RTCSessionDescription*)sdp offerId:(uint64_t)offerId
{
    KIMProtoVideoChatAnswerMessage * answerMessage = [[KIMProtoVideoChatAnswerMessage alloc]init];
    [answerMessage setOfferId:offerId];
    [answerMessage setSessionDescription:sdp.sdp];
    [[self imClient] sendMessage:answerMessage];
}

-(void)handleVideoChatAnswerMessage:(KIMProtoVideoChatAnswerMessage*)answerMessage
{
    NSObject<KIMVideoChatModuleSignalDelegate> * signalDelegate = [[self signalDelegateSet] objectForKey:[NSNumber numberWithUnsignedLongLong:answerMessage.offerId]];
    
    if (!signalDelegate) {
        return;
    }
    
    RTCSessionDescription * answer = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:answerMessage.sessionDescription];
    
    [signalDelegate didVideoChatModuleReceivedAnswer:answer];
}

-(void)sendNegotiationResult:(BOOL)isNegotiationSuccess offerId:(uint64_t)offerId
{
    KIMProtoVideoChatNegotiationResultMessage * negotiationResultMessage = [[KIMProtoVideoChatNegotiationResultMessage alloc] init];
    
    [negotiationResultMessage setOfferId:offerId];
    if (isNegotiationSuccess) {
        [negotiationResultMessage setResult:KIMProtoVideoChatNegotiationResultMessage_NegotiationResult_NegotiationResultSuccess];
    }else{
        [negotiationResultMessage setResult:KIMProtoVideoChatNegotiationResultMessage_NegotiationResult_NegotiationResultFailed];
    }
    
    [[self imClient] sendMessage:negotiationResultMessage];
}

-(void)handleVideoChatNegotiationResultMessage:(KIMProtoVideoChatNegotiationResultMessage*)negotiationResultMessage
{
    NSObject<KIMVideoChatModuleSignalDelegate> * signalDelegate = [[self signalDelegateSet] objectForKey:[NSNumber numberWithUnsignedLongLong:negotiationResultMessage.offerId]];
    
    if (!signalDelegate) {
        return;
    }
    BOOL negotiationSuccess = FALSE;
    switch (negotiationResultMessage.result) {
        case KIMProtoVideoChatNegotiationResultMessage_NegotiationResult_NegotiationResultSuccess:
        {
            negotiationSuccess = YES;
        }
            break;
        case KIMProtoVideoChatNegotiationResultMessage_NegotiationResult_NegotiationResultFailed:
        {
            negotiationSuccess = NO;
        }
            break;
        default:
        {
            negotiationSuccess = NO;
        }
            break;
    }
    [signalDelegate didVideoChatModuleReceivedNegotiationResult:negotiationSuccess];
}

-(void)sendICECandidate:(RTCIceCandidate*)iceCandidate offerId:(uint64_t)offerId
{
    KIMProtoVideoChatCandidateAddressMessage * candidateAddressMessage = [[KIMProtoVideoChatCandidateAddressMessage alloc]init];
    [candidateAddressMessage setOfferId:offerId];
    [candidateAddressMessage setFromSessionId:self.imClient.currentSessionId];
    [candidateAddressMessage setSdpMid:iceCandidate.sdpMid];
    [candidateAddressMessage setSdpMlineIndex:iceCandidate.sdpMLineIndex];
    [candidateAddressMessage setSdpIzedDescription:iceCandidate.sdp];
    [[self imClient]sendMessage:candidateAddressMessage];
}

-(void)handleVideoChatICECandidateAddressMessage:(KIMProtoVideoChatCandidateAddressMessage*)candidateAddressMessage
{
    NSObject<KIMVideoChatModuleSignalDelegate> * signalDelegate = [[self signalDelegateSet] objectForKey:[NSNumber numberWithUnsignedLongLong:candidateAddressMessage.offerId]];
    
    if (!signalDelegate) {
        return;
    }
    
    RTCIceCandidate * iceCandidate = [[RTCIceCandidate alloc] initWithSdp:candidateAddressMessage.sdpIzedDescription sdpMLineIndex:(int)candidateAddressMessage.sdpMlineIndex sdpMid:candidateAddressMessage.sdpMid];
    
    [signalDelegate didVideoChatModuleReceivedCandidateAddress:iceCandidate];
}

-(void)sendByeToOffer:(uint64_t)offerId
{
    KIMProtoVideoChatByeMessage * byeMessage = [[KIMProtoVideoChatByeMessage alloc] init];
    [byeMessage setOfferId:offerId];
    [self.imClient sendMessage:byeMessage];
}

-(void)handleVideoChatByeMessage:(KIMProtoVideoChatByeMessage*)byeMessage
{
    NSObject<KIMVideoChatModuleSignalDelegate> * signalDelegate = [[self signalDelegateSet] objectForKey:[NSNumber numberWithUnsignedLongLong:byeMessage.offerId]];
    
    if (!signalDelegate) {
        return;
    }
    [signalDelegate didVideoChatModuleReceivedBye];
}

-(void)imClientDidLogin:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.moduleStateLock lock];
    if (KIMVideoChatModuleState_Runing == self.moduleState && [user isEqual:self.currentUser]) {
        [self.moduleStateLock unlock];
        return;
    }else{
        
        if (KIMVideoChatModuleState_Stop != self.moduleState) {//客户端以新的用户上线，但是对于上一个模块的下线并未通知
            //清空此当前用户的登录信息
            [self clearUserDataWhenLogined];
        }
        //切换用户
        self.currentUser = user;
        self.moduleState = KIMVideoChatModuleState_Runing;
        [self.moduleStateLock unlock];
    }
}
-(void)imClientDidLogout:(KIMClient*)imClient withUser:(KIMUser*)user
{
    [self.moduleStateLock lock];
    if (KIMVideoChatModuleState_Stop == self.moduleState) {
        [self.moduleStateLock unlock];
        return;
    }
    //清空此用户的登录信息
    [self clearUserDataWhenLogined];
    self.currentUser = nil;
    self.moduleState = KIMVideoChatModuleState_Stop;
    [self.moduleStateLock unlock];
}

-(void)clearUserDataWhenLogined
{
    [self.delegateSet removeAllObjects];
    [self.callbackHub removeAllObjects];
    [self.pendingRequestSet removeAllObjects];
    [self.canceldRequestSet removeAllObjects];
    [self.signalDelegateSet removeAllObjects];
}

@end
