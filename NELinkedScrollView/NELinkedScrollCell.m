//
//  NELinkedScrollCell.m
//  PRIS_iPhone
//
//  Created by Sun on 14/6/9.
//
//

#import "NELinkedScrollCell.h"
#import "NELinkedScrollView.h"

@interface NELinkedScrollCell () 

@property (nonatomic, weak) id<NELinkedScrollDelegate> scrollingDelegate;

@end

@implementation NELinkedScrollCell {
    BOOL _pulling;
    BOOL _pullingStarted;
    BOOL _isDragging;
    BOOL _isPullingForward;
    NSUInteger innerPageIndex;
    BOOL _isScrolling;
    BOOL _scrollingStarted;
}

- (void)dealloc {
    _scrollView.delegate = nil;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];

        scrollView.contentSize = frame.size;

        self.scrollView = scrollView;
        self.scrollView.contentSize = CGSizeMake(frame.size.width * 3, frame.size.height);
        self.scrollViewStartOffset = CGPointMake(frame.size.width, 0);
        
        self.scrollViewEndOffset = CGPointMake(frame.size.width, 0);

    }
    return self;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@, scrollDelegate:%@, contentSize:(%f, %f)>", [super debugDescription], self.scrollView.delegate, self.scrollView.contentSize.width, self.scrollView.contentSize.height];
}

- (void)setScrollView:(UIScrollView *)scrollView {
    if (_scrollView) {
        [_scrollView removeFromSuperview];
    }
    _scrollView = scrollView;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
//    _scrollView.pagingEnabled = YES;
    _scrollView.clipsToBounds = YES;
    _scrollView.delegate = self;
    [self addSubview:_scrollView];
    CGPoint offset = _scrollView.contentOffset;
    if (offset.x < self.scrollViewStartOffset.x) {
        offset.x = self.scrollViewStartOffset.x;
    }

    if (offset.x > self.scrollViewEndOffset.x) {
        offset.x = self.scrollViewEndOffset.x;
    }
    [_scrollView setContentOffset:offset];
}

- (void)setScrollViewStartOffset:(CGPoint)scrollViewStartOffset {
    _scrollViewStartOffset = scrollViewStartOffset;

    CGPoint offset = _scrollView.contentOffset;

    if (offset.x < self.scrollViewStartOffset.x) {
        offset.x = self.scrollViewStartOffset.x;
    }

    [_scrollView setContentOffset:offset];
}

- (void)setScrollViewEndOffset:(CGPoint)scrollViewEndOffset {
    _scrollViewEndOffset = scrollViewEndOffset;

    CGPoint offset = _scrollView.contentOffset;

    if (offset.x > self.scrollViewEndOffset.x) {
        offset.x = self.scrollViewEndOffset.x;
    }

    [_scrollView setContentOffset:offset];
}

- (void)cellWillAddtoLinkedScrollView:(NELinkedScrollView *)linkedScrollView {
    self.scrollingDelegate = linkedScrollView;
}

- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated {
    if ([self.scrollingDelegate respondsToSelector:@selector(scrollingViewDidBeginScrolling:)]) {
        [self.scrollingDelegate scrollingViewDidBeginScrolling:self];
    }
    if ([self.scrollingDelegate respondsToSelector:@selector(scrollingView:scrollToOffset:animated:)]) {
        [self.scrollingDelegate scrollingView:self scrollToOffset:offset animated:animated];
    }
}

#pragma mark - scrollingview delegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (_isDragging) {
        return;
    }
    _isDragging = YES;
    _pulling = NO;
    _pullingStarted = NO;
    _isScrolling = NO;
    _scrollingStarted = NO;
    if ([self.scrollingDelegate respondsToSelector:@selector(scrollingViewWillBeginPulling:)]) {
        [self.scrollingDelegate scrollingViewWillBeginPulling:self];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!_isDragging) {
        return;
    }

    CGFloat offset = scrollView.contentOffset.x;

    if ((offset > self.scrollViewEndOffset.x || offset < self.scrollViewStartOffset.x)) {
        _pulling = YES;
        _isScrolling = NO;
        _isPullingForward = offset < self.scrollViewStartOffset.x;
        if ([self.scrollingDelegate respondsToSelector:@selector(scrollingViewDidBeginPulling:)] && !_pullingStarted) {
            _pullingStarted = YES;
            [self.scrollingDelegate scrollingViewDidBeginPulling:self];
        }
    } else {
        _pulling = NO;
        _isScrolling = YES;
        if ([self.scrollingDelegate respondsToSelector:@selector(scrollingViewDidBeginScrolling:)] && !_scrollingStarted) {
            _scrollingStarted = YES;
            [self.scrollingDelegate scrollingViewDidBeginScrolling:self];
        }
        [self.scrollingDelegate scrollingView:self didChangePullOffset:0];
        scrollView.transform = CGAffineTransformMakeTranslation(0, 0);
    }

    if (_pulling) {
        CGFloat pullOffset = 0.f;

        if (offset >= self.scrollViewEndOffset.x) {
            pullOffset = MAX(0, offset - self.scrollViewEndOffset.x);
        } else if (offset <= self.scrollViewStartOffset.x) {
            pullOffset = MIN(0, offset - self.scrollViewStartOffset.x);
        }

        if ([self.scrollingDelegate respondsToSelector:@selector(scrollingView:didChangePullOffset:)]) {
            [self.scrollingDelegate scrollingView:self didChangePullOffset:pullOffset];
        }

        scrollView.transform = CGAffineTransformMakeTranslation(pullOffset, 0);
    } else {
        
        if ([self.scrollingDelegate respondsToSelector:@selector(scrollingViewDidScrolling:)]) {
            [self.scrollingDelegate scrollingViewDidScrolling:self];
        }
    }
}

- (void)scrollingEnded:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity {

    if (!_pulling) {
        return;
    }
    _pulling = NO;
    _pullingStarted = NO;
//    _deceleratingBackToZero = NO;
    if ([self.scrollingDelegate respondsToSelector:@selector(scrollingViewDidEndPulling:withVelocity:)]) {
        [self.scrollingDelegate scrollingViewDidEndPulling:self withVelocity:velocity];
    }

    if (_isPullingForward) {
        scrollView.contentOffset = self.scrollViewStartOffset;
    } else {
        scrollView.contentOffset = self.scrollViewEndOffset;
    }
    scrollView.transform = CGAffineTransformIdentity;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    _isDragging = NO;

    if (_isScrolling) {
        _isScrolling = NO;
        _scrollingStarted = NO;
        if ([self.scrollingDelegate respondsToSelector:@selector(scrollingViewDidEndScrolling:withVelocity:)]) {
            CGPoint target = [self.scrollingDelegate scrollingViewDidEndScrolling:self withVelocity:velocity];
            *targetContentOffset = target;
        }

    } else if (_pulling) {
        CGPoint currentOffset = scrollView.contentOffset;
        if (currentOffset.x > self.scrollViewEndOffset.x) {
            *targetContentOffset = self.scrollViewEndOffset;
        }
        if (currentOffset.x < self.scrollViewStartOffset.x) {
            *targetContentOffset = self.scrollViewStartOffset;
        }
        [self scrollingEnded:scrollView withVelocity:velocity];
    }
}
@end
