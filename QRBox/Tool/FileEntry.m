//
//  FileEntry.m
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/14.
//

#import "FileEntry.h"

@implementation FileEntry

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.path forKey:@"path"];
    [aCoder encodeBool:self.isDir forKey:@"isDir"];
    [aCoder encodeObject:self.data forKey:@"data"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
 
    self = [super init];
    if (self) {
        self.path = [aDecoder decodeObjectForKey:@"path"];
        self.isDir = [aDecoder decodeBoolForKey:@"isDir"];
        self.data = [aDecoder decodeObjectForKey:@"data"];
    }
    return self;
}

- (NSData*)serialize{
      return [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:nil];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}


@end
