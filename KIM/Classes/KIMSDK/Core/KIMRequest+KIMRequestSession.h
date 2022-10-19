//
//  KIMRequest+KIMRequestSession.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/26.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMRequest.h"
@class KIMTCPSocketManager;
@interface KIMRequest (KIMRequestSession)
-(void)executeWithSocketManager:(KIMTCPSocketManager*)socketManager;
@end
