//
//  KIMChatSession+Internal.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatSession.h"

@interface KIMChatSession (Internal)
@property(nonatomic,weak)KIMChatModule * chatModule;
-(instancetype)initWithCurrentUser:(KIMUser*)currentUser andOpponent:(KIMUser*)opponent chatModule:(KIMChatModule*)chatModule;
-(void)didReceiveMessage:(KIMChatMessage*)chatMessage FromChatModule:(KIMChatModule*)chatModule;
@end
