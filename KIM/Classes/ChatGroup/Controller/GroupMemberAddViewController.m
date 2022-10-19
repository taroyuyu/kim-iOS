//
//  GroupMemberAddViewController.m
//  HUTLife
//
//  Created by Kakawater on 2018/12/25.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "GroupMemberAddViewController.h"
#import "KIMClient.h"
@interface GroupMemberAddViewController ()
/**
 *@description 通信录列表
 */
@property(nonatomic,strong)NSArray<KIMUser*> *contactList;
/**
 *@description 群成员列表
 */
@property(nonatomic,strong)NSArray<KIMUser*> * groupMemberList;
/**
 *@description x待添加的成员列表
 */
@property(nonatomic,strong)NSMutableArray<KIMUser*> *selectedUserList;
@end

@implementation GroupMemberAddViewController

static NSString * const ContactCellReuseIdentifier = @"ContactCell";

+(instancetype)groupMemberAddViewControllerWithChatGroup:(KIMChatGroup*)chatGroup
{
    GroupMemberAddViewController * viewController = [[GroupMemberAddViewController alloc] initWithStyle:UITableViewStylePlain];
    [viewController setChatGroup:chatGroup];
    return viewController;
}

-(NSArray<KIMUser*> *)contactList
{
    if (self->_contactList) {
        return self->_contactList;
    }
    
    self->_contactList = [NSArray<KIMUser*> array];
    
    return self->_contactList;
}

-(NSArray<KIMUser*> *)groupMemberList
{
    if (self->_groupMemberList) {
        return self->_groupMemberList;
    }
    
    self->_groupMemberList = [NSArray<KIMUser*> array];
    
    return self->_groupMemberList;
}
-(NSMutableArray<KIMUser*> *)selectedUserList
{
    if (self->_selectedUserList) {
        return self->_selectedUserList;
    }
    
    self->_selectedUserList = [NSMutableArray<KIMUser*> array];
    
    return self->_selectedUserList;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [[self navigationItem] setTitle:@"添加群成员"];
    [[self navigationItem] setLeftBarButtonItem:[[UIBarButtonItem alloc]initWithTitle:@"取消" style:(UIBarButtonItemStylePlain) target:self action:@selector(cancleButtonClicked)]];
    [[self navigationItem] setRightBarButtonItem:[[UIBarButtonItem alloc]initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonClicked)]];
    [[[self navigationItem] rightBarButtonItem] setEnabled:NO];
    
    //注册Cell
    [[self tableView] registerClass:[UITableViewCell class] forCellReuseIdentifier:ContactCellReuseIdentifier];
    
    //获取好友列表
    KIMRosterModule * rosterModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule;
    NSArray<KIMUser*> * friendList = [[rosterModule retriveFriendListFromLocalCache] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"account" ascending:YES]]];
    
    if (friendList.count) {
        self.contactList = [friendList copy];
    }
    
    self.groupMemberList = [[[[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule] retriveChatGroupMemberListFromLocalCache:self.chatGroup] copy];
    
    [self.tableView reloadData];
}

-(void)cancleButtonClicked
{
    [[self navigationController] popViewControllerAnimated:YES];
}

-(void)doneButtonClicked
{
    
    KIMChatGroupModule * chatGroupModule = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];
    for (KIMUser * user  in self.selectedUserList) {
        [chatGroupModule inviteUser:user toChatGroup:self.chatGroup];
    }
    [[self navigationController] popViewControllerAnimated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.contactList.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    KIMUser *contactModel = [[self contactList] objectAtIndex:[indexPath row]];
    
    KIMUserVCard * userVCard = [((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule retriveUserVCardFromLocalCache:contactModel];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ContactCellReuseIdentifier forIndexPath:indexPath];
    
    if (userVCard.avatar) {
         [[cell imageView] setImage:[UIImage imageWithData:userVCard.avatar]];
    }else{
        [[cell imageView] setImage:[UIImage imageNamed:@"branddefulthead"]];
    }
    
    if ([userVCard.nickName hasContent]) {
        [[cell textLabel] setText:userVCard.nickName];
    }else{
        [[cell textLabel] setText:userVCard.user.account];
    }
    
    if ([self.groupMemberList containsObject:contactModel]) {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    KIMUser *contactModel = [[self contactList] objectAtIndex:[indexPath row]];
    
    if ([self.groupMemberList containsObject:contactModel]) {
        return;
    }
    
    if ([self.selectedUserList containsObject:contactModel]) {
        [self.selectedUserList removeObject:contactModel];
        [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
    }else{
        [self.selectedUserList addObject:contactModel];
        [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    
    if ([self.selectedUserList count]) {
        [[[self navigationItem] rightBarButtonItem] setEnabled:YES];
    }else{
        [[[self navigationItem] rightBarButtonItem] setEnabled:NO];
    }
}
@end
