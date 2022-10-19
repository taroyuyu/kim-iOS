//
//  FindViewController.m
//  HUT
//
//  Created by Lingyu on 16/2/27.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "FindViewController.h"
#import "FindListViewController.h"

@interface FindViewController ()

@end

@implementation FindViewController

+(instancetype)findViewController
{
    FindViewController *viewController = [[FindViewController alloc] initWithRootViewController:[FindListViewController findListViewController]];
    [[viewController tabBarItem] setImage:[UIImage imageNamed:@"tabbar_discover"]];
    [[viewController tabBarItem] setSelectedImage:[UIImage imageNamed:@"tabbar_discoverHL"]];
    [viewController setTitle:@"发现"];
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
