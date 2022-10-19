//
//  KIMChatGroup.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/31.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMChatGroup.h"

@implementation KIMChatGroup
-(instancetype)initWithGroupId:(NSString*)groupId
{
    
    if (!groupId.length) {
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        [self setGroupId:groupId];
    }
    
    return self;
}
NSString * KIMChatGroupIDKey = @"GroupId";
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (self.groupId) {
        [aCoder encodeObject:self.groupId forKey:KIMChatGroupIDKey];
    }
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self) {
        self.groupId = [aDecoder decodeObjectForKey:KIMChatGroupIDKey];
    }
    
    return self;
}
- (id)copyWithZone:(nullable NSZone *)zone
{
    KIMChatGroup * copy = [[KIMChatGroup allocWithZone:zone] initWithGroupId:[self.groupId copyWithZone:zone]];
    return copy;
}
-(BOOL)isEqual:(KIMChatGroup*)chatGroup
{
    if (self.class != chatGroup.class) {
        return NO;
    }
    
    return self.hash == chatGroup.hash;
}
-(NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%@-%@",NSStringFromClass(self.class),self.groupId] hash];
}
@end
