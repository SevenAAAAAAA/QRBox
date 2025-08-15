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

@interface QRMainViewController () <GCDAsyncSocketDelegate, TCPServerToolDelegate>

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *containerShadowView;
@property (nonatomic, strong) UILabel *stepLabel;
@property (nonatomic, strong) UIImageView *QRcode;
@property (nonatomic, strong) UIImageView *scanImageView;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, assign) int port;
@property (nonatomic, assign) long sentTag;
@property (nonatomic, assign) long currentTag;
@property (nonatomic, strong) NSArray *fileEntries;
@property (nonatomic, assign) BOOL connStatus;
@property (nonatomic, assign) BOOL finished;

@end

@implementation QRMainViewController

static NSString * const LISTEN_START = @"LISTEN_START";

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

NSString *findUserPath() {
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
    [SVProgressHUD setBackgroundColor:RGBA(0, 0, 0, 0.5)];
    [SVProgressHUD setFont:[UIFont fontWithName:@"PingFang SC" size:16]];
    [SVProgressHUD setForegroundColor:[UIColor whiteColor]];
    [SVProgressHUD setMinimumSize:CGSizeMake(200, 120)];
    [SVProgressHUD setCornerRadius:15];
    [SVProgressHUD setMaximumDismissTimeInterval:0.8];
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
    
    [_tipLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.containerView.mas_bottom).offset(ZOOM(30));
        make.left.right.equalTo(self.view).inset(ZOOM(26));
    }];
}


#pragma mark - 动态生成二维码

- (void)generateDynamicQRCode {
    // 获取本机IP（确保在WiFi环境下）
    NSString *ip = [LANTool getIPAddress:YES];
    _port = (arc4random() % 10000) + 20000; // 20000-30000随机端口
    
    // 生成连接字符串（Base64编码防特殊字符）
    NSString *connectionInfo = [NSString stringWithFormat:@"%@:%d", ip, _port];
    NSString *encodedInfo = [connectionInfo base64EncodedString];
    
    // 启动TCP服务端监听
    [self startTCPServerOnPort:_port];
    
    // 使用 SGQRCode 生成二维码
    UIImage *qrImage = [SGGenerateQRCode generateQRCodeWithData:encodedInfo size:(ZOOM(180))];
    
    // 转换为PNG格式
    NSData *pngData = UIImagePNGRepresentation(qrImage);
    UIImage *qrPngImage = [UIImage imageWithData:pngData];
    
    // 生成二维码图片
    self.QRcode.image = qrPngImage;
}


#pragma mark - TCP

- (void)startTCPServerOnPort:(uint16_t)port {
    if (port <= 0) {
      NSAssert(port > 0, @"port must be more zero");
    }
    BOOL result = [[TCPServerTool shareInstance] listenOnPort:_port delegate:self];
    if (result) {
        [SVProgressHUD showSuccessWithStatus:[[NSString alloc]initWithFormat:@"监听端口成功"]];
        if([[NSUserDefaults standardUserDefaults] objectForKey:LISTEN_START]==nil||[[NSUserDefaults standardUserDefaults] objectForKey:LISTEN_START]==NO)
        {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:LISTEN_START];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
    }else {
        UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"错误" message:@"监听端口失败" preferredStyle:UIAlertControllerStyleAlert];
        [alertVc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self.navigationController popViewControllerAnimated:YES];
        }]];
        [self presentViewController:alertVc animated:YES completion:nil];
    }
}


#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(TCPServerTool *)tool withTag:(long)tag{
    self.sentTag = tag;
    if(self.currentTag == self.fileEntries.count){
        [SVProgressHUD dismiss];
        FileEntry *entry = [[FileEntry alloc] init];
        NSData *finishMsgData = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:YES error:nil];
        self.currentTag += 1;
        [[TCPServerTool shareInstance] sendData:finishMsgData to:@"" withTag:self.currentTag];
    } else if (self.currentTag == self.fileEntries.count + 1 ||
               self.currentTag == self.fileEntries.count + 2) {
        self.finished = TRUE;
        [SVProgressHUD showWithStatus:@"发送完成，等待连接断开"];
    }
}

