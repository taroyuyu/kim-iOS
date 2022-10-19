//
//  KIMOnlineModule.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMClientService.h"
/**
 * KIMOnlineModule的通知将会在主线程发送
 */
extern NSString * const KIMUserOnlineUpdateNotificationName;

typedef NS_ENUM(NSUInteger,KIMOnlineState){
    KIMOnlineState_Online,//在线
    KIMOnlineState_Invisible,//隐身
    KIMOnlineState_Offline//离线
};

@interface KIMOnlineModule : NSObject<KIMClientService>
@property(nonatomic,assign)KIMOnlineState currentUserOnlineState;
-(KIMOnlineState)getUserOnlineState:(KIMUser*)user;
@end
