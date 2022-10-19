//
//  MainViewController.m
//  HUT
//
//  Created by Lingyu on 16/2/16.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "MainViewController.h"
#import "MessageViewController.h"
#import "ContactViewController.h"
#import "FindViewController.h"
#import "ProfileViewController.h"
#import "VideoChatViewController.h"

@interface MainViewController()<KIMVideoChatModuleDelegate>
@property(nonatomic,strong)KIMVideoChatRequest * processingVideoChatRequest;
@property(nonatomic,strong)NSTimer * ringTimer;
@end

@implementation MainViewController


/**
 *加载子控制器
 */
-(void)loadChildControllers
{
    [self addChildViewController:[MessageViewController messageController]];
    [self addChildViewController:[ContactViewController contactController]];
    [self addChildViewController:[FindViewController findViewController]];
    [self addChildViewController:[ProfileViewController profileViewController]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadChildControllers];
    
    [[[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] videoChatModule] addDelegate:self];
}

-(void)didKIMVideoChatModule:(KIMVideoChatModule*)videoChatModule receivedVideoChatRequest:(KIMVideoChatRequest*)videoChatRequest
{
    [self setProcessingVideoChatRequest:videoChatRequest];
    [self presentViewController:[VideoChatViewController ringFrom:videoChatRequest] animated:YES completion:nil];
}
-(void)didKIMVideoChatModule:(KIMVideoChatModule*)videoChatModule receivedVideoChatRequestCancel:(KIMVideoChatRequest*)videoChatRequest
{
    if (self.processingVideoChatRequest.offerId == videoChatRequest.offerId) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self setProcessingVideoChatRequest:nil];
        }];
    }
}
-(void)dealloc
{
    [[[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] videoChatModule] removeDelegate:self];
}
@end
