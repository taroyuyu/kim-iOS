//
//  ChatGroupSessionMessageModel.m
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "ChatGroupSessionMessageModel.h"

@interface ChatGroupSessionMessageModel ()
{
    MessageType _type;
}
@end

@implementation ChatGroupSessionMessageModel
static NSString * const GroupIdKey = @"groupId";
static NSString * const GroupNameKey = @"groupName";
static NSString * const GroupIconKey = @"groupIcon";
static NSString * const ContentKey = @"content";
-(instancetype)init
{
    self = [super init];
    if (self) {
        self->_type = MessageType_ChatGroupSession;
    }
    
    return self;
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder{ // NS_DESIGNATED_INITIALIZER
    self = [super initWithCoder:aDecoder];
    if (self) {
        self->_type = MessageType_ChatGroupSession;
        [self setGroupId:[aDecoder decodeObjectForKey:GroupIdKey]];
        [self setGroupName:[aDecoder decodeObjectForKey:GroupNameKey]];
        [self setGroupIcon:[aDecoder decodeObjectForKey:GroupIconKey]];
        [self setContent:[aDecoder decodeObjectForKey:ContentKey]];
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
    [aCoder encodeObject:self.groupId forKey:GroupIdKey];
    [aCoder encodeObject:self.groupName forKey:GroupNameKey];
    [aCoder encodeObject:self.groupIcon forKey:GroupIconKey];
    [aCoder encodeObject:self.content forKey:ContentKey];
}
@end
