//
//  NELinkedScrollView.h
//  PRIS_iPhone
//
//  Created by Sun on 14/6/9.
//
//

#import <UIKit/UIKit.h>
#import "NELinkedScrollCell.h"
#import "NELinkedScrollViewAnimator.h"

@protocol NELinkedScrollViewDataSource;

@class NELinkedScrollView;

@protocol NELinkedScrollViewDelegate <NSObject>

@optional
//响应点击事件，处理由delegate负责，如翻页，全屏。
- (void)linkedScrollView:(NELinkedScrollView *)linkedScrollView clickCell:(NELinkedScrollCell *)cell atLocation:(CGPoint)location;

//通知切换page
- (void)linkedScrollView:(NELinkedScrollView *)linkedScrollView currentCell:(NELinkedScrollCell *)cell willTurnFromOffset:(CGPoint)fromOffset toOffset:(CGPoint)toOffset;
- (void)linkedScrollView:(NELinkedScrollView *)linkedScrollView currentCellDidCancelTurnPage:(NELinkedScrollCell *)cell;
- (void)linkedScrollView:(NELinkedScrollView *)linkedScrollView currentCell:(NELinkedScrollCell *)cell didTurnFromOffset:(CGPoint)fromOffset toOffset:(CGPoint)toOffset;

//通知切换cell
- (void)linkedScrollView:(NELinkedScrollView *)linkedScrollView willScrollFromCell:(NELinkedScrollCell *)fromCell toCell:(NELinkedScrollCell *)toCell;
- (void)linkedScrollView:(NELinkedScrollView *)linkedScrollView didScrollFromCell:(NELinkedScrollCell *)fromCell toCell:(NELinkedScrollCell *)toCell;

//没有获得新cell会调用，表示已经到最前面或最后面
- (void)linkedScrollViewScrolledToTheBegin:(NELinkedScrollView *)linkedScrollView;
- (void)linkedScrollViewScrolledToTheEnd:(NELinkedScrollView *)linkedScrollView;
@end

@interface NELinkedScrollView : UIView <NELinkedScrollDelegate>

@property (nonatomic, strong) UIScrollView *containerScrollView;

@property (nonatomic, strong, readonly) NELinkedScrollCell *currentCell;

@property (nonatomic, weak) id<NELinkedScrollViewDataSource> dataSource;

@property (nonatomic ,weak) id<NELinkedScrollViewDelegate> delegate;

- (void)reloadDataOfCell:(NELinkedScrollCell *)cell;

- (BOOL)scrollToNextPageAnimated:(BOOL)animated;
- (BOOL)scrollToPreviousPageAnimated:(BOOL)animated;

- (void)currentCellScrollToOffset:(CGPoint)offset animated:(BOOL)animated;

- (NELinkedScrollCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;

@property (nonatomic, strong) NELinkedScrollViewAnimator<NEAnimatorActionDelegate, UIGestureRecognizerDelegate> *animator;

@property (nonatomic, getter = isScrolling, readonly) BOOL scrolling;
@property (nonatomic, getter = isAnimating, readonly) BOOL animating;

@end

@protocol NELinkedScrollViewDataSource <NSObject>

@required
- (NELinkedScrollCell *)linkedScrollView:(NELinkedScrollView *)linkedScrollView cellPreviousCell:(NELinkedScrollCell *)cell;

- (NELinkedScrollCell *)linkedScrollView:(NELinkedScrollView *)linkedScrollView cellAfterCell:(NELinkedScrollCell *)cell;

@end