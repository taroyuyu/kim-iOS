//
//  ContactCell.m
//  HUTLife
//
//  Created by Lingyu on 16/4/6.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <objc/runtime.h>
#import "ContactCell.h"
#import "KIMUser.h"
#import "KIMUserVCard.h"

static NSObject * RelevantModelKey = nil;
@interface ContactCell ()
@end
@implementation ContactCell
+(void)load
{
    [super load];
    
    RelevantModelKey = [NSObject new];
}

+(instancetype)cellWithTableView:(UITableView *)tableView andModel:(KIMUser *)model
{
    
    static NSString *contactsCellIdentifier = @"contactsCell";
    ContactCell *contactsCell = [tableView dequeueReusableCellWithIdentifier:contactsCellIdentifier];
    
    if (nil==contactsCell) {
        contactsCell = [[ContactCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:contactsCellIdentifier];
    }
    
    [contactsCell setModel:model];
    return contactsCell;

}

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if (self) {
        [self loadSubviews];
    }
    
    return self;
}

-(void)loadSubviews
{
    [self addSubview:[self userAvator]];
    [self addSubview:[self userName]];
    [self addSubview:[self onlineState]];
}

-(UIImageView*)userAvator
{
    if (self->_userAvator) {
        return self->_userAvator;
    }
    
    self->_userAvator = [UIImageView new];
    [self->_userAvator setBounds:CGRectMake(0, 0, 40, 40)];
    [[self->_userAvator layer] setCornerRadius:20];
    [self->_userAvator setClipsToBounds:YES];
    
    return self->_userAvator;
}

-(UILabel*)userName
{
    if (self->_userName) {
        return self->_userName;
    }
    
    self->_userName = [UILabel new];
    
    return self->_userName;
}

-(UILabel*)onlineState
{
    if (self->_onlineState) {
        return self->_onlineState;
    }
    
    self->_onlineState = [UILabel new];
    [self->_onlineState setTextColor:[UIColor grayColor]];
    [self->_onlineState setFont:[UIFont systemFontOfSize:14]];
    return self->_onlineState;
}
-(void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat interval = 10;
    
    
    CGSize contentSize = [self bounds].size;
    //布局userAvator
    CGSize avatorSize = [[self userAvator] bounds].size;
    [[self userAvator] setCenter:CGPointMake(avatorSize.width/2 + interval, contentSize.height/2)];
    
    //布局userName
    [[self userName] sizeToFit];
    CGRect userNameFrame = [[self userName] frame];
    CGFloat userNamePostionX = CGRectGetMaxX([[self userAvator] frame]) + interval;
    CGFloat userNamePostionY = interval;
    [[self userName] setFrame:CGRectMake(userNamePostionX,userNamePostionY, userNameFrame.size.width, userNameFrame.size.height)];
    
    //布局onlineState
    [[self onlineState] sizeToFit];
    CGRect onlineStateFrame = [[self onlineState] frame];
    CGFloat onlineStatePostitionX = CGRectGetMaxX([[self userAvator] frame]) + interval;
    CGFloat onlineStatePositionY = CGRectGetMaxY([[self userName] frame]) + interval/2;
    [[self onlineState] setFrame:CGRectMake(onlineStatePostitionX, onlineStatePositionY, onlineStateFrame.size.width, onlineStateFrame.size.height)];
}
-(void)dealloc
{
    objc_setAssociatedObject(self, &RelevantModelKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

@end
