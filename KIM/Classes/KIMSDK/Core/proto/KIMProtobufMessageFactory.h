//
//  KIMProtobufMessageFactory.h
//  KakaIM
//
//  Created by taroyuyu on 2018/4/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPBProtocolBuffers.h"
@interface KIMProtobufMessageFactory : NSObject
+(GPBMessage*)createMessageWithFullName:(NSString*)fullName andData:(NSData*)data;
@end
