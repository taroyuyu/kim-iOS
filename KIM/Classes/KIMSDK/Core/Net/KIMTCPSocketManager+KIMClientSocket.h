//
//  KIMTCPSocketManager+KIMClientSocket.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMTCPSocketManager.h"

@interface KIMTCPSocketManager (KIMClientSocket)
-(void)notifyToSend;
@end
