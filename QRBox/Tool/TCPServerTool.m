//
//  TCPServerTool.m
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/14.
//

#import "TCPServerTool.h"
#import "GCDAsyncSocket.h"

@interface TCPServerTool () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket *serverSocket;
@property (nonatomic, strong) GCDAsyncSocket *clientSocket;
@property (nonatomic, strong) NSMutableDictionary *heartDict;
@property (nonatomic, strong) NSMutableData *dataBuffer;
@property (nonatomic, strong) NSThread *checkThread;
@property (nonatomic, assign) long tag;

@end

@implementation TCPServerTool

+ (instancetype)shareInstance {
    static TCPServerTool *tool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tool = [self new];
    });
    return tool;
}

- (BOOL)listenOnPort:(uint16_t)port delegate:(id<TCPServerToolDelegate>)delegate {
    self.delegate = delegate;
    NSError *error;
    BOOL result = [self.serverSocket acceptOnPort:port error:&error];
    return result;
}

- (void)sendData:(NSData *)contentData to:(NSString *)client withTag:(long)tag {
    if(!self.clientSocket){
        return;
    }
    self.tag = tag;
    NSInteger dataLength = contentData.length;
    NSData *lengthData = [NSData dataWithBytes:&dataLength length:sizeof(dataLength)];
    NSData *headData = [lengthData subdataWithRange:NSMakeRange(0, 4)];
    NSMutableData *data = [NSMutableData dataWithData:headData];
    [data appendData:contentData];
    [self.clientSocket writeData:data withTimeout:-1 tag:tag];
}

- (void)disconnect {
    if(self.clientSocket && !self.clientSocket.isDisconnected){
        [self.clientSocket disconnect];
    }
    self.clientSocket = nil;
    self.serverSocket = nil;
}


#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    self.clientSocket = newSocket;
    if ([self.delegate respondsToSelector:@selector(socket: status:withError:)]) {
        [self.delegate socket:self status:(ConnectStatusConnected)withError:nil];
    }
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [self.dataBuffer appendData:data];
    while (self.dataBuffer.length >= 4) {
        NSInteger dataLength = 0;
        [[self.dataBuffer subdataWithRange:(NSMakeRange(0, 4))] getBytes:&dataLength length:sizeof(dataLength)];
        if (self.dataBuffer.length >= (dataLength+4)) {
            NSData *realData = [self.dataBuffer subdataWithRange:NSMakeRange(4, dataLength)];
            char hearBeat[4] = {0xab,0xcd,0x00,0x00};
            NSData *heartData = [NSData dataWithBytes:&hearBeat length:sizeof(hearBeat)];
            if ([realData isEqualToData:heartData]) {
                if (kStringIsEmpty(sock.connectedHost)) {
                    return;;
                } else {
                    //更新最新时间
                    self.heartDict[sock.connectedHost] = [NSDate date];
                }
            } else {
                if ([self.delegate respondsToSelector:@selector(socket: receiveData:)]) {
                    [self.delegate socket:self receiveData:realData];
                }
            }
            self.dataBuffer = [[self.dataBuffer subdataWithRange:NSMakeRange(4+dataLength, self.dataBuffer.length-4-dataLength)] mutableCopy];
            
        } else {
            break;
        }
    }
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (tag == -1) {
        return;
    } else {
        if ([self.delegate respondsToSelector:@selector(socket: withTag:)]) {
            [self.delegate socket:self withTag:tag];
        }
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err {
    if ([self.delegate respondsToSelector:@selector(socket: status:withError:)]) {
        [self.delegate socket:self status:(ConnectStatusDisconnected)withError:err];
    }
}


#pragma mark - Property

- (GCDAsyncSocket *)serverSocket {
    if (!_serverSocket) {
        _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    return _serverSocket;
}

- (NSMutableData *)dataBuffer {
    if (!_dataBuffer) {
        _dataBuffer = [NSMutableData data];
    }
    return _dataBuffer;
}


@end

