//
//  QRMainViewController.m
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/13.
//

#import "QRMainViewController.h"
#import "Masonry.h"
#import "PrefixHeader.h"
#import "SGQRCode.h"
#import "LANTool.h"
#import <GCDAsyncSocket.h>
#import "TCPServerTool.h"
#import "FileEntry.h"
#import <sys/sysctl.h>

#define CHUNK_SIZE (1024 * 1024) // 1MB 的块大小
static NSString * const LISTEN_START = @"LISTEN_START";

@interface QRMainViewController () <GCDAsyncSocketDelegate, TCPServerToolDelegate>

// UI
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *containerShadowView;
@property (nonatomic, strong) UILabel *stepLabel;
@property (nonatomic, strong) UIImageView *QRcode;
@property (nonatomic, strong) UIImageView *scanImageView;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UILabel *tipLabel;

// 网络与传输
@property (nonatomic, assign) int port;
@property (nonatomic, assign) long sentTag;
@property (nonatomic, assign) long currentTag;
@property (nonatomic, assign) BOOL connStatus;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL hasStartedSending;

// 文件传输
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSFileHandle *> *fileHandles;
@property (nonatomic, assign) UInt64 totalFilesSize;
@property (nonatomic, assign) UInt64 sentFilesSize;
@property (nonatomic, strong) NSMutableArray<NSString *> *filePathsQueue;
@property (nonatomic, strong) dispatch_queue_t sendingQueue;
@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, assign) long windowSize;

@end

@implementation QRMainViewController

NSString *findVersionPath(NSString *path) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    
    if (isExist && isDir) {
        NSArray *dirArray = [fileManager contentsOfDirectoryAtPath:path error:nil];
        for (NSString *str in dirArray) {
            NSString *subPath = [path stringByAppendingPathComponent:str];
            BOOL isSubDir = NO;
            [fileManager fileExistsAtPath:subPath isDirectory:&isSubDir];
            if (isSubDir) {
                if ([subPath containsString:@"/8.0."] && ![subPath containsString:@"/Apps"]) {
                    return subPath;
                }
                else {
                    return findVersionPath(subPath);
                }
            } else {
            }
        }
    } else {
    }
    return NULL;
}

NSString *findUserPath(void) {
    NSFileManager *mgr = [NSFileManager defaultManager];
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    
    NSRange range = [library rangeOfString:@"0xe4893f"];
    NSString *oaaLibrary = NULL;
    if (range.location != NSNotFound) {
        oaaLibrary = [library substringToIndex:range.location + range.length];
    } else {
        return NULL;
    }
    
    NSArray *dirArray = [mgr contentsOfDirectoryAtPath:oaaLibrary error:nil];
    for (NSString *dir in dirArray) {
        NSString *verPath = findVersionPath([oaaLibrary stringByAppendingPathComponent:dir]);
        if (verPath) {
            NSString *userPath = [verPath stringByAppendingPathComponent:@"007"];
            return userPath;
        }
    }
    return NULL;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setUpHUD];
    [self setupUI];
    self.title = @"数据迁移";
    
    // 初始化队列与状态
    self.sendingQueue = dispatch_queue_create("com.webox.sendingQueue", DISPATCH_QUEUE_SERIAL);
    self.fileHandles = [NSMutableDictionary dictionary];
    self.filePathsQueue = [NSMutableArray array];
    self.condition = [[NSCondition alloc] init];
    
    int64_t memorySize = 0;
    size_t size = sizeof(memorySize);
    sysctlbyname("hw.memsize", &memorySize, &size, NULL, 0);
    if (memorySize >= (4ULL * 1024 * 1024 * 1024)) { // 4GB+
        self.windowSize = 30;
    } else {
        self.windowSize = 10;
    }
    
    [self generateDynamicQRCode]; // 动态生成二维码
    self.sourceDirPath = findUserPath();
    NSLog(@"finally find user path %@", self.sourceDirPath);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationBarStyle];
}

- (void)setupNavigationBarStyle {
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor whiteColor];
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor blackColor],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:20]
    };
    
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
}

