//
//  FileEntry.m
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/14.
//

#import "FileEntry.h"

@implementation FileEntry

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:self.type forKey:@"type"];
    [aCoder encodeObject:self.path forKey:@"path"];
    [aCoder encodeInt64:self.fileSize forKey:@"fileSize"];
    [aCoder encodeInt64:self.offset forKey:@"offset"];
    [aCoder encodeObject:self.chunkData forKey:@"chunkData"];
    [aCoder encodeBool:self.isDir forKey:@"isDir"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.type = [aDecoder decodeIntegerForKey:@"type"];
        self.path = [aDecoder decodeObjectForKey:@"path"];
        self.fileSize = [aDecoder decodeInt64ForKey:@"fileSize"];
        self.offset = [aDecoder decodeInt64ForKey:@"offset"];
        self.chunkData = [aDecoder decodeObjectForKey:@"chunkData"];
        self.isDir = [aDecoder decodeBoolForKey:@"isDir"];
    }
    return self;
}


@end
