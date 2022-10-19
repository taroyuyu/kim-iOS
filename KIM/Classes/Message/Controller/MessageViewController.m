//
//  MessageViewController.m
//  HUTLife
//
//  Created by Lingyu on 16/3/7.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "MessageViewController.h"
#import "MessageListViewController.h"

@interface MessageViewController ()

@end

@implementation MessageViewController

+(instancetype)messageController
{
    MessageViewController *viewController = [[MessageViewController alloc] initWithRootViewController:[MessageListViewController messageListController]];
    [viewController setTitle:@"消息"];
    [[viewController tabBarItem] setImage:[UIImage imageNamed:@"icon_chat"]];
    [[viewController tabBarItem] setSelectedImage:[UIImage imageNamed:@"icon_chat_active"]];
    return viewController;
}


-(void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSInteger currentChildViewController = [[self childViewControllers] count];
    
    if (currentChildViewController == 1) {
        [[[self tabBarController] tabBar] setHidden:YES];
    }
    [super pushViewController:viewController animated:animated];
    
}

-(UIViewController*)popViewControllerAnimated:(BOOL)animated
{
    UIViewController *previousViewController = [super popViewControllerAnimated:animated];
    
    NSInteger currentChildViewController = [[self childViewControllers] count];
    
    if (currentChildViewController == 1) {
        [[[self tabBarController] tabBar] setHidden:NO];
    }
    
    return previousViewController;
}

- (nullable NSArray<__kindof UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSArray *popViewControllers = [super popToViewController:viewController animated:animated];
    
    NSInteger currentChildViewController = [[self childViewControllers] count];
    
    if (currentChildViewController == 1) {
        [[[self tabBarController] tabBar] setHidden:NO];
    }
    
    
    return popViewControllers;
}

- (nullable NSArray<__kindof UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated
{
    NSArray *popViewControllers = [super popToRootViewControllerAnimated:animated];
    
    [[[self tabBarController] tabBar] setHidden:NO];
    
    return popViewControllers;
}


@end
