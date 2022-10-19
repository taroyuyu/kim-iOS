//
//  FindListViewController.m
//  HUT
//
//  Created by Lingyu on 16/2/27.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "FindListViewController.h"
//#import "TimeLineViewController.h"


typedef enum : NSUInteger {
    FindListItemTypeTimeLine,
} FindListItemType;
@interface FindListViewController ()

@end

@implementation FindListViewController

+(instancetype)findListViewController
{
    return [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"findListController"];
}

-(void)loadView
{
    [super loadView];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([indexPath section]) {
        case FindListItemTypeTimeLine:
//            [[self navigationController]pushViewController:[TimeLineViewController timeLineController] animated:YES];
            break;
    }
}

@end
