//
//  KIMClientSocket+KIMTCPSocketManager.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/25.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMClientSocket.h"

@class KIMTCPSocketManager;

@interface KIMClientSocket (KIMTCPSocketManager)
@property(nonatomic,readonly)int socketfd;
@property(nonatomic,readonly)BOOL hasDataForSend;
@property(nonatomic,weak)KIMTCPSocketManager * socketManager;
-(void)tryToSendData;
-(void)tryToRetrieveData;
@end
