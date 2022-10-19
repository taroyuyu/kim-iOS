//
//  KIMClient+Service.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMClient.h"

@class GPBMessage;

@interface KIMClient (Service)
/**
 * @return 若当前可以发送消息则返回YES,否则返回NO
 */
-(BOOL)sendMessage:(GPBMessage*)message;
/**
 * 获取当前设备标识
 */
-(NSString*)currentDeviceIdentifier;
@end
