//
//  KIMTCPSocketManager.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KIMClientSocket;

typedef NS_ENUM(NSUInteger,KIMTCPSocketManagerState)
{
    KIMTCPSocketManagerState_Stop,//停止运行
    KIMTCPSocketManagerState_Running,//正在运行
};

@interface KIMTCPSocketManager : NSObject
@property(atomic,readonly)KIMTCPSocketManagerState state;
-(void)addClientSocket:(KIMClientSocket*)clientSocket;
-(void)removeClientSocket:(KIMClientSocket*)clientSocket;
-(void)start;
-(void)stop;
@end