- (void)setUpHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD setBackgroundColor:RGBA(0, 0, 0, 0.5)];
        [SVProgressHUD setFont:[UIFont fontWithName:@"PingFang SC" size:16]];
        [SVProgressHUD setForegroundColor:[UIColor whiteColor]];
        [SVProgressHUD setMinimumSize:CGSizeMake(200, 120)];
        [SVProgressHUD setCornerRadius:15];
        [SVProgressHUD setMaximumDismissTimeInterval:0.8];
    });
}

- (void)dealloc {
    [[TCPServerTool shareInstance] disconnect];
    [TCPServerTool shareInstance].delegate = nil;
}


#pragma mark - setupUI

- (void)setupUI {
    self.view.backgroundColor = RGBA(238, 238, 238, 1);
    [self addAllSubviews];
    [self addAllConstraints];
}

- (void)addAllSubviews {
    [self.view addSubview:self.containerShadowView];
    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.stepLabel];
    [self.containerView addSubview:self.saveButton];
    [self.containerView addSubview:self.QRcode];
    [self.containerView addSubview:self.scanImageView];
    [self.containerView addSubview:self.refreshButton];
    [self.view addSubview:self.tipLabel];
}

- (void)addAllConstraints {
    [_containerShadowView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(ZOOM(28));
        make.left.right.equalTo(self.view).inset(ZOOM(16));
        make.height.mas_equalTo(ZOOM(500));
    }];
    
    [_containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(ZOOM(20));
        make.left.right.equalTo(self.view).inset(ZOOM(16));
        make.height.mas_equalTo(ZOOM(500));
    }];
    
    [_stepLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.containerView).offset(ZOOM(16));
        make.left.right.equalTo(self.containerView).inset(ZOOM(10));
    }];
    
    [_QRcode mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.stepLabel.mas_bottom).offset(ZOOM(50));
        make.centerX.equalTo(self.containerView);
        make.size.mas_equalTo(ZOOM(180));
    }];
    
    [_scanImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.QRcode);
        make.size.mas_equalTo(ZOOM(200));
    }];
    
    [_saveButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.containerView).offset(ZOOM(-40));
        make.left.right.equalTo(self.containerView).inset(ZOOM(22));
        make.height.mas_equalTo(ZOOM(48));
    }];
    
    [_refreshButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.QRcode.mas_bottom).offset(ZOOM(20));
        make.centerX.equalTo(self.containerView);
        make.size.mas_equalTo(CGSizeMake(ZOOM(80), ZOOM(30)));
    }];
    
    [_tipLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.containerView.mas_bottom).offset(ZOOM(30));
        make.left.right.equalTo(self.view).inset(ZOOM(26));
    }];
}


#pragma mark - 动态生成二维码

- (void)generateDynamicQRCode {
    self.QRcode.image = nil; // 清除旧图，避免视觉残留
    
    // 获取本机IP（确保在WiFi环境下）
    NSString *ip = [LANTool getIPAddress:YES];
    if (!ip) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:@"请连接Wi-Fi"];
        });
        return;
    }
    _port = (arc4random() % 10000) + 20000; // 20000-30000随机端口
    
    // 生成连接字符串（Base64编码防特殊字符）
    NSString *connectionInfo = [NSString stringWithFormat:@"%@:%d", ip, _port];
    NSString *encodedInfo = [connectionInfo base64EncodedString];
    
    // 启动TCP服务端监听
    [self startTCPServerOnPort:_port];
    
    // 使用 SGQRCode 生成二维码
    UIImage *qrImage = [SGGenerateQRCode generateQRCodeWithData:encodedInfo size:(ZOOM(180))];
    if (!qrImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:@"二维码生成失败"];
        });
    }
    
    // 转换为PNG格式
    NSData *pngData = UIImagePNGRepresentation(qrImage);
    UIImage *qrPngImage = [UIImage imageWithData:pngData];
    
    // 生成二维码图片
    self.QRcode.image = qrPngImage;
}

