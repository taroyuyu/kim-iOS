//
//  KakaIMMessageAdapter.m
//  KakaIM
//
//  Created by taroyuyu on 2018/4/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import "KIMMessageAdapter.h"
#import "KIMProtobufMessageFactory.h"
@implementation KIMMessageAdapter
struct KIMDatagram{
    uint32_t dataGramLength;//数据包长度 = size(dataGramLength) + sizeof(messageTypeNameLength) + messageTypeNameLength + sizeof(protobufDataLength) + protobufDataLength
    uint32_t messageTypeNameLength;//消息类型名称长度
    char * messageTypeName;//消息类型名称
    uint32_t protobufDataLength;//protobuf数据长度
    uint8_t * protobufData;//protobuf数据
};
- (void)encapsulateMessageToByteStream:(GPBMessage * const)message outputBuffer:(KIMCircleBuffer * const)outputBuffer
{
    //1.判断消息是否进行了初始化
    if(false ==  [message isInitialized]){
        return;
    }
    //2.封装
    static struct KIMDatagram datagram;
    memset(&datagram,0, sizeof(datagram));
    datagram.messageTypeNameLength = [[[message descriptor] fullName] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    datagram.messageTypeName = malloc(sizeof(char) * datagram.messageTypeNameLength);
    strcpy(datagram.messageTypeName,[[[message descriptor] fullName] UTF8String]);
    datagram.protobufDataLength = [message serializedSize];
    datagram.protobufData = malloc(sizeof(uint8_t) * datagram.protobufDataLength);
    [[message data] getBytes:datagram.protobufData length:datagram.protobufDataLength];
    
    datagram.dataGramLength = sizeof(datagram.dataGramLength) + sizeof(datagram.messageTypeNameLength)+datagram.messageTypeNameLength+
    sizeof(datagram.protobufDataLength)+datagram.protobufDataLength;
    //3.将KakaIMDatagram.messageTypeNameLength和将KakaIMDatagram.protobufDataLength转换成网络字节序
    datagram.dataGramLength = htonl(datagram.dataGramLength);
    datagram.messageTypeNameLength = htonl(datagram.messageTypeNameLength);
    datagram.protobufDataLength = htonl(datagram.protobufDataLength);
    //4.将字节流按顺序插入到缓冲区1
    [outputBuffer appendContent:&datagram.dataGramLength bufferLength:sizeof(datagram.dataGramLength)];
    [outputBuffer appendContent:&datagram.messageTypeNameLength bufferLength:sizeof(datagram.messageTypeNameLength)];
    [outputBuffer appendContent:datagram.messageTypeName bufferLength:ntohl(datagram.messageTypeNameLength)];
    [outputBuffer appendContent:&datagram.protobufDataLength bufferLength:sizeof(datagram.protobufDataLength)];
    [outputBuffer appendContent:datagram.protobufData bufferLength:ntohl(datagram.protobufDataLength)];
    //5.释放datagram的内存空间
    free(datagram.messageTypeName);
    free(datagram.protobufData);
}
- (bool)tryToretriveMessage:(KIMCircleBuffer * const) inputBuffer message:(GPBMessage ** const)message
{
    //1.从输入缓冲中提取前面几个字节，判断下一条消息的长度
    struct KIMDatagram datagram;
    [inputBuffer headWithBuffer:&datagram.dataGramLength bufferLength:sizeof(datagram.dataGramLength)];
    datagram.dataGramLength = ntohl(datagram.dataGramLength);
    
    if(inputBuffer.used >= sizeof(datagram.dataGramLength)){
        if (inputBuffer.used >= datagram.dataGramLength){//输入缓冲区中可能存在一条消息
            //1.提取消息长度并转换成主机字节序
            [inputBuffer retriveWithBuffer:&datagram.dataGramLength bufferLength:sizeof(datagram.dataGramLength)];
            datagram.dataGramLength = ntohl(datagram.dataGramLength);
            //2.提取消息类型名称长度并转换成主机字节序
            [inputBuffer retriveWithBuffer:&datagram.messageTypeNameLength bufferLength:sizeof(datagram.messageTypeNameLength)];
            datagram.messageTypeNameLength = ntohl(datagram.messageTypeNameLength);
            //3.提取消息类型名称
            datagram.messageTypeName = malloc(sizeof(char) * datagram.messageTypeNameLength);
            datagram.messageTypeName[sizeof(char) * datagram.messageTypeNameLength] = '\0';
            [inputBuffer retriveWithBuffer:datagram.messageTypeName bufferLength:datagram.messageTypeNameLength];
            //4.提取protobufData长度并转换成主机字节序
            [inputBuffer retriveWithBuffer:&datagram.protobufDataLength bufferLength:sizeof(datagram.protobufDataLength)];
            datagram.protobufDataLength = ntohl(datagram.protobufDataLength);
            //5.提取protobufData
            datagram.protobufData = malloc(sizeof(uint8_t) * datagram.protobufDataLength);
            [inputBuffer retriveWithBuffer:datagram.protobufData bufferLength:datagram.protobufDataLength];
            //6.根据messageTypeName创建消息，并进行反序列化
            NSData * data = [[NSData alloc] initWithBytes:datagram.protobufData length:datagram.protobufDataLength];
            GPBMessage * tmpMessage = [KIMProtobufMessageFactory createMessageWithFullName:[NSString stringWithUTF8String:datagram.messageTypeName] andData:data];

            //7.销毁Datagram的内存
            free(datagram.messageTypeName);
            free(datagram.protobufData);

            //8.判断消息是否初始化成功
            if([tmpMessage isInitialized]){
                *message = tmpMessage;
                return true;
            }else{
                return false;
            }
        }
    }
    return false;
}
@end