- (void)socket:(nonnull TCPServerTool *)tool status:(ConnectStatus)status withError:(nullable NSError *)err {
    if (status == 0) {
        self.connStatus = YES;
        [self startSendData];
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeGradient];
    } else {
        self.connStatus = NO;
        [[TCPServerTool shareInstance] disconnect];
        [TCPServerTool shareInstance].delegate = nil;
        if([[NSUserDefaults standardUserDefaults] objectForKey:LISTEN_START])
        {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:LISTEN_START];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
        if (self.finished) {
            if (err) {  // closed by remote client... ( the disconnection is initiated by the remote client)
                [SVProgressHUD dismiss];
                UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"提示" message:@"发送完成" preferredStyle:UIAlertControllerStyleAlert];
                [alertVc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [self.navigationController popViewControllerAnimated:YES];
                }]];
                [self presentViewController:alertVc animated:YES completion:nil];
            }
        } else {
            if(err) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.fileEntries.count == 0) {
                        UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"提示" message:@"发送完成" preferredStyle:UIAlertControllerStyleAlert];
                        [alertVc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [self.navigationController popViewControllerAnimated:YES];
                        }]];
                        [self presentViewController:alertVc animated:YES completion:nil];
                        return;
                    }
                    [SVProgressHUD dismiss];
                    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"提示" message:@"连接断开，请重新发送" preferredStyle:UIAlertControllerStyleAlert];
                    [alertVc addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [self.navigationController popViewControllerAnimated:YES];
                    }]];
                    [self presentViewController:alertVc animated:YES completion:nil];
                });
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }
    }
}

- (void)socket:(TCPServerTool *)tool receiveData:(NSData *)contentData {
}


#pragma mark - 发送数据

- (void)startSendData {
    NSError *error;
    if (self.sourceDirPath == nil) {
        [SVProgressHUD showErrorWithStatus:@"未找到需要传输的数据"];
        [[TCPServerTool shareInstance] disconnect];
        return;
    }
    self.fileEntries = [NSFileManager.defaultManager subpathsOfDirectoryAtPath:self.sourceDirPath error:&error];
    if (error) {
        [SVProgressHUD showErrorWithStatus:@"未找到需要传输的数据"];
        [[TCPServerTool shareInstance] disconnect];
    } else {
        self.currentTag = 0;
        [self trySendOneEntry];
    }
}

- (void)trySendOneEntry {
    if (self.currentTag >= self.fileEntries.count) {
        FileEntry *endSignal = [[FileEntry alloc] init]; // 当文件数据传输完毕时，创建一个空的 WBFileEntry 对象为结束标志
        NSData *signalData = [NSKeyedArchiver archivedDataWithRootObject:endSignal requiringSecureCoding:YES error:nil];    // 序列化结束信号
        [[TCPServerTool shareInstance] sendData:signalData to:@"" withTag:self.currentTag];   // 发送结束信号
        self.currentTag += 1;
        return;
    } else {
        if (self.currentTag-self.sentTag <= 5) {
            NSString *relativePath = [self.fileEntries objectAtIndex:self.currentTag];
            NSString *fullPath = [self.sourceDirPath stringByAppendingPathComponent:relativePath];
            FileEntry *entry = [[FileEntry alloc] init];
            BOOL isDir;
            [NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDir];
            entry.isDir = isDir;
            NSString *progressString = [NSString stringWithFormat:@"已发送:%ld/%ld",self.currentTag,self.fileEntries.count];
            entry.path = relativePath;
            if (entry.isDir == FALSE) {
                entry.data = [NSData dataWithContentsOfFile:fullPath];
            }
            @autoreleasepool {
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:YES error:nil];
                [[TCPServerTool shareInstance] sendData:data to:@"" withTag:self.currentTag];
            }
            [SVProgressHUD showWithStatus:progressString];
            self.currentTag ++;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.connStatus) {
                [self trySendOneEntry];
            } else {
                return;
            }
        });
    }
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
        [SVProgressHUD showSuccessWithStatus:@"图片已保存到相簿"];
        return;
    }
    
    // 错误处理
    NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
    if (underlyingError) {
        if ([underlyingError.domain isEqualToString:@"PHPhotosErrorDomain"] && underlyingError.code == 3311) {
            [SVProgressHUD showErrorWithStatus:@"相册访问权限被拒绝"];
        } else if (([underlyingError.domain isEqualToString:@"PHPhotosErrorDomain"] && underlyingError.code == 1001)
                  || ([underlyingError.domain isEqualToString:@"NSCocoaErrorDomain"] && underlyingError.code == 640)) {
            [SVProgressHUD showErrorWithStatus:@"存储空间不足"];
        } else {
            [SVProgressHUD showErrorWithStatus:error.localizedDescription];
        }
    } else if ([error.domain isEqualToString:@"ALAssetsLibraryErrorDomain"]) {
        switch (error.code) {
            case -3311:
                [SVProgressHUD showErrorWithStatus:@"相册访问权限被拒绝"];
                break;
            default:
                [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                break;
        }
    } else {
        [SVProgressHUD showErrorWithStatus:error.localizedDescription];
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

- (UILabel *)tipLabel {
    if (!_tipLabel) {
        _tipLabel = [UILabel labelWithText:@"Tips：若使用两台手机，需要两台手机连接同一个【WIFI】才能传输" fontSize:ZOOM(16) bold:YES textColor:RGBA(153, 153, 153, 1)];
        _tipLabel.textAlignment = NSTextAlignmentLeft;
        _tipLabel.numberOfLines = 0;
    }
    return _tipLabel;
}


@end