- (void)refreshQRCode {
    // 如果已经建立连接并开始发送，不允许刷新
    if (self.hasStartedSending && self.connStatus) {
        [SVProgressHUD showErrorWithStatus:@"传输已开始，无法刷新"];
        return;
    }

    // 断开旧连接（如果存在）
    [[TCPServerTool shareInstance] disconnect];
    [TCPServerTool shareInstance].delegate = nil;

    // 重置状态
    self.connStatus = NO;
    self.hasStartedSending = NO;
    self.finished = NO;
    self.sentTag = 0;
    self.currentTag = 0;
    [self.fileHandles removeAllObjects];
    [self.filePathsQueue removeAllObjects];

    // 清除 UserDefaults 中的监听标记
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:LISTEN_START];
    [NSUserDefaults.standardUserDefaults synchronize];

    // 重新生成二维码
    [self generateDynamicQRCode];
}


#pragma mark - TCP

- (void)startTCPServerOnPort:(uint16_t)port {
    if (port <= 0) {
      NSAssert(port > 0, @"port must be more zero");
    }
    BOOL result = [[TCPServerTool shareInstance] listenOnPort:_port delegate:self];
    if (result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showSuccessWithStatus:[[NSString alloc]initWithFormat:@"监听端口成功"]];
        });
        if([[NSUserDefaults standardUserDefaults] objectForKey:LISTEN_START]==nil||[[NSUserDefaults standardUserDefaults] objectForKey:LISTEN_START]==NO)
        {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:LISTEN_START];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
    } else {
        static int retryCount = 0;
        static NSTimeInterval retryInterval = 2.0; // 初始间隔2秒
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"端口占用，%ds后重试", (int)retryInterval]];
            
            // 指数退避 + 最大重试限制
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(retryInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (retryCount++ < 5) {
                    self.port = (arc4random() % 10000) + 30001;
                    retryInterval *= 2; // 退避策略
                    [self startTCPServerOnPort:self.port];
                } else {
                    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"错误" message:@"监听端口失败" preferredStyle:UIAlertControllerStyleAlert];
                    [alertVc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [self.navigationController popViewControllerAnimated:YES];
                    }]];
                    [self presentViewController:alertVc animated:YES completion:nil];
                }
            });
        });
    }
}


#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(TCPServerTool *)tool withTag:(long)tag {
    self.sentTag = tag;
    [self.condition lock];
    [self.condition signal];
    [self.condition unlock];
}

- (void)socket:(nonnull TCPServerTool *)tool status:(ConnectStatus)status withError:(nullable NSError *)err {
    if (status == 0) {
        [SVProgressHUD showWithStatus:@"客户端已连接，请稍候"];
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeGradient];
        self.connStatus = YES;
        self.hasStartedSending = YES;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self startSendData];
        });
        [self monitorMemoryUsage];
    } else {
        self.connStatus = NO;
        
        [self.condition lock];
        [self.condition broadcast];
        [self.condition unlock];
        
        [[TCPServerTool shareInstance] disconnect];
        [TCPServerTool shareInstance].delegate = nil;
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:LISTEN_START]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:LISTEN_START];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
        
        // 关闭所有文件句柄
        for (NSFileHandle *handle in [self.fileHandles allValues]) {
            [handle closeFile];
        }
        [self.fileHandles removeAllObjects];
        
        if (self.finished) {
            if (err) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD dismiss];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                                     message:@"发送完成"
                                                                              preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                        [self.navigationController popViewControllerAnimated:YES];
                    }]];
                    [self presentViewController:alert animated:YES completion:nil];
                });
            }
        } else if (self.hasStartedSending) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *message = err ? @"连接断开，请重新发送" : @"连接已关闭";
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                                   message:message
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                        [self.navigationController popViewControllerAnimated:YES];
                    }]];
                    [self presentViewController:alert animated:YES completion:nil];
                });
            });
        }
        // 若未开始发送（仅监听后退出），静默关闭，不提示
    }
}

- (void)socket:(TCPServerTool *)tool receiveData:(NSData *)contentData {
}

- (void)monitorMemoryUsage {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (self.connStatus) {
            @autoreleasepool {
                static NSUInteger sendCount = 0;
                sendCount++;
                
                if (sendCount % 10 == 0) {
                    [NSThread sleepForTimeInterval:0.01];
                }
                if (self.currentTag - self.sentTag > 20) {
                    [NSThread sleepForTimeInterval:0.1];
                }
                [NSThread sleepForTimeInterval:0.05];
            }
        }
    });
}


