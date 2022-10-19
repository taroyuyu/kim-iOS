//
//  ContactToolBar.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/23.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "ContactToolBar.h"

@interface ContactToolBar()
@property(nonatomic,strong)UIButton * friendApplicationButton;
@property(nonatomic,strong)UILabel * friendApplicationLabel;
@property(nonatomic,strong)UIButton * chatGroupButton;
@property(nonatomic,strong)UILabel * chatGroupLabel;
@property(nonatomic,strong)UIView * bottomLine;
@end

@implementation ContactToolBar

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        [self addSubview:[self friendApplicationButton]];
        [self addSubview:[self friendApplicationLabel]];
        [self addSubview:[self chatGroupButton]];
        [self addSubview:[self chatGroupLabel]];
        [self addSubview:[self bottomLine]];
    }
    
    return self;
}

-(UIButton*)friendApplicationButton
{
    if (self->_friendApplicationButton) {
        return self->_friendApplicationButton;
    }
    
    self->_friendApplicationButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self->_friendApplicationButton setBounds:CGRectMake(0, 0, 48, 48)];
    [self->_friendApplicationButton setBackgroundImage:[UIImage imageNamed:@"addFriend"] forState:UIControlStateNormal];
    [self->_friendApplicationButton addTarget:self action:@selector(didFriendApplicationClicked:) forControlEvents:UIControlEventTouchUpInside];
    return self->_friendApplicationButton;
}

-(UILabel*)friendApplicationLabel
{
    if (self->_friendApplicationLabel) {
        return self->_friendApplicationLabel;
    }
    
    self->_friendApplicationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [self->_friendApplicationLabel setText:@"新的朋友"];
    
    return self->_friendApplicationLabel;
}

-(UIButton*)chatGroupButton
{
    if (self->_chatGroupButton) {
        return self->_chatGroupButton;
    }
    
    self->_chatGroupButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self->_chatGroupButton setBounds:CGRectMake(0, 0, 48, 48)];
    [self->_chatGroupButton setBackgroundImage:[UIImage imageNamed:@"groupIcon"] forState:UIControlStateNormal];
    [self->_chatGroupButton addTarget:self action:@selector(didChatGroupClicked:) forControlEvents:UIControlEventTouchUpInside];
    return self->_chatGroupButton;
}

-(UILabel*)chatGroupLabel
{
    if (self->_chatGroupLabel) {
        return self->_chatGroupLabel;
    }
    
    self->_chatGroupLabel = [[UILabel alloc]initWithFrame:CGRectZero];
    [self->_chatGroupLabel setText:@"群聊"];
    
    return self->_chatGroupLabel;
}

-(UIView*)bottomLine
{
    if (self->_bottomLine) {
        return self->_bottomLine;
    }
    
    self->_bottomLine = [[UIView alloc] initWithFrame:CGRectZero];
    [self->_bottomLine setBackgroundColor:[UIColor colorWithRed:236/255.0 green:237/255.0 blue:241/255.0 alpha:1.0f]];
    
    return self->_bottomLine;
}

-(void)didFriendApplicationClicked:(UIButton*)friendApplicationButton
{
    if ([[self delegate] respondsToSelector:@selector(didContactToolBarSelectedFriendApplicationItem:)]) {
        [[self delegate] didContactToolBarSelectedFriendApplicationItem:self];
    }
}

-(void)didChatGroupClicked:(UIButton*)chatGroupButton
{
    if ([[self delegate] respondsToSelector:@selector(didContactToolBarSelectedChatGroupItem:)]) {
        [[self delegate] didContactToolBarSelectedChatGroupItem:self];
    }
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize contentSize = [self bounds].size;
    
    CGFloat horizonInterval = (contentSize.width - self.friendApplicationButton.bounds.size.width - self.chatGroupButton.bounds.size.width)/3;
    
    [[self friendApplicationLabel] sizeToFit];
    [[self chatGroupLabel] sizeToFit];
    
    [[self friendApplicationButton] setCenter:CGPointMake(horizonInterval + self.friendApplicationButton.bounds.size.width/2, contentSize.height/2)];
    [[self friendApplicationLabel] setCenter:CGPointMake(self.friendApplicationButton.center.x, CGRectGetMaxY(self.friendApplicationButton.frame) + self.friendApplicationLabel.bounds.size.height/2)];
    [[self chatGroupButton] setCenter:CGPointMake(contentSize.width - (self.chatGroupButton.bounds.size.width/2 + horizonInterval),contentSize.height/2)];
    [[self chatGroupLabel] setCenter:CGPointMake(self.chatGroupButton.center.x, CGRectGetMaxY(self.chatGroupButton.frame) + self.chatGroupLabel.bounds.size.height/2)];
 
    [[self bottomLine] setFrame:CGRectMake(0, contentSize.height-1, contentSize.width, 1)];
}

@end
