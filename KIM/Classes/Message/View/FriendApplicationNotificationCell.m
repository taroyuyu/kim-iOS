//
//  FriendApplicationNotificationCell.m
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "FriendApplicationNotificationCell.h"
@interface FriendApplicationNotificationCell()
/**
 *@ddescription 徽章
 */
@property(nonatomic,strong)UIImageView *iconView;
/**
 *@description 标题
 */
@property(nonatomic,strong)UILabel *titleLabel;
/**
 *@description 提示
 */
@property(nonatomic,strong)UILabel *promptLabel;
@property(nonatomic,strong)UILabel * badgeValueLabel;
@end
@implementation FriendApplicationNotificationCell
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self) {
        [self addSubview:[self iconView]];
        [self addSubview:[self titleLabel]];
        [self addSubview:[self promptLabel]];
        [self addSubview:[self badgeValueLabel]];
    }
    
    return self;
}
-(UIImageView*)iconView
{
    if (self->_iconView) {
        return self->_iconView;
    }
    self->_iconView = [UIImageView new];
    CGSize iconViewSize = CGSizeMake(40, 40);
    [self->_iconView setBounds:CGRectMake(0, 0, iconViewSize.width, iconViewSize.height)];
    [self->_iconView setImage:[UIImage imageNamed:@"aio_buddy_validate_icon"]];
    [[self->_iconView layer]setCornerRadius:iconViewSize.width/2];
    [self->_iconView setClipsToBounds:YES];
    return self->_iconView;
}

-(UILabel*)titleLabel
{
    if (self->_titleLabel) {
        return self->_titleLabel;
    }
    
    self->_titleLabel = [UILabel new];
    return self->_titleLabel;
}

-(UILabel*)promptLabel
{
    if (self->_promptLabel) {
        return self->_promptLabel;
    }
    
    self->_promptLabel = [UILabel new];
    
    return self->_promptLabel;
}
-(UILabel*)badgeValueLabel
{
    if(self->_badgeValueLabel){
        return self->_badgeValueLabel;
    }
    
    self->_badgeValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 24, 24)];
    [[self->_badgeValueLabel layer] setCornerRadius:self->_badgeValueLabel.bounds.size.width/2.0];
    [self->_badgeValueLabel setClipsToBounds:YES];
    [self->_badgeValueLabel setBackgroundColor:[UIColor redColor]];
    [self->_badgeValueLabel setTextColor:[UIColor whiteColor]];
    [self->_badgeValueLabel setTextAlignment:NSTextAlignmentCenter];
    return self->_badgeValueLabel;
}
-(void)setModel:(FriendApplicationNotificationMessageModel *)model
{
    self->_model = model;
    
    switch (model.peerRole) {
        case FriendApplicationPeerRole_Sponsor:
        {
            [self.promptLabel setText:[NSString stringWithFormat:@"%@想添加你为好友",model.peerAccount]];
        }
            break;
        case FriendApplicationPeerRole_Target:
        {
            [self.promptLabel setText:[NSString stringWithFormat:@"添加%@为好友",model.peerAccount]];
        }
            break;
        default:
            break;
    }
    
    if (model.unReadCount) {
        [[self badgeValueLabel] setHidden:NO];
        [[self badgeValueLabel] setText:[NSString stringWithFormat:@"%ld",model.unReadCount]];
    }else{
        [[self badgeValueLabel] setHidden:YES];
    }
    
    [self setNeedsLayout];
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat interval = 10;
    
    CGSize contentSize = [self bounds].size;
    
    //布局flagImageView
    CGSize iconViewSize = [[self iconView] bounds].size;
    [[self iconView] setCenter:CGPointMake(iconViewSize.width/2 + interval, contentSize.height/2)];
    
    //布局badgeLabel
    CGSize badgeLabelSize = [[self badgeValueLabel] bounds].size;
    [[self badgeValueLabel] setCenter:CGPointMake(contentSize.width-(interval + badgeLabelSize.width/2), contentSize.height/2)];
    
    //布局flageLabel
    [[self titleLabel] sizeToFit];
    CGSize titleLaelSize = [[self titleLabel] bounds].size;
    CGFloat flagLabelMarginTop = interval * 1.5;
    CGFloat flagLabelMarginLeft = CGRectGetMaxX([[self iconView] frame]) + interval;
    [[self titleLabel] setFrame:CGRectMake(flagLabelMarginLeft, flagLabelMarginTop, titleLaelSize.width, titleLaelSize.height)];
    
    //布局promptLael
    [[self promptLabel] sizeToFit];
    CGSize promptLabelSize = [[self promptLabel] bounds].size;
    CGFloat promptLabelMarginLeft = CGRectGetMaxX([[self iconView] frame]) + interval;
    CGFloat promptLabelMarginTop = CGRectGetMaxY([[self titleLabel] frame]) + interval/2;
    [[self promptLabel] setFrame:CGRectMake(promptLabelMarginLeft, promptLabelMarginTop, promptLabelSize.width, promptLabelSize.height)];
    
}
@end