#pragma mark - 内存警告处理

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    // 如果已经建立连接且尚未完成传输，则中断
    if (self.connStatus && !self.finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:@"内存不足，传输已中断"];
        });
        [[TCPServerTool shareInstance] disconnect];
    }
}


#pragma mark - 发送数据

- (void)startSendData {
    NSError *error;
    if (self.sourceDirPath == nil) {
        [SVProgressHUD showErrorWithStatus:@"未找到需要传输的数据"];
        [[TCPServerTool shareInstance] disconnect];
        return;
    }
    
    NSArray<NSString *> *allPaths = [NSFileManager.defaultManager subpathsOfDirectoryAtPath:self.sourceDirPath error:&error];
    if (error || allPaths.count == 0) {
        [SVProgressHUD showErrorWithStatus:@"未找到需要传输的数据"];
        [[TCPServerTool shareInstance] disconnect];
        return;
    }
    
    // 重置状态
    self.totalFilesSize = 0;
    self.sentFilesSize = 0;
    [self.filePathsQueue removeAllObjects];
    
    // 跳过规则
    NSArray<NSString *> *skipDirectories = @[@"Library/Caches", @"Library/WebKit", @"Library/Cookies", @"tmp"];
    NSArray<NSString *> *skipExtensions = @[@"log", @"tmp", @"cache"];
    
    NSMutableArray<NSString *> *validPaths = [NSMutableArray array];
    for (NSString *relativePath in allPaths) {
        BOOL shouldSkip = NO;
        
        // 跳过指定目录
        for (NSString *dir in skipDirectories) {
            if ([relativePath containsString:dir]) {
                shouldSkip = YES;
                break;
            }
        }
        
        // 跳过指定扩展名
        NSString *extension = [[relativePath pathExtension] lowercaseString];
        if ([skipExtensions containsObject:extension]) {
            shouldSkip = YES;
        }
        
        if (shouldSkip) {
            NSLog(@"跳过文件: %@", relativePath);
            continue;
        }
        
        NSString *fullPath = [self.sourceDirPath stringByAppendingPathComponent:relativePath];
        BOOL isDir;
        if ([NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) {
            NSDictionary<NSFileAttributeKey, id> *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:fullPath error:nil];
            if (attrs) {
                self.totalFilesSize += [attrs fileSize];
            }
        }
        [validPaths addObject:relativePath];
    }
    
    self.filePathsQueue = [validPaths mutableCopy];
    
    // 先发送 Meta 包（总大小 + 文件数）
    FileEntry *metaEntry = [[FileEntry alloc] init];
    metaEntry.type = FileEntryTypeMeta;
    metaEntry.fileSize = self.totalFilesSize;
    metaEntry.path = [NSString stringWithFormat:@"%lu", (unsigned long)validPaths.count];
    
    NSData *metaData = [NSKeyedArchiver archivedDataWithRootObject:metaEntry requiringSecureCoding:YES error:nil];
    if (metaData) {
        [[TCPServerTool shareInstance] sendData:metaData to:@"" withTag:self.currentTag++];
    } else {
        NSLog(@"⚠️ Meta 数据序列化失败");
    }
    
    // 开始发送文件
    [self sendNextFile];
}

