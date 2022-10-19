//
//  KIMVideoChatSession.h
//  HUTLife
//
//  Created by taroyuyu on 2018/5/3.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"

@class KIMVideoChatModule;
@interface KIMVideoChatSession : NSObject
@property(nonatomic,readonly)KIMUser * currentUser;
@property(nonatomic,readonly)KIMUser * peerUser;
@property(nonatomic,readonly)KIMVideoChatModule * videoChatModule;
@end
