//
//  KIMProtobufMessageFactory.m
//  KakaIM
//
//  Created by taroyuyu on 2018/4/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMProtobufMessageFactory.h"
#import "KakaImmessage.pbobjc.h"
#import "KakaImclientPresident.pbobjc.h"
@implementation KIMProtobufMessageFactory
static NSMutableDictionary<NSString*,Class> * messageDB = nil;
+(void)initialize
{
    //注册消息
    if (messageDB == nil) {
        messageDB = [[NSMutableDictionary<NSString*,Class> alloc] init];
    }
    
    [messageDB setObject:[KIMProtoRequestSessionIDMessage class] forKey:[[KIMProtoRequestSessionIDMessage descriptor] fullName]];
    [messageDB setObject:[KIMProtoResponseSessionIDMessage class] forKey:[[KIMProtoResponseSessionIDMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoLoginMessage class] forKey:[[KIMProtoLoginMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoResponseLoginMessage class] forKey:[[KIMProtoResponseLoginMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoRegisterMessage class] forKey:[[KIMProtoRegisterMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoResponseRegisterMessage class] forKey:[[KIMProtoResponseRegisterMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoHeartBeatMessage class] forKey:[[KIMProtoHeartBeatMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoResponseHeartBeatMessage class] forKey:[[KIMProtoResponseHeartBeatMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoLogoutMessage class] forKey:[[KIMProtoLogoutMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoResponseLogoutMessage class] forKey:[[KIMProtoResponseLogoutMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoBuildingRelationshipRequestMessage class] forKey:[[KIMProtoBuildingRelationshipRequestMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoBuildingRelationshipAnswerMessage class] forKey:[[KIMProtoBuildingRelationshipAnswerMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoDestroyingRelationshipRequestMessage class] forKey:[[KIMProtoDestroyingRelationshipRequestMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatRequestCancelMessage class] forKey:[[KIMProtoVideoChatRequestCancelMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatOfferMessage class] forKey:[[KIMProtoVideoChatOfferMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatAnswerMessage class] forKey:[[KIMProtoVideoChatAnswerMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatNegotiationResultMessage class] forKey:[[KIMProtoVideoChatNegotiationResultMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatCandidateAddressMessage class] forKey:[[KIMProtoVideoChatCandidateAddressMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatByeMessage class] forKey:[[KIMProtoVideoChatByeMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoDestoryingRelationshipResponseMessage class] forKey:[[KIMProtoDestoryingRelationshipResponseMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoFriendListRequestMessage class] forKey:[[KIMProtoFriendListRequestMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoFriendListItem class] forKey:[[KIMProtoFriendListItem descriptor]fullName]];
    [messageDB setObject:[KIMProtoFriendListResponseMessage class] forKey:[[KIMProtoFriendListResponseMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoOnlineStateMessage class] forKey:[[KIMProtoOnlineStateMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatMessage class] forKey:[[KIMProtoChatMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatRequestMessage class] forKey:[[KIMProtoVideoChatRequestMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoVideoChatReplyMessage class] forKey:[[KIMProtoVideoChatReplyMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoNotificationMessage class] forKey:[[KIMProtoNotificationMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoPullChatMessage class] forKey:[[KIMProtoPullChatMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoFetchUserVCardMessage class] forKey:[[KIMProtoFetchUserVCardMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoUserVCardResponseMessage class] forKey:[[KIMProtoUserVCardResponseMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoUpdateUserVCardMessage class] forKey:[[KIMProtoUpdateUserVCardMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoUpdateUserVCardMessageResponse class] forKey:[[KIMProtoUpdateUserVCardMessageResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupCreateRequest class] forKey:[[KIMProtoChatGroupCreateRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupCreateResponse class] forKey:[[KIMProtoChatGroupCreateResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupDisbandRequest class] forKey:[[KIMProtoChatGroupDisbandRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupDisbandResponse class] forKey:[[KIMProtoChatGroupDisbandResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupJoinRequest class] forKey:[[KIMProtoChatGroupJoinRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupJoinResponse class] forKey:[[KIMProtoChatGroupJoinResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupQuitRequest class] forKey:[[KIMProtoChatGroupQuitRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoChatGroupQuitResponse class] forKey:[[KIMProtoChatGroupQuitResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoUpdateChatGroupInfoRequest class] forKey:[[KIMProtoUpdateChatGroupInfoRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoUpdateChatGroupInfoResponse class] forKey:[[KIMProtoUpdateChatGroupInfoResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoFetchChatGroupInfoRequest class] forKey:[[KIMProtoFetchChatGroupInfoRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoFetchChatGroupInfoResponse class] forKey:[[KIMProtoFetchChatGroupInfoResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoFetchChatGroupMemberListRequest class] forKey:[[KIMProtoFetchChatGroupMemberListRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoFetchChatGroupMemberListResponse class] forKey:[[KIMProtoFetchChatGroupMemberListResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoFetchChatGroupListRequest class] forKey:[[KIMProtoFetchChatGroupListRequest descriptor]fullName]];
    [messageDB setObject:[KIMProtoFetchChatGroupListResponse class] forKey:[[KIMProtoFetchChatGroupListResponse descriptor]fullName]];
    [messageDB setObject:[KIMProtoGroupChatMessage class] forKey:[[KIMProtoGroupChatMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoPullGroupChatMessage class] forKey:[[KIMProtoPullGroupChatMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoRequestNodeMessage class] forKey:[[KIMProtoRequestNodeMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoResponseNodeMessage class] forKey:[[KIMProtoResponseNodeMessage descriptor]fullName]];
    [messageDB setObject:[KIMProtoResponseLoginMessage class] forKey:[[KIMProtoResponseLoginMessage descriptor]fullName]];
}
+(GPBMessage*)createMessageWithFullName:(NSString*)fullName andData:(NSData*)data
{
    if (messageDB) {
        Class messageClass = [messageDB objectForKey:fullName];
        if (messageClass) {
            NSError * error = nil;
            GPBMessage * message = [[messageClass alloc] initWithData:data error:&error];
            if (error) {
                return nil;
            }else{
                
                return message;
            }
        }else{
            return nil;
        }
    }else{
        return nil;
    }
}
@end
