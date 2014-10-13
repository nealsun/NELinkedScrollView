//
//  NEDemoCell.m
//  NELinkedScrollViewDemo
//
//  Created by neal on 14/10/13.
//  Copyright (c) 2014年 orz. All rights reserved.
//

#import "NEDemoCell.h"

@implementation NEDemoCell

- (UIColor *)randomColor {
    return [UIColor colorWithRed:(random()%255)/255.0 green:(random()%255)/255.0 blue:(random()%255)/255.0 alpha:1.0];
}

- (instancetype)initWithFrame:(CGRect)frame pageCount:(NSInteger)page {
    self = [super initWithFrame:frame];
    if (self) {
        [self initWthPageCount:page];
    }
    return self;
}

- (void)initWthPageCount:(NSInteger)page {
    CGRect frame = self.frame;
    self.scrollView.contentSize = CGSizeMake(frame.size.width * (page + 2), frame.size.height);
    self.scrollViewStartOffset = CGPointMake(frame.size.width, 0);
    self.scrollViewEndOffset = CGPointMake(frame.size.width * page, 0);
    //        self.scrollView.backgroundColor = [self randomColor];
    for (UIView *v in [self.scrollView subviews]) {
        [v removeFromSuperview];
    }
    for (int i = 0; i < page; i++) {
        UILabel *label = [[UILabel alloc] initWithFrame:self.bounds];
        label.text = [NSString stringWithFormat:@"%d", i];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont systemFontOfSize:120];
        CGRect lframe = label.frame;
        lframe.origin.x = lframe.size.width * (i + 1);
        label.frame = lframe;
        [self.scrollView addSubview:label];
    }
}
@end
