//
//  vCardHeaderView.m
//  HUTLife
//
//  Created by Lingyu on 16/4/17.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "vCardHeaderView.h"
#import "KIMUserVCard.h"
@interface vCardHeaderView ()
@property(nonatomic,strong)UIImageView *avatorPicture;
@property(nonatomic,strong)UILabel *nameLabel;
@end

@implementation vCardHeaderView
-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        [self loadSubviews];
    }
    
    return self;
}

-(void)loadSubviews
{
    [self addSubview:[self avatorPicture]];
    [self addSubview:[self nameLabel]];
}

-(UIImageView*)avatorPicture
{
    if (self->_avatorPicture) {
        return self->_avatorPicture;
    }
    
    CGSize avatorSize = CGSizeMake(80, 80);
    
    self->_avatorPicture = [UIImageView new];
    [self->_avatorPicture setImage:[UIImage imageNamed:@"normal_avatar"]];
    [self->_avatorPicture setBounds:CGRectMake(0, 0, avatorSize.width, avatorSize.height)];
    [[self->_avatorPicture layer] setCornerRadius:avatorSize.width/2];
    [self->_avatorPicture setContentMode:UIViewContentModeScaleAspectFill];
    [self->_avatorPicture setClipsToBounds:YES];
    return self->_avatorPicture;
}
-(UILabel*)nameLabel
{
    if (self->_nameLabel) {
        return self->_nameLabel;
    }
    
    self->_nameLabel = [UILabel new];
    [self->_nameLabel setTextAlignment:NSTextAlignmentCenter];
    [self->_nameLabel setTextColor:[UIColor whiteColor]];
    
    return self->_nameLabel;
}

-(void)setModel:(KIMUserVCard *)model
{
    self->_model = model;
    [self loadModelInfo];
}

-(void)loadModelInfo
{
    if ([[self model] avatar]) {
        [[self avatorPicture] setImage:[UIImage imageWithData:[[self model] avatar]]];
    }else{
        [[self avatorPicture] setImage:[UIImage imageNamed:@"normal_avatar"]];
    }
    
    if ([[[self model] nickName] hasContent]) {
        [[self nameLabel] setText:[[self model] nickName]];
    }else{
        [[self nameLabel] setText:self.model.user.account];
    }
}


-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize contentSize = [self bounds].size;
    
    CGFloat interval = 5;
    
    //布局avatorPicture
    [[self avatorPicture] setCenter:CGPointMake(contentSize.width/2, contentSize.height/2)];
    
    //布局nameLabel
    CGFloat nameLabelHeight = 44;
    [[self nameLabel] setFrame:CGRectMake(0, CGRectGetMaxY([[self avatorPicture] frame]) + interval, contentSize.width, nameLabelHeight)];
}

@end
