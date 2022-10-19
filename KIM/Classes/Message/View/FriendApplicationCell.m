//
//  FriendApplicationCell.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/23.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "FriendApplicationCell.h"

@interface FriendApplicationCell()
@property(nonatomic,strong)UIImageView *avatar;
@property(nonatomic,strong)UILabel * peerUserName;
@property(nonatomic,strong)UILabel * introduction;
@property(nonatomic,strong)UIButton * handleButton;
@end
@implementation FriendApplicationCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self) {
        [self addSubview:[self avatar]];
        [self addSubview:[self peerUserName]];
        [self addSubview:[self introduction]];
        [self addSubview:[self handleButton]];
    }
    
    return self;
}

-(UIImageView*)avatar
{
    if (self->_avatar) {
        return self->_avatar;
    }
    
    self->_avatar = [UIImageView new];
    CGSize flagImageViewSize = CGSizeMake(40, 40);
    [self->_avatar setBounds:CGRectMake(0, 0, flagImageViewSize.width, flagImageViewSize.height)];
    [[self->_avatar layer]setCornerRadius:flagImageViewSize.width/2];
    [self->_avatar setClipsToBounds:YES];
    
    return self->_avatar;
}

-(UILabel*)peerUserName
{
    if (self->_peerUserName) {
        return self->_peerUserName;
    }
    
    self->_peerUserName = [[UILabel alloc] init];
    
    return self->_peerUserName;
}

-(UILabel*)introduction
{
    if (self->_introduction) {
        return self->_introduction;
    }
    
    self->_introduction = [[UILabel alloc] init];
    
    return self->_introduction;
}

-(UIButton*)handleButton
{
    if (self->_handleButton) {
        return self->_handleButton;
    }
    
    self->_handleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self->_handleButton setBounds:CGRectMake(0, 0, 100, 36)];
    return self->_handleButton;
}
-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat interval = 10;
    
    CGSize contentSize = [self bounds].size;
    
    //布局flagImageView
    CGSize avatarViewSize = [[self avatar] bounds].size;
    [[self avatar] setCenter:CGPointMake(avatarViewSize.width/2 + interval, contentSize.height/2)];
    
    //布局flageLabel
    [[self peerUserName] sizeToFit];
    CGSize peerUserNameLabelSize = [[self peerUserName] bounds].size;
    CGFloat peerUserNameLabelMarginTop = interval * 1.5;
    CGFloat peerUserNameLabelMarginLeft = CGRectGetMaxX([[self avatar] frame]) + interval;
    [[self peerUserName] setFrame:CGRectMake(peerUserNameLabelMarginLeft, peerUserNameLabelMarginTop, peerUserNameLabelSize.width, peerUserNameLabelSize.height)];
    
    //布局promptLael
    [[self introduction] sizeToFit];
    CGSize introductionLabelSize = [[self introduction] bounds].size;
    CGFloat introductionLabelMarginLeft = CGRectGetMaxX([[self avatar] frame]) + interval;
    CGFloat introductionLabelMarginTop = CGRectGetMaxY([[self peerUserName] frame]) + interval/2;
    [[self introduction] setFrame:CGRectMake(introductionLabelMarginLeft, introductionLabelMarginTop, introductionLabelSize.width, introductionLabelSize.height)];
    
    //布局handleButton
    CGSize handleButtonSize = [[self handleButton] bounds].size;
    [[self handleButton] setCenter:CGPointMake(contentSize.width - (handleButtonSize.width/2 + interval), contentSize.height/2)];
}

@end
