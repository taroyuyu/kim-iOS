//
//  KIMChatGroupSession+Internal.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatGroupSession.h"

@interface KIMChatGroupSession (Internal)
@property(nonatomic,weak)KIMChatModule * chatModule;
-(instancetype)initWithCurrentUser:(KIMUser*)currentUser andChatGroup:(KIMChatGroup*)chatGroup chatModule:(KIMChatModule*)chatModule;
-(void)didReceiveMessage:(KIMChatGroupMessage*)chatGroupMessage FromChatModule:(KIMChatModule*)chatModule;
@end
