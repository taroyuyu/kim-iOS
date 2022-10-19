//
//  KIMChatGroup.h
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KIMChatGroup : NSObject<NSCoding,NSCopying>
@property(nonatomic,strong)NSString * groupId;
-(instancetype)initWithGroupId:(NSString*)groupId;
@end
