//
//  ProfileViewController.m
//  HUT
//
//  Created by Lingyu on 16/2/16.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "ProfileViewController.h"
#import "ProfileListViewController.h"

@interface ProfileViewController ()

@end

@implementation ProfileViewController

+(instancetype)profileViewController
{
    ProfileViewController *viewController = [[ProfileViewController alloc] initWithRootViewController:[ProfileListViewController profileListController]];
    [viewController setTitle:@"我"];
    [[viewController tabBarItem] setImage:[UIImage imageNamed:@"ic_tabbar_settings_normal"]];
    [[viewController tabBarItem] setSelectedImage:[UIImage imageNamed:@"ic_tabbar_settings_pressed"]];
    
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