- (void)sendNextFile {
    if (self.filePathsQueue.count == 0) {
        // 发送完成标记
        FileEntry *finishEntry = [[FileEntry alloc] init];
        finishEntry.type = FileEntryTypeFinish;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:finishEntry requiringSecureCoding:YES error:nil];
        [[TCPServerTool shareInstance] sendData:data to:@"" withTag:self.currentTag++];
        
        self.finished = YES;
        [SVProgressHUD showSuccessWithStatus:@"所有文件已发送完成"];
        return;
    }
    
    NSString *relativePath = self.filePathsQueue.firstObject;
    [self.filePathsQueue removeObjectAtIndex:0];
    NSString *fullPath = [self.sourceDirPath stringByAppendingPathComponent:relativePath];
    
    BOOL isDir;
    [NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDir];
    
    if (isDir) {
        // 发送目录
        FileEntry *dirEntry = [[FileEntry alloc] init];
        dirEntry.type = FileEntryTypeDirectory;
        dirEntry.path = relativePath;
        dirEntry.isDir = YES;
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dirEntry requiringSecureCoding:YES error:nil];
        [[TCPServerTool shareInstance] sendData:data to:@"" withTag:self.currentTag++];
        [self sendNextFile];
    } else {
        // 发送文件 Start
        FileEntry *startEntry = [[FileEntry alloc] init];
        startEntry.type = FileEntryTypeStart;
        startEntry.path = relativePath;
        
        NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:fullPath error:nil];
        startEntry.fileSize = attrs ? [attrs fileSize] : 0;
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:startEntry requiringSecureCoding:YES error:nil];
        [[TCPServerTool shareInstance] sendData:data to:@"" withTag:self.currentTag++];
        
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fullPath];
        if (fileHandle) {
            [self.fileHandles setObject:fileHandle forKey:relativePath];
            [self sendNextChunkForFile:relativePath];
        } else {
            NSLog(@"无法打开文件: %@", fullPath);
            [self sendNextFile];
        }
    }
}

- (void)sendNextChunkForFile:(NSString *)relativePath {
    NSFileHandle *fileHandle = [self.fileHandles objectForKey:relativePath];
    if (!fileHandle) {
        [self sendNextFile];
        return;
    }
    
    @autoreleasepool {
        NSData *chunkData = [fileHandle readDataOfLength:CHUNK_SIZE];
        if (chunkData.length > 0) {
            FileEntry *chunkEntry = [[FileEntry alloc] init];
            chunkEntry.type = FileEntryTypeData;
            chunkEntry.path = relativePath;
            chunkEntry.offset = [fileHandle offsetInFile] - chunkData.length;
            chunkEntry.chunkData = chunkData;
            
            [self sendDataWithEntry:chunkEntry];
            
            if (chunkData.length == CHUNK_SIZE) {
                dispatch_async(self.sendingQueue, ^{
                    [self sendNextChunkForFile:relativePath];
                });
            } else {
                // 文件结束
                [fileHandle closeFile];
                [self.fileHandles removeObjectForKey:relativePath];
                
                FileEntry *endEntry = [[FileEntry alloc] init];
                endEntry.type = FileEntryTypeEnd;
                endEntry.path = relativePath;
                [self sendDataWithEntry:endEntry];
                
                dispatch_async(self.sendingQueue, ^{
                    [self sendNextFile];
                });
            }
        } else {
            [fileHandle closeFile];
            [self.fileHandles removeObjectForKey:relativePath];
            dispatch_async(self.sendingQueue, ^{
                [self sendNextFile];
            });
        }
    }
}


#pragma mark - Flow Control & Progress

- (void)sendDataWithEntry:(FileEntry *)entry {
    [self.condition lock];
    while (self.currentTag - self.sentTag >= self.windowSize) {
        [self.condition wait];
    }
    [self.condition unlock];
    
    @autoreleasepool {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:YES error:nil];
        [[TCPServerTool shareInstance] sendData:data to:@"" withTag:self.currentTag];
    }
    
    self.currentTag++;
    self.sentFilesSize += entry.chunkData.length;
    
    float progress = self.totalFilesSize > 0 ? (float)self.sentFilesSize / (float)self.totalFilesSize : 0;
    NSString *status = [NSString stringWithFormat:@"发送进度: %.1f%%", progress * 100];
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showProgress:progress status:status];
    });
}


#pragma mark - 保存二维码到相册

- (void)saveQRCodeToAlbum {
    if (!self.QRcode.image) return;
    
    UIImageWriteToSavedPhotosAlbum(
        self.QRcode.image,
        self,
        @selector(imageSavedToPhotosAlbum:didFinishSavingWithError:contextInfo:),
        nil
    );
}

