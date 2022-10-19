//
//  FriendApplicationNotificationMessageModel.m
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "FriendApplicationNotificationMessageModel.h"

@interface FriendApplicationNotificationMessageModel ()
{
    MessageType _type;
}
@end

@implementation FriendApplicationNotificationMessageModel
static NSString * const ApplicationIdKey = @"applicationId";
static NSString * const PeerRoleKey = @"peerRole";
static NSString * const PeerAccountKey = @"peerAccount";
static NSString * const IntroductionKey = @"introduction";
-(instancetype)init
{
    self = [super init];
    if (self) {
        self->_type = MessageType_FriendApplication;
    }
    
    return self;
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder{ // NS_DESIGNATED_INITIALIZER
    self = [super initWithCoder:aDecoder];
    if (self) {
        self->_type = MessageType_FriendApplication;
        [self setApplicationId:[aDecoder decodeObjectForKey:ApplicationIdKey]];
        [self setPeerRole:[[aDecoder decodeObjectForKey:PeerAccountKey]integerValue]];
        [self setPeerAccount:[aDecoder decodeObjectForKey:PeerAccountKey]];
        [self setIntroduction:[aDecoder decodeObjectForKey:IntroductionKey]];
    }
    
    return self;
}
-(MessageType)type
{
    return self->_type;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
        [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.applicationId forKey:ApplicationIdKey];
    [aCoder encodeObject:[NSNumber numberWithInteger:self.peerRole] forKey:PeerRoleKey];
    [aCoder encodeObject:self.peerAccount forKey:PeerAccountKey];
    [aCoder encodeObject:self.introduction forKey:IntroductionKey];
}
@end
