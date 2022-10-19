//
//  KIMUser.m
//  KIMSDKTest
//
//  Created by taroyuyu on 2018/5/27.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMUser.h"

@implementation KIMUser
-(instancetype)initWithUserAccount:(NSString*)userAccount
{
    if (![userAccount length]) {
        return nil;
    }
    self = [super init];
    
    if (self) {
        self.account = userAccount;
    }
    
    return self;
}
NSString * KIMUserAccountKey = @"Account";
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (self.account) {
        [aCoder encodeObject:self.account forKey:KIMUserAccountKey];
    }
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (self) {
        self.account = [aDecoder decodeObjectForKey:KIMUserAccountKey];
    }
    
    return self;
}
- (id)copyWithZone:(nullable NSZone *)zone
{
    KIMUser * copy = [[KIMUser allocWithZone:zone] initWithUserAccount:[self.account copyWithZone:zone]];
    
    return copy;
}
-(BOOL)isEqual:(KIMUser*)user
{
    if (user.class != self.class) {
        return NO;
    }
    return self.hash == user.hash;
}
-(NSUInteger)hash
{
    return [self.account hash];
}

@end
