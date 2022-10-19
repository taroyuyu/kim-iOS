//
//  KIMChatGroupInfo.h
//  HUTLife
//
//  Created by taroyuyu on 2018/4/23.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMUser.h"
#import "KIMChatGroup.h"
@interface KIMChatGroupInfo : NSObject
@property(nonatomic,strong)KIMChatGroup * chatGroup;
@property(nonatomic,strong)NSString * groupName;
@property(nonatomic,strong)NSString * groupDescription;
@property(nonatomic,strong)KIMUser * groupMaster;
@end
