//
//  ChatSessionMessageModel.m
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "ChatSessionMessageModel.h"

@interface ChatSessionMessageModel ()
{
    MessageType _type;
}
@end

@implementation ChatSessionMessageModel
static NSString * const PeerAccountKey = @"peerAccount";
static NSString * const NickNameKey = @"nickName";
static NSString * const AvatarKey = @"avatar";
static NSString * const ContentKey = @"content";
-(instancetype)init
{
    self = [super init];
    if (self) {
        self->_type = MessageType_ChatSession;
    }
    
    return self;
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder{ // NS_DESIGNATED_INITIALIZER
    self = [super initWithCoder:aDecoder];
    if(self){
        self->_type = MessageType_ChatSession;
        [self setPeerAccount:[aDecoder decodeObjectForKey:PeerAccountKey]];
        [self setNickName:[aDecoder decodeObjectForKey:NickNameKey]];
        [self setAvatar:[aDecoder decodeObjectForKey:AvatarKey]];
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
    [aCoder encodeObject:self.peerAccount forKey:PeerAccountKey];
    [aCoder encodeObject:self.nickName forKey:NickNameKey];
    [aCoder encodeObject:self.avatar forKey:AvatarKey];
    [aCoder encodeObject:self.content forKey:ContentKey];
}
@end
