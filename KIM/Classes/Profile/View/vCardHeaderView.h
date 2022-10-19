//
//  vCardHeaderView.h
//  HUTLife
//
//  Created by Lingyu on 16/4/17.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <UIKit/UIKit.h>
@class vCardHeaderView;
@class KIMUserVCard;

typedef enum : NSUInteger {
    VCardHeaderViewEventAvatorClicked,
} VCardHeaderViewEvent;

@interface vCardHeaderView : UIView
@property(nonatomic,strong)KIMUserVCard *model;
@end
