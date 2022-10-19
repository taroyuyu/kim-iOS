//
//  MessageModel.m
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "MessageModel.h"

@interface MessageModel ()
@end
@implementation MessageModel
static NSString * const UnreadCountKey = @"unReadCount";
-(instancetype)init
{
    self = [super init];
    if (self) {
        [self setUnReadCount:0];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSNumber numberWithInteger:self.unReadCount] forKey:UnreadCountKey];
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        [self setUnReadCount:[[aDecoder decodeObjectForKey:UnreadCountKey]integerValue]];
    }
    return self;
}
@end
