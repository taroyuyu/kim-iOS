//
//  KIMSessionModule.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
@class GPBMessage;
typedef NS_ENUM(NSUInteger,KIMSessionModuleState)
{
    KIMSessionModuleState_Ready,//就绪
    KIMSessionModuleState_Connecting,//正在连接服务器
    KIMSessionModuleState_SessionBuilding,//正在构建会话
    KIMSessionModuleState_SessionBuilded,//会话构建
};

@protocol KIMSessionModuleDelegate;

@interface KIMSessionModule : NSObject
@property(nonatomic,readonly)KIMSessionModuleState state;
/**
 * delegate的回调将会在全局队列中执行
 */
@property(nonatomic,weak)NSObject<KIMSessionModuleDelegate> * delegate;
@property(nonatomic,readonly)NSString * sessionId;
-(instancetype) initWithServerAddr:(NSString *)serverAddr andPort:(unsigned short)serverPort;
-(void)start;
-(void)stop;
-(void)sendMessage:(GPBMessage*)message;
@end

@protocol KIMSessionModuleDelegate
-(void)sessionModule:(KIMSessionModule*)sessionModule didChangedState:(KIMSessionModuleState)state;
-(void)sessionModule:(KIMSessionModule*)sessionModule didReceivedMessage:(GPBMessage*)message;
@end
