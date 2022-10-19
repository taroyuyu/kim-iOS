//
//  AboutViewController.m
//  HUT
//
//  Created by Lingyu on 16/2/19.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "AboutViewController.h"

@interface AboutViewController ()

@end

@implementation AboutViewController

+(instancetype)aboutController
{
    return [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"aboutController"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:@"关于软件"];
}

@end