// 保存结果回调
- (void)imageSavedToPhotosAlbum:(UIImage*)image didFinishSavingWithError:(NSError*)error contextInfo:(id)contextInfo {
    if (!error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showSuccessWithStatus:@"图片已保存到相簿"];
        });
        return;
    }
    
    // 错误处理
    NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
    if (underlyingError) {
        if ([underlyingError.domain isEqualToString:@"PHPhotosErrorDomain"] && underlyingError.code == 3311) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showErrorWithStatus:@"相册访问权限被拒绝"];
            });
        } else if (([underlyingError.domain isEqualToString:@"PHPhotosErrorDomain"] && underlyingError.code == 1001)
                  || ([underlyingError.domain isEqualToString:@"NSCocoaErrorDomain"] && underlyingError.code == 640)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showErrorWithStatus:@"存储空间不足"];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showErrorWithStatus:error.localizedDescription];
            });
        }
    } else if ([error.domain isEqualToString:@"ALAssetsLibraryErrorDomain"]) {
        switch (error.code) {
            case -3311:
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showErrorWithStatus:@"相册访问权限被拒绝"];
                });
                break;
            default:
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                });
                break;
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:error.localizedDescription];
        });
    }
}


#pragma mark - lazy load

- (UIView *)containerShadowView {
    if (!_containerShadowView) {
        _containerShadowView = [[UIView alloc] init];
        _containerShadowView.backgroundColor = RGBA(0, 0, 0, 0.3);
        _containerShadowView.layer.cornerRadius = ZOOM(12);
    }
    return _containerShadowView;
}

- (UIView *)containerView {
    if (!_containerView) {
        _containerView = [[UIView alloc] init];
        _containerView.backgroundColor = [UIColor whiteColor];
        _containerView.layer.cornerRadius = ZOOM(12);
    }
    return _containerView;
}

- (UILabel *)stepLabel {
    if (!_stepLabel) {
        _stepLabel = [UILabel labelWithText:@"1.打开需要导出数据的App \n2.找到【我的】➡️【设置】➡️【数据迁移】 \n3.选择【数据导入】扫描下方二维码建立传输链接，等待传输成功即可" fontSize:ZOOM(16) bold:YES textColor:RGBA(153, 153, 153, 1)];
        _stepLabel.textAlignment = NSTextAlignmentLeft;
        _stepLabel.numberOfLines = 0;
    }
    return _stepLabel;
}

- (UIImageView *)QRcode {
    if (!_QRcode) {
        _QRcode = [[UIImageView alloc] init];
    }
    return _QRcode;
}

- (UIImageView *)scanImageView {
    if (!_scanImageView) {
        _scanImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"QRBox_scanArea"]];
    }
    return _scanImageView;
}

- (UIButton *)saveButton {
    if (!_saveButton) {
        _saveButton = [[UIButton alloc] init];
        [_saveButton setBackgroundImage:[UIImage imageNamed:@"QRBox_saveButton"] forState:UIControlStateNormal];
        [_saveButton addTarget:self action:@selector(saveQRCodeToAlbum) forControlEvents:UIControlEventTouchUpInside];
    }
    return _saveButton;
}

- (UIButton *)refreshButton {
    if (!_refreshButton) {
        _refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_refreshButton setTitle:@"🔄 刷新" forState:UIControlStateNormal];
        _refreshButton.titleLabel.font = [UIFont systemFontOfSize:ZOOM(14) weight:UIFontWeightMedium];
        [_refreshButton setTitleColor:RGBA(0, 122, 255, 1) forState:UIControlStateNormal];
        [_refreshButton addTarget:self action:@selector(refreshQRCode) forControlEvents:UIControlEventTouchUpInside];
        _refreshButton.layer.borderColor = RGBA(0, 122, 255, 1).CGColor;
        _refreshButton.layer.borderWidth = 1.0;
        _refreshButton.layer.cornerRadius = ZOOM(6);
    }
    return _refreshButton;
}

- (UILabel *)tipLabel {
    if (!_tipLabel) {
        _tipLabel = [UILabel labelWithText:@"Tips：若使用两台手机，需要两台手机连接同一个【WIFI】才能传输" fontSize:ZOOM(16) bold:YES textColor:RGBA(153, 153, 153, 1)];
        _tipLabel.textAlignment = NSTextAlignmentLeft;
        _tipLabel.numberOfLines = 0;
    }
    return _tipLabel;
}


@end
