//
//  NEViewController.m
//  NELinkedScrollViewDemo
//
//  Created by neal on 14/10/13.
//  Copyright (c) 2014年 orz. All rights reserved.
//

#import "NEViewController.h"
#import "NELinkedScrollView.h"
#import "NELinkedScrollCell.h"

#import "NEDemoCell.h"

@interface NEViewController () <NELinkedScrollViewDelegate, NELinkedScrollViewDataSource>

@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation NEViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.containerView.delegate = self;
    self.containerView.dataSource = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NEDemoCell *cell = [[NEDemoCell alloc] initWithFrame:self.view.frame pageCount:(random()%5)+1];
    [self.containerView reloadDataOfCell:cell];
}

//bounce
- (void)animationBounce {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    animation.values = @[ @0, @10, @-10, @10, @0 ];
    animation.keyTimes = @[ @0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1 ];
    animation.duration = 0.4;
    animation.additive = YES;
    [self.containerView.layer addAnimation:animation forKey:@"bounce"];
}

- (NELinkedScrollCell *)linkedScrollView:(NELinkedScrollView *)linkedScrollView cellPreviousCell:(NELinkedScrollCell *)currentCell {
    static NSString *ReusableEpubIdentifier = @"ReusableEpubIdentifier";
    NEDemoCell *cell = (NEDemoCell *)[self.containerView dequeueReusableCellWithIdentifier:ReusableEpubIdentifier];
    if (!cell) {
        cell = [[NEDemoCell alloc] initWithFrame:self.view.frame pageCount:(random()%8)+1];
        cell.identifier = ReusableEpubIdentifier;
    } else {
        [cell initWthPageCount:(random()%5)+1];
    }
    [cell.scrollView setContentOffset:cell.scrollViewEndOffset];
    cell.scrollView.backgroundColor = [cell randomColor];
    return cell;
}

- (NELinkedScrollCell *)linkedScrollView:(NELinkedScrollView *)linkedScrollView cellAfterCell:(NELinkedScrollCell *)currentCell {
    static NSString *ReusableEpubIdentifier = @"ReusableEpubIdentifier";
    NEDemoCell *cell = (NEDemoCell *)[self.containerView dequeueReusableCellWithIdentifier:ReusableEpubIdentifier];
    if (!cell) {
        cell = [[NEDemoCell alloc] initWithFrame:self.view.frame pageCount:(random()%6)+1];
        cell.identifier = ReusableEpubIdentifier;
    } else {
        [cell initWthPageCount:(random()%5)+1];
    }
    [cell.scrollView setContentOffset:cell.scrollViewStartOffset];
    cell.scrollView.backgroundColor = [cell randomColor];
    return cell;
}

//没有获得新cell会调用，表示已经到最前面或最后面
- (void)linkedScrollViewScrolledToTheBegin:(NELinkedScrollView *)linkedScrollView {
    [self animationBounce];
}

- (void)linkedScrollViewScrolledToTheEnd:(NELinkedScrollView *)linkedScrollView {
    [self animationBounce];
}

- (void)linkedScrollView:(NELinkedScrollView *)linkedScrollView clickCell:(NELinkedScrollCell *)cell atLocation:(CGPoint)location {
    if (location.x < 100) {
        //  往前翻
        [self.containerView scrollToPreviousPageAnimated:YES];
    } else if (location.x > self.view.bounds.size.width - 100) {
        //  往后翻
        [self.containerView scrollToNextPageAnimated:YES];
    }
}
@end
