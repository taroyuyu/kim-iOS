//
//  KIMMediaSession.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/9.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger,KIMMediaSessionState)
{
    KIMMediaSessionState_New,//对象刚刚被创建，还没有准备好处理会话
    KIMMediaSessionState_Pending,//正在等待对方发送Offer
    KIMMediaSessionState_Negotiating,//正在进行会话协商
    KIMMediaSessionState_NegotiationFailed,//连接失败
    KIMMediaSessionState_NegotiationSuccess,//协商成功，正在建立对等连接
    KIMMediaSessionState_Connected,//对等连接建立
    KIMMediaSessionState_DisConnected,//对等连接断开
    KIMMediaSessionState_Bye,//会话结束
};

@class KIMVideoChatModule;
@class KIMUser;
@protocol KIMMediaSessionDelegate;

@interface KIMMediaSession : NSObject
@property(nonatomic,weak)KIMVideoChatModule * videoChatModule;
@property(nonatomic,strong)KIMUser * opponent;
@property(nonatomic,readonly)KIMMediaSessionState sessionState;
@property(nonatomic,weak)NSObject<KIMMediaSessionDelegate> * delegate;
/**
 * 挂断电话
 */
-(void)hangup;
@end

@protocol KIMMediaSessionDelegate
@optional
/**
 * 正在进行协商
 */
-(void)mediaSessionStartedNegotiation:(KIMMediaSession *)mediaSession;
/**
 * 协商失败
 */
-(void)mediaSessionNegotiationFailed:(KIMMediaSession*)mediaSession;
/**
 * 协商成功
 */
-(void)mediaSessionNegotiationSuccess:(KIMMediaSession*)mediaSession;
/**
 * 对等连接建立
 */
-(void)mediaSessionConnected:(KIMMediaSession*)mediaSession;
/**
 * 连接断开
 */
-(void)mediaSessionDisconnected:(KIMMediaSession*)mediaSession;
/**
 * 会话结束
 */
-(void)mediaSessionDidHangUp:(KIMMediaSession*)mediaSession;
@end
