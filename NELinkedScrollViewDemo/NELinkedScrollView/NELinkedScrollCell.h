//
//  NELinkedScrollCell.h
//  PRIS_iPhone
//
//  Created by Sun on 14/6/9.
//
//

#import <UIKit/UIKit.h>

@class NELinkedScrollCell, NELinkedScrollView;

@protocol NELinkedScrollDelegate <NSObject>

//切换时delegate
- (void)scrollingViewWillBeginPulling:(NELinkedScrollCell *)cell;
- (void)scrollingViewDidBeginPulling:(NELinkedScrollCell *)cell;
- (void)scrollingView:(NELinkedScrollCell *)cell didChangePullOffset:(CGFloat)offset;
- (void)scrollingViewDidEndPulling:(NELinkedScrollCell *)cell withVelocity:(CGPoint)velocity;

//一般滑动时的delegate
- (void)scrollingViewDidBeginScrolling:(NELinkedScrollCell *)cell;
- (void)scrollingViewDidScrolling:(NELinkedScrollCell *)cell;
- (CGPoint)scrollingViewDidEndScrolling:(NELinkedScrollCell *)cell withVelocity:(CGPoint)velocity;

//直接调用setcontentoffset后调用
- (void)scrollingView:(NELinkedScrollCell *)cell scrollToOffset:(CGPoint)offset animated:(BOOL)animated;
@end

@interface NELinkedScrollCell : UIView <UIScrollViewDelegate>{
@protected
    UIScrollView *_scrollView;
    CGPoint _scrollViewStartOffset;
    CGPoint _scrollViewEndOffset;
}

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, copy) NSString *identifier;

@property (nonatomic, weak, readonly) id<NELinkedScrollDelegate> scrollingDelegate;

@property (nonatomic) CGPoint scrollViewStartOffset;
@property (nonatomic) CGPoint scrollViewEndOffset;

- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated;

- (void)cellWillAddtoLinkedScrollView:(NELinkedScrollView *)linkedScrollView;

@end
