//
//  KIMClientSocket.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger,KIMClientSocketError)
{
    KIMClientSocketError_Connecting,//正在连接
    KIMClientSocketError_Connected,//连接已经建立
    KIMClientSocketError_Disconnected,//连接断开
    KIMClientSocketError_InternalError,//内部错误
    KIMClientSocketError_Timeout,//连接超时
};

typedef NS_ENUM(NSUInteger,KIMClientSocketState)
{
    KIMClientSocketState_Ready,//就绪
    KIMClientSocketState_Connecting,//正在连接
    KIMClientSocketState_Connected,//连接建立
    KIMClientSocketState_Disconnected,//连接断开
};

@protocol KIMClientSocketDelegate;
@class GPBMessage;
@class KIMClientSocket;

@interface KIMClientSocket : NSObject
@property(nonatomic,readonly)KIMClientSocketState socketState;
/**
 * socketDelegate的回调函数将会在全局队列中执行
 */
@property(nonatomic,weak)NSObject<KIMClientSocketDelegate> * socketDelegate;
-(instancetype)initWithServerAddr:(NSString*)serverAddr andPort:(unsigned short)serverPort;
/**
 * completionCallback将在全局队列中执行
 */
-(void)connectToServerWithCompletion:(void(^)(KIMClientSocket* clientSocket,NSError * error))completionCallback;
-(void)close;
-(void)sendMessage:(GPBMessage*)message;
@end

@protocol KIMClientSocketDelegate
-(void)clientSocket:(KIMClientSocket*)clientSocket didSocketStateChanged:(KIMClientSocketState)socketState;
-(void)clientSocket:(KIMClientSocket*)clientSocket didReceivedMessage:(GPBMessage*)message;
@end
