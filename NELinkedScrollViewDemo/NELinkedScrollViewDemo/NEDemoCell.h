//
//  NEDemoCell.h
//  NELinkedScrollViewDemo
//
//  Created by neal on 14/10/13.
//  Copyright (c) 2014年 orz. All rights reserved.
//

#import "NELinkedScrollCell.h"

@interface NEDemoCell : NELinkedScrollCell

- (instancetype)initWithFrame:(CGRect)frame pageCount:(NSInteger)page;
- (UIColor *)randomColor;
- (void)initWthPageCount:(NSInteger)page;
@end
