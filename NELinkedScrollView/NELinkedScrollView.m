//
//  NELinkedScrollView.m
//  PRIS_iPhone
//
//  Created by Sun on 14/6/9.
//
//

#import "NELinkedScrollView.h"

@interface NELinkedScrollView () <UIGestureRecognizerDelegate>

@property(nonatomic, strong) NELinkedScrollCell *currentCell;
@property(nonatomic, strong) NELinkedScrollCell *interimCell;
@property(nonatomic, strong) NSMutableDictionary *reusableCells;

@property(nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

@end

@implementation NELinkedScrollView {
    CGPoint _initOffset; //外层拖动时的起始偏移
    CGPoint _lastOffset; //外层拖动时上次的偏移
    CGPoint _cellInitOffset; // cell的拖动时起始偏移
    CGPoint _cellLastOffset; // cell上次的偏移，用来记录取消
    NSInteger _directon; // 0中间 1next -1previous
    BOOL _innerAnimation;  //表示cell在切换
    BOOL _outterAnimation; //表示正在外层切换
                           //    BOOL    _forward;           //向前还是向后翻页 yes向前 no向后；
    CGPoint _currentOffset;
    CGPoint _forwardOffset;
    
    BOOL _canceled;
}

- (NSString *)debugDescription {
    NSString *debugString = [super debugDescription];
    NSMutableString *detail = [NSMutableString new];
    [detail appendString:@"<reuseCell:"];
    for (NSString *key in [self.reusableCells allKeys]) {
        for (NELinkedScrollCell *cell in self.reusableCells[key]) {
            [detail appendString:[cell debugDescription]];
        }
    }
    [detail appendString:@">"];
    [detail
        appendString:[NSString
                         stringWithFormat:@"<currentCell:%@>",
                                          [self.currentCell debugDescription]]];
    [detail
        appendString:[NSString
                         stringWithFormat:@"<interimCell:%@>",
                                          [self.interimCell debugDescription]]];
    return [NSString stringWithFormat:@"%@\n%@", debugString, detail];
}

- (void)commonInit {
    CGRect frame = [self bounds];
    _containerScrollView = [[UIScrollView alloc] initWithFrame:[self bounds]];
    _containerScrollView.pagingEnabled = YES;
    _containerScrollView.scrollEnabled = NO;
    _containerScrollView.showsHorizontalScrollIndicator = NO;
    _containerScrollView.showsVerticalScrollIndicator = NO;
    _containerScrollView.contentSize =
        CGSizeMake(3 * frame.size.width, frame.size.height);
    _containerScrollView.contentOffset = CGPointMake(frame.size.width, 0);
//    _containerScrollView.delegate = self;
    [self addSubview:_containerScrollView];
    _containerScrollView.backgroundColor = [UIColor clearColor];

    //  添加tap手势
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(tapGestureAction:)];
    [self.containerScrollView addGestureRecognizer:tap];
    [tap setDelegate:self];

    _reusableCells = [@{} mutableCopy];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/
- (void)setCurrentCell:(NELinkedScrollCell *)currentCell {
    _currentCell = currentCell;
    _currentCell.scrollView.scrollEnabled = self.animator ? NO : YES;
}

- (void)setInterimCell:(NELinkedScrollCell *)interimCell {
    _interimCell = interimCell;
    _interimCell.scrollView.scrollEnabled = self.animator ? NO : YES;
}

- (void)setAnimator:
            (NELinkedScrollViewAnimator<UIGestureRecognizerDelegate,
                                        NEAnimatorActionDelegate> *)animator {
    _animator = animator;
    if (_animator) {
//        self.containerScrollView.scrollEnabled = NO;
        self.currentCell.scrollView.scrollEnabled = NO;
        self.interimCell.scrollView.scrollEnabled = NO;
        if (_panGestureRecognizer) {
            [self removeGestureRecognizer:_panGestureRecognizer];
            _panGestureRecognizer = nil;
        }
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc]
            initWithTarget:_animator
                    action:@selector(panGestureRecognized:)];
        _panGestureRecognizer.delegate = _animator;
        [self addGestureRecognizer:_panGestureRecognizer];
    } else {
//        self.containerScrollView.scrollEnabled = YES;
        self.currentCell.scrollView.scrollEnabled = YES;
        self.interimCell.scrollView.scrollEnabled = YES;
        if (_panGestureRecognizer) {
            [self removeGestureRecognizer:_panGestureRecognizer];
            _panGestureRecognizer = nil;
        }
    }
}

- (BOOL)isScrolling {
    return self.containerScrollView.isDragging ||
           self.containerScrollView.isDecelerating ||
           self.currentCell.scrollView.isDecelerating ||
           self.currentCell.scrollView.isDragging;
}

- (BOOL)isAnimating {
    return _outterAnimation || _innerAnimation;
}

#pragma mark - public interface
- (void)currentCellScrollToOffset:(CGPoint)offset animated:(BOOL)animated {
    if (!self.currentCell) {
        return;
    }
    CGPoint currentOffset = self.currentCell.scrollView.contentOffset;
    if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                         currentCell:
                                                  willTurnFromOffset:
                                                            toOffset:)]) {
        [self.delegate linkedScrollView:self
                            currentCell:self.currentCell
                     willTurnFromOffset:currentOffset
                               toOffset:CGPointMake(currentOffset.x +
                                                        self.currentCell.bounds.size.width * PLUS_SCALE_RATIO,
                                                    0)];
    }

    [self.currentCell.scrollView setContentOffset:offset animated:animated];

    if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                         currentCell:
                                                   didTurnFromOffset:
                                                            toOffset:)]) {
        [self.delegate linkedScrollView:self
                            currentCell:self.currentCell
                      didTurnFromOffset:currentOffset
                               toOffset:CGPointMake(currentOffset.x +
                                                        self.currentCell.bounds
                                                            .size.width * PLUS_SCALE_RATIO,
                                                    0)];
    }
}

//在offsetbegin和end范围之内， 页内滚动，超出了切换前后cell
- (BOOL)scrollToNextPageAnimated:(BOOL)animated {
    if (_outterAnimation) {
        [self removeContainerAnimation];
    }
    if (_innerAnimation) {
        [self removeCurrentCellAnimation];
    }
    CGPoint currentOffset = self.currentCell.scrollView.contentOffset;

    if (self.currentCell.scrollView.contentOffset.x <
        self.currentCell.scrollViewEndOffset.x) {
        //页内
        if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                             currentCell:
                                                      willTurnFromOffset:
                                                                toOffset:)]) {
            [self.delegate
                  linkedScrollView:self
                       currentCell:self.currentCell
                willTurnFromOffset:self.currentCell.scrollView.contentOffset
                          toOffset:CGPointMake(
                                       currentOffset.x +
                                           self.currentCell.bounds.size.width * PLUS_SCALE_RATIO,
                                       0)];
        }

        if (animated) {
            [self
                animationView:self.currentCell.scrollView
                   fromBounds:CGRectMake(
                                  self.currentCell.scrollView.contentOffset.x,
                                  0, self.currentCell.frame.size.width,
                                  self.currentCell.frame.size.height)
                     toBounds:CGRectMake(
                                  self.currentCell.scrollView.contentOffset.x +
                                      self.currentCell.frame.size.width * PLUS_SCALE_RATIO,
                                  0, self.currentCell.frame.size.width,
                                  self.currentCell.frame.size.height)
                        delta:0
                          key:@"innerBoundsAnimation"];
            _innerAnimation = YES;
            _currentOffset = self.currentCell.scrollView.contentOffset;
            _forwardOffset = CGPointMake(
                currentOffset.x + self.currentCell.bounds.size.width * PLUS_SCALE_RATIO, 0);
            [self.currentCell.scrollView
                setContentOffset:CGPointMake(
                                     currentOffset.x +
                                         self.currentCell.bounds.size.width * PLUS_SCALE_RATIO,
                                     0)
                        animated:NO];
        } else {
            CGPoint currentOffset = self.currentCell.scrollView.contentOffset;
            [self.currentCell.scrollView
                setContentOffset:CGPointMake(
                                     currentOffset.x +
                                         self.currentCell.bounds.size.width * PLUS_SCALE_RATIO,
                                     0)
                        animated:NO];
            if ([self.delegate
                    respondsToSelector:@selector(linkedScrollView:
                                                      currentCell:
                                                didTurnFromOffset:
                                                         toOffset:)]) {
                [self.delegate
                     linkedScrollView:self
                          currentCell:self.currentCell
                    didTurnFromOffset:currentOffset
                             toOffset:CGPointMake(currentOffset.x +
                                                      self.currentCell.bounds
                                                          .size.width * PLUS_SCALE_RATIO,
                                                  0)];
            }
        }

    } else {
        //页间
        NELinkedScrollCell *newCell =
            [self.dataSource linkedScrollView:self
                                cellAfterCell:self.currentCell];
        if (newCell) {

            if (_innerAnimation) {
                //切换cell, 把原来页内翻页的动画去掉
                [self removeCurrentCellAnimation];
            }

            CGRect frame = self.currentCell.frame;
            frame.origin.x += self.bounds.size.width;
            newCell.frame = frame;
            if (newCell.superview != self.containerScrollView) {
                [self.containerScrollView addSubview:newCell];
            }
            [newCell cellWillAddtoLinkedScrollView:self];
            [self.containerScrollView bringSubviewToFront:newCell];
            if (self.interimCell) {
                [self inqueueReusableCell:self.interimCell];
                self.interimCell = nil;
            }
            self.interimCell = newCell;
            newCell.hidden = NO;
            if ([self.delegate
                    respondsToSelector:@selector(linkedScrollView:
                                               willScrollFromCell:
                                                           toCell:)] &&
                self.interimCell) {
                [self.delegate linkedScrollView:self
                             willScrollFromCell:self.currentCell
                                         toCell:self.interimCell];
            }
            // animation
            if (animated) {

                [self
                    animationView:self.containerScrollView
                       fromBounds:CGRectMake(
                                      self.containerScrollView.contentOffset.x,
                                      0,
                                      self.containerScrollView.frame.size.width,
                                      self.containerScrollView.frame.size
                                          .height)
                         toBounds:
                             CGRectMake(
                                 self.containerScrollView.contentOffset.x +
                                     self.containerScrollView.frame.size.width,
                                 0, self.containerScrollView.frame.size.width,
                                 self.containerScrollView.frame.size.height)
                            delta:0
                              key:@"outterBoundsAnimation"];
                [self.containerScrollView
                    setContentOffset:CGPointMake(self.containerScrollView
                                                         .contentOffset.x +
                                                     self.bounds.size.width,
                                                 0)
                            animated:NO];

                _outterAnimation = YES;
                //                _forward = NO;
            } else {
                [self.containerScrollView
                    setContentOffset:CGPointMake(self.containerScrollView
                                                         .contentOffset.x +
                                                     self.bounds.size.width,
                                                 0)
                            animated:NO];
                [self recenterIfNecessary];
                if ([self.delegate
                        respondsToSelector:@selector(linkedScrollView:
                                                    didScrollFromCell:
                                                               toCell:)] &&
                    self.interimCell) {
                    [self.delegate linkedScrollView:self
                                  didScrollFromCell:self.interimCell
                                             toCell:self.currentCell];
                }
            }

        } else {
            //抖一下？ 回调一个delegate， 嗯！

            if ([self.delegate
                    respondsToSelector:
                        @selector(linkedScrollViewScrolledToTheEnd:)]) {
                [self.delegate linkedScrollViewScrolledToTheEnd:self];
            }
            return NO;
        }
    }
    return YES;
}

- (BOOL)scrollToPreviousPageAnimated:(BOOL)animated {
    if (_outterAnimation) {
        [self removeContainerAnimation];
    }
    if (_innerAnimation) {
        [self removeCurrentCellAnimation];
    }
    CGPoint currentOffset = self.currentCell.scrollView.contentOffset;
    if (self.currentCell.scrollView.contentOffset.x >
        self.currentCell.scrollViewStartOffset.x) {
        NELinkedScrollCell *cell = self.currentCell;
        //页内
        if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                             currentCell:
                                                      willTurnFromOffset:
                                                                toOffset:)]) {
            [self.delegate
                  linkedScrollView:self
                       currentCell:cell
                willTurnFromOffset:cell.scrollView.contentOffset
                          toOffset:CGPointMake(
                                       currentOffset.x -
                                           self.currentCell.bounds.size.width * PLUS_SCALE_RATIO,
                                       0)];
        }
        if (animated) {
            [self animationView:cell.scrollView
                     fromBounds:CGRectMake(cell.scrollView.contentOffset.x, 0,
                                           cell.frame.size.width,
                                           cell.frame.size.height)
                       toBounds:CGRectMake(cell.scrollView.contentOffset.x -
                                               cell.frame.size.width * PLUS_SCALE_RATIO,
                                           0, cell.frame.size.width,
                                           cell.frame.size.height)
                          delta:0
                            key:@"innerBoundsAnimation"];
            _innerAnimation = YES;
            _currentOffset = cell.scrollView.contentOffset;
            _forwardOffset = CGPointMake(
                currentOffset.x - self.currentCell.bounds.size.width * PLUS_SCALE_RATIO, 0);
            [cell.scrollView
                setContentOffset:CGPointMake(currentOffset.x -
                                                 cell.bounds.size.width * PLUS_SCALE_RATIO,
                                             0)
                        animated:NO];
        } else {
            CGPoint currentOffset = self.currentCell.scrollView.contentOffset;
            [self.currentCell.scrollView
                setContentOffset:CGPointMake(
                                     currentOffset.x -
                                         self.currentCell.bounds.size.width * PLUS_SCALE_RATIO,
                                     0)
                        animated:NO];
            if ([self.delegate
                    respondsToSelector:@selector(linkedScrollView:
                                                      currentCell:
                                                didTurnFromOffset:
                                                         toOffset:)]) {
                [self.delegate
                     linkedScrollView:self
                          currentCell:self.currentCell
                    didTurnFromOffset:currentOffset
                             toOffset:CGPointMake(currentOffset.x -
                                                      self.currentCell.bounds
                                                          .size.width * PLUS_SCALE_RATIO,
                                                  0)];
            }
        }
    } else {
        //页间
        NELinkedScrollCell *newCell =
            [self.dataSource linkedScrollView:self
                             cellPreviousCell:self.currentCell];
        if (newCell) {

            if (_innerAnimation) {
                //切换cell, 把原来页内翻页的动画去掉
                [self removeCurrentCellAnimation];
            }

            CGRect frame = self.currentCell.frame;
            frame.origin.x -= self.bounds.size.width;
            newCell.frame = frame;
            if (newCell.superview != self.containerScrollView) {
                [self.containerScrollView addSubview:newCell];
            }
            [newCell cellWillAddtoLinkedScrollView:self];
            [newCell.scrollView setContentOffset:newCell.scrollViewEndOffset];
            [self.containerScrollView bringSubviewToFront:newCell];
            if (self.interimCell) {
                [self inqueueReusableCell:self.interimCell];
                self.interimCell = nil;
            }
            self.interimCell = newCell;
            newCell.hidden = NO;
            if ([self.delegate
                    respondsToSelector:@selector(linkedScrollView:
                                               willScrollFromCell:
                                                           toCell:)] &&
                self.interimCell) {
                [self.delegate linkedScrollView:self
                             willScrollFromCell:self.currentCell
                                         toCell:self.interimCell];
            }
            // animation
            if (animated) {

                [self
                    animationView:self.containerScrollView
                       fromBounds:CGRectMake(
                                      self.containerScrollView.contentOffset.x,
                                      0,
                                      self.containerScrollView.frame.size.width,
                                      self.containerScrollView.frame.size
                                          .height)
                         toBounds:
                             CGRectMake(
                                 self.containerScrollView.contentOffset.x -
                                     self.containerScrollView.frame.size.width,
                                 0, self.containerScrollView.frame.size.width,
                                 self.containerScrollView.frame.size.height)
                            delta:0
                              key:@"outterBoundsAnimation"];
                [self.containerScrollView
                    setContentOffset:CGPointMake(self.containerScrollView
                                                         .contentOffset.x -
                                                     self.bounds.size.width,
                                                 0)
                            animated:NO];

                _outterAnimation = YES;
                //                _forward = YES;
            } else {
                [self.containerScrollView
                    setContentOffset:CGPointMake(self.containerScrollView
                                                         .contentOffset.x -
                                                     self.bounds.size.width,
                                                 0)
                            animated:NO];
                [self recenterIfNecessary];
                if ([self.delegate
                        respondsToSelector:@selector(linkedScrollView:
                                                    didScrollFromCell:
                                                               toCell:)] &&
                    self.interimCell) {
                    [self.delegate linkedScrollView:self
                                  didScrollFromCell:self.interimCell
                                             toCell:self.currentCell];
                }
            }
        } else {
            //抖一下？ 回调一个delegate， 嗯！
            if ([self.delegate
                    respondsToSelector:
                        @selector(linkedScrollViewScrolledToTheEnd:)]) {
                [self.delegate linkedScrollViewScrolledToTheBegin:self];
            }
            return NO;
        }
    }
    return YES;
}

- (void)reloadDataOfCell:(NELinkedScrollCell *)cell {
    NSAssert(cell, @"cell 不能为空");
    if (self.interimCell) {
        [self inqueueReusableCell:self.interimCell];
        self.interimCell = nil;
    }
    // add cell to container
    CGRect frame = [cell frame];
    frame.origin.x = self.bounds.size.width;
    frame.size = self.bounds.size;
    cell.frame = frame;
    if (cell.superview != self.containerScrollView) {
        [self.containerScrollView addSubview:cell];
    }
    [cell cellWillAddtoLinkedScrollView:self];
    // set cell to visible
    NELinkedScrollCell *tmpCell = self.currentCell;
    if ([self.delegate
         respondsToSelector:@selector(linkedScrollView:willScrollFromCell:toCell:)]) {
        [self.delegate linkedScrollView:self willScrollFromCell:tmpCell toCell:cell];;
    }
    if (self.currentCell) {
        [self inqueueReusableCell:self.currentCell];
        self.currentCell = nil;
    }
    self.currentCell = cell;

    self.currentCell.hidden = NO;
    if ([self.delegate
            respondsToSelector:@selector(linkedScrollView:didScrollFromCell:toCell:)]) {
        [self.delegate linkedScrollView:self didScrollFromCell:tmpCell toCell:cell];
    }
}

- (NELinkedScrollCell *)dequeueReusableCellWithIdentifier:
                            (NSString *)identifier {
    NSMutableArray *array = [self.reusableCells objectForKey:identifier];
    NELinkedScrollCell *cell = [array firstObject];
    if (cell) {
        [array removeObject:cell];
    }
    return cell;
}

- (void)inqueueReusableCell:(NELinkedScrollCell *)cell {
    if (!cell.identifier) {
        cell.identifier = @"";
    }
    NSMutableArray *array = [self.reusableCells objectForKey:cell.identifier];
    if (!array) {
        array = [@[] mutableCopy];
        [self.reusableCells setObject:array forKey:cell.identifier];
    }
    [array addObject:cell];
    cell.hidden = YES;
}
#pragma mark - Layout
- (void)removeCurrentCellAnimation {
    CAAnimation *anim = [self.currentCell.scrollView.layer
        animationForKey:@"innerBoundsAnimation"];
    if (anim) {
        [self.currentCell.scrollView.layer
            removeAnimationForKey:@"innerBoundsAnimation"];
        if (_innerAnimation) {
            if (_canceled) {
                _canceled = NO;
            }else {
                if ([self.delegate
                     respondsToSelector:@selector(linkedScrollView:
                                                  currentCell:
                                                  didTurnFromOffset:
                                                  toOffset:)]) {
                         [self.delegate linkedScrollView:self
                                             currentCell:self.currentCell
                                       didTurnFromOffset:_currentOffset
                                                toOffset:_forwardOffset];
                     }
            }
            
            _innerAnimation = NO;
        }
    }
}

- (void)removeContainerAnimation {
    CAAnimation *anim = [self.containerScrollView.layer
        animationForKey:@"outterBoundsAnimation"];
    if (anim) {
        [self.containerScrollView.layer
            removeAnimationForKey:@"outterBoundsAnimation"];
        if (_outterAnimation) {
            if (_canceled) {
                _canceled = NO;
            }else {
                [self recenterIfNecessary];
                if ([self.delegate
                     respondsToSelector:@selector(linkedScrollView:
                                                  didScrollFromCell:
                                                  toCell:)] &&
                    self.interimCell) {
                    [self.delegate linkedScrollView:self
                                  didScrollFromCell:self.interimCell
                                             toCell:self.currentCell];
                }
            }
            
            _outterAnimation = NO;
        }
    }
}

- (void)animationView:(UIScrollView *)scrollView
           fromBounds:(CGRect)from
             toBounds:(CGRect)to
                delta:(CGFloat)deltaOffset
                  key:(NSString *)key {

    //    [self removeContainerAnimation];
    //    [self removeCurrentCellAnimation];
    CGFloat duration =
        deltaOffset == 0
            ? 0.35
            : (0.35 / scrollView.frame.size.width) * (scrollView.frame.size.width - fabs(deltaOffset));
    if (duration < 0.2) {
        duration = 0.2;
    }

    CAMediaTimingFunction *timing =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];

    CABasicAnimation *animation =
        [CABasicAnimation animationWithKeyPath:@"bounds"];
    animation.delegate = self;
    animation.fillMode = kCAFillModeForwards;
    animation.duration = duration;

    animation.timingFunction = timing;
    animation.removedOnCompletion = YES;
    if (scrollView != self.containerScrollView) {
        from.size.width  *= PLUS_SCALE_RATIO;
        from.size.height *= PLUS_SCALE_RATIO;
        to.size.height *= PLUS_SCALE_RATIO;
        to.size.width *= PLUS_SCALE_RATIO;
    }
    
    animation.fromValue = [NSValue valueWithCGRect:from];
    animation.toValue = [NSValue valueWithCGRect:to];
    [scrollView.layer addAnimation:animation forKey:key];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    //    [self recenterIfNecessary];
}

//// recenter content periodically
- (void)recenterIfNecessary {
    CGPoint currentOffset = self.containerScrollView.contentOffset;
    //    CGFloat contentWidth = self.containerScrollView.contentSize.width;
    CGFloat centerOffsetX = self.bounds.size.width;
    CGFloat distanceFromCenter = currentOffset.x - centerOffsetX;
    self.containerScrollView.contentOffset = CGPointMake(centerOffsetX, 0);
    CGFloat offsetWithBias =
        self.bounds.size.width - 5; //允许误差范围，防止paging
    if (distanceFromCenter >= offsetWithBias) {
        CGRect frame = self.currentCell.frame;
        frame.origin.x -= self.bounds.size.width;
        self.currentCell.frame = frame;
        frame = self.interimCell.frame;
        frame.origin.x = self.bounds.size.width;
        self.interimCell.frame = frame;
        [self cellExchange];
    } else if (distanceFromCenter <= -offsetWithBias) {
        CGRect frame = self.currentCell.frame;
        frame.origin.x += frame.size.width;
        self.currentCell.frame = frame;
        frame = self.interimCell.frame;
        frame.origin.x = self.bounds.size.width;
        self.interimCell.frame = frame;
        [self cellExchange];
    }else {
        DLog(@"container view not recenter");
    }
}

- (void)cellExchange {
    NELinkedScrollCell *tmp = self.currentCell;
    self.currentCell = self.interimCell;
    self.interimCell = tmp;
    tmp = nil;
}

#pragma mark - animation
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if (!flag) {
        return;
    }
    if (_innerAnimation) {
        if (_canceled) {
            _canceled = NO;
        }else {
            if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                            currentCell:
                                                            didTurnFromOffset:
                                                            toOffset:)]) {
                [self.delegate linkedScrollView:self
                                    currentCell:self.currentCell
                              didTurnFromOffset:_currentOffset
                                       toOffset:_forwardOffset];
            }
        }
        
        _innerAnimation = NO;
    }
    if (_outterAnimation) {
        if (_canceled) {
            _canceled = NO;
        }else {
            [self recenterIfNecessary];
            if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                            didScrollFromCell:
                                                            toCell:)] &&
                self.interimCell) {
                [self.delegate linkedScrollView:self
                              didScrollFromCell:self.interimCell
                                         toCell:self.currentCell];
            }
        }
        
        _outterAnimation = NO;
    }
}

#pragma mark - scrolling delegate
- (void)scrollingViewWillBeginPulling:(NELinkedScrollCell *)cell {
    [self.containerScrollView sendSubviewToBack:cell.scrollView];
    if (cell == self.currentCell) {
        _initOffset = self.containerScrollView.contentOffset;
        _lastOffset = _initOffset;
        _cellInitOffset = cell.scrollView.contentOffset;
        _cellLastOffset = _cellInitOffset;
    } else {
        if (_outterAnimation) {
            [self removeContainerAnimation];
        }
        _initOffset = self.containerScrollView.contentOffset;
        _lastOffset = _initOffset;
        _cellInitOffset = cell.scrollView.contentOffset;
        _cellLastOffset = _cellInitOffset;
    }
}

- (void)scrollingViewDidBeginPulling:(NELinkedScrollCell *)cell {
//    [self.containerScrollView setScrollEnabled:NO];
    NELinkedScrollCell *newCell;
    if (cell.scrollView.contentOffset.x > cell.scrollViewEndOffset.x) {
        newCell = [self.dataSource linkedScrollView:self cellAfterCell:cell];
        if (newCell) {

            if (_innerAnimation) {
                //切换cell, 把原来页内翻页的动画去掉
                [self removeCurrentCellAnimation];
            }

            CGRect frame = self.bounds;
            frame.origin.x = self.bounds.size.width + self.bounds.size.width;
            newCell.frame = frame;
            if (newCell.superview != self.containerScrollView) {
                [self.containerScrollView addSubview:newCell];
            }
            [newCell cellWillAddtoLinkedScrollView:self];
            [self.containerScrollView bringSubviewToFront:newCell];
            newCell.hidden = NO;
        } else {
            cell.scrollView.scrollEnabled = NO;
        }
        if (self.interimCell) {
            [self inqueueReusableCell:self.interimCell];
            self.interimCell = nil;
        }
        self.interimCell = newCell;
    } else if (cell.scrollView.contentOffset.x < cell.scrollViewStartOffset.x) {
        newCell = [self.dataSource linkedScrollView:self cellPreviousCell:cell];
        if (newCell) {

            if (_innerAnimation) {
                //切换cell, 把原来页内翻页的动画去掉
                [self removeCurrentCellAnimation];
            }

            CGRect frame = self.bounds;
            frame.origin.x = 0;//self.bounds.size.width - 320;
            newCell.frame = frame;
            if (newCell.superview != self.containerScrollView) {
                [self.containerScrollView addSubview:newCell];
            }
            [newCell cellWillAddtoLinkedScrollView:self];
            [newCell.scrollView setContentOffset:newCell.scrollViewEndOffset];
            [self.containerScrollView bringSubviewToFront:newCell];
            newCell.hidden = NO;
        } else {
            cell.scrollView.scrollEnabled = NO;
        }
        if (self.interimCell) {
            [self inqueueReusableCell:self.interimCell];
            self.interimCell = nil;
        }
        self.interimCell = newCell;
    }
    if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                  willScrollFromCell:
                                                              toCell:)] &&
        self.interimCell) {
        [self.delegate linkedScrollView:self
                     willScrollFromCell:self.currentCell
                                 toCell:self.interimCell];
    }
}

- (void)scrollingView:(NELinkedScrollCell *)cell
    didChangePullOffset:(CGFloat)offset {
    [self.containerScrollView
        setContentOffset:CGPointMake(_initOffset.x + offset, 0)];
    CGPoint currentOffset = CGPointMake(_initOffset.x + offset, 0);
    if (currentOffset.x > _initOffset.x) {
        if (_lastOffset.x > currentOffset.x) {
            _canceled = YES;
        } else {
            _canceled = NO;
        }
    } else if (currentOffset.x < _initOffset.x) {
        if (_lastOffset.x < currentOffset.x) {
            _canceled = YES;
        } else {
            _canceled = NO;
        }
    }
    _lastOffset.x = _initOffset.x + offset;
}

- (void)scrollingViewDidEndPulling:(NELinkedScrollCell *)cell withVelocity:(CGPoint)velocity {
//    [self.containerScrollView setScrollEnabled:YES];
    CGPoint targetOffset = _initOffset;
    CGPoint currentOffset = self.containerScrollView.contentOffset;
    CGFloat deltaOffset = currentOffset.x - _initOffset.x;
    cell.scrollView.scrollEnabled = YES;
    if (self.interimCell == nil) {
        if (cell.scrollView.contentOffset.x >= cell.scrollViewEndOffset.x) {
            if ([self.delegate
                    respondsToSelector:
                        @selector(linkedScrollViewScrolledToTheEnd:)]) {
                [self.delegate linkedScrollViewScrolledToTheEnd:self];
            }
        } else if (cell.scrollView.contentOffset.x <=
                   cell.scrollViewStartOffset.x) {
            if ([self.delegate
                    respondsToSelector:
                        @selector(linkedScrollViewScrolledToTheBegin:)]) {
                [self.delegate linkedScrollViewScrolledToTheBegin:self];
            }
        }
    } else {
//        if (fabsf(currentOffset.x - _initOffset.x) < 40 && velocity.x == 0) {
//            targetOffset = CGPointMake(_initOffset.x, 0);
//            _canceled = YES;
//        } else
        if (!_canceled) {
            if (currentOffset.x > _initOffset.x) {
                targetOffset =
                    CGPointMake(_initOffset.x + cell.bounds.size.width, 0);
            } else if (currentOffset.x < _initOffset.x) {
                targetOffset =
                    CGPointMake(_initOffset.x - cell.bounds.size.width, 0);
            }
        }
    }

    _outterAnimation = YES;
    
    [self animationView:self.containerScrollView
             fromBounds:CGRectMake(currentOffset.x, 0,
                                   self.containerScrollView.frame.size.width,
                                   self.containerScrollView.frame.size.height)
               toBounds:CGRectMake(targetOffset.x, 0,
                                   self.containerScrollView.frame.size.width,
                                   self.containerScrollView.frame.size.height)
                  delta:deltaOffset
                    key:@"outterBoundsAnimation"];
    [self.containerScrollView setContentOffset:CGPointMake(targetOffset.x, 0)
                                      animated:NO];
}

- (void)scrollingViewDidBeginScrolling:(NELinkedScrollCell *)cell {
//    _directon = 0;
    if (_innerAnimation) {
        //切换cell, 把原来页内翻页的动画去掉
        [self removeCurrentCellAnimation];
    }
    UIScrollView *cellScrollView = cell.scrollView;
    CGPoint contentOffset = cellScrollView.contentOffset;
    _cellLastOffset.x = contentOffset.x;
//    BOOL reverse = NO;
//    NSInteger directionForNow = 0;
//    if (contentOffset.x > _cellInitOffset.x) {
//        directionForNow = 1;
//    } else if (contentOffset.x < _cellInitOffset.x) {
//        directionForNow = -1;
//    }
//    
//    reverse = (directionForNow != _directon && directionForNow != 0 ? YES : NO);
//    _directon = directionForNow;
    
    if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                    currentCell:
                                                    willTurnFromOffset:
                                                    toOffset:)] /*&&
        reverse*/) {
        if (contentOffset.x > _cellInitOffset.x) {
            [self.delegate
             linkedScrollView:self
             currentCell:self.currentCell
             willTurnFromOffset:_cellInitOffset
             toOffset:CGPointMake(_cellInitOffset.x +
                                  cell.bounds.size.width * PLUS_SCALE_RATIO,
                                  _cellInitOffset.y)];
        } else {
            [self.delegate
             linkedScrollView:self
             currentCell:self.currentCell
             willTurnFromOffset:_cellInitOffset
             toOffset:CGPointMake(_cellInitOffset.x -
                                  cell.bounds.size.width * PLUS_SCALE_RATIO,
                                  _cellInitOffset.y)];
        }
    }
}

- (void)scrollingViewDidScrolling:(NELinkedScrollCell *)cell {
    UIScrollView *cellScrollView = cell.scrollView;
    CGPoint contentOffset = cellScrollView.contentOffset;
    CGFloat deltaOffset = contentOffset.x - _cellInitOffset.x;
    if (deltaOffset > 0) {
        if (_cellLastOffset.x > contentOffset.x) {
            _canceled = YES;
        } else {
            _canceled = NO;
        }
    } else if (deltaOffset < 0) {
        if (_cellLastOffset.x < contentOffset.x) {
            _canceled = YES;
        } else {
            _canceled = NO;
        }
    }
    _cellLastOffset.x = contentOffset.x;
}

- (CGPoint)scrollingViewDidEndScrolling:(NELinkedScrollCell *)cell withVelocity:(CGPoint)velocity{
    UIScrollView *cellScrollView = cell.scrollView;
    CGPoint contentOffset = cellScrollView.contentOffset;
    if ((int)_cellInitOffset.x % (int)(cell.bounds.size.width * PLUS_SCALE_RATIO) != 0) {
        //校准
        if (contentOffset.x > _cellInitOffset.x) {
            _cellInitOffset.x =
                ((int)(_cellInitOffset.x / (cell.bounds.size.width * PLUS_SCALE_RATIO))) *
                cell.bounds.size.width * PLUS_SCALE_RATIO;
        } else {
            _cellInitOffset.x =
                ((int)(_cellInitOffset.x / (cell.bounds.size.width * PLUS_SCALE_RATIO)) + 1) *
                cell.bounds.size.width * PLUS_SCALE_RATIO;
        }
    }

    CGFloat deltaOffset = contentOffset.x - _cellInitOffset.x;
    //    BOOL backToInit = NO;
    CGPoint targetOffset = _cellInitOffset;
//    if (fabsf(deltaOffset) < (40 * PLUS_SCALE_RATIO) && velocity.x == 0) {
//        targetOffset = CGPointMake(_cellInitOffset.x, 0);
//        _canceled = YES;
//    } else
    if (_canceled) {
        
    } else {
        if (deltaOffset > 0) {
            targetOffset =
            CGPointMake(_cellInitOffset.x + cell.bounds.size.width * PLUS_SCALE_RATIO, 0);
        } else if (deltaOffset < 0) {
            targetOffset =
            CGPointMake(_cellInitOffset.x - cell.bounds.size.width * PLUS_SCALE_RATIO, 0);
        }
    }
    

    _innerAnimation = YES;
    _currentOffset = _cellInitOffset;
    _forwardOffset = targetOffset;
    
    [self animationView:cell.scrollView
             fromBounds:CGRectMake(contentOffset.x, 0, cell.frame.size.width,
                                   cell.frame.size.height)
               toBounds:CGRectMake(targetOffset.x, 0, cell.frame.size.width,
                                   cell.frame.size.height)
                  delta:deltaOffset
                    key:@"innerBoundsAnimation"];
    [cell.scrollView setContentOffset:targetOffset animated:NO];
    return targetOffset;
}

- (void)scrollingView:(NELinkedScrollCell *)cell
       scrollToOffset:(CGPoint)offset
             animated:(BOOL)animated {
    if (animated) {

        [self animationView:cell.scrollView
                 fromBounds:CGRectMake(cell.scrollView.contentOffset.x, 0,
                                       cell.frame.size.width,
                                       cell.frame.size.height)
                   toBounds:CGRectMake(offset.x, 0, cell.frame.size.width,
                                       cell.frame.size.height)
                      delta:0
                        key:@"innerBoundsAnimation"];
        _innerAnimation = YES;
        _currentOffset = cell.scrollView.contentOffset;
        _forwardOffset = offset;

        [cell.scrollView setContentOffset:offset animated:NO];
    } else {
        CGPoint currentOffset = cell.scrollView.contentOffset;
        [cell.scrollView setContentOffset:offset animated:NO];
        if ([self.delegate respondsToSelector:@selector(linkedScrollView:
                                                             currentCell:
                                                       didTurnFromOffset:
                                                                toOffset:)]) {
            [self.delegate linkedScrollView:self
                                currentCell:self.currentCell
                          didTurnFromOffset:currentOffset
                                   toOffset:offset];
        }
    }
}

#pragma mark - tap gesture action
- (void)tapGestureAction:(id)sender {
    //    if (_outterAnimation) {
    //        return;
    //    }
    CGPoint location = [((UITapGestureRecognizer *)sender)locationInView:self];

    if (self.delegate &&
        [self.delegate respondsToSelector:@selector(linkedScrollView:
                                                           clickCell:
                                                          atLocation:)]) {
        [self.delegate linkedScrollView:self
                              clickCell:self.currentCell
                             atLocation:location];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
        (UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        if ([otherGestureRecognizer
                isKindOfClass:[UILongPressGestureRecognizer class]]) {
            if (otherGestureRecognizer.state !=
                UIGestureRecognizerStateFailed) {
                return NO;
            }
        }

        if ([otherGestureRecognizer
                isKindOfClass:[UISwipeGestureRecognizer class]]) {
            if (otherGestureRecognizer.state !=
                UIGestureRecognizerStateFailed) {
                return NO;
            }
        }

        if ([otherGestureRecognizer
                isKindOfClass:[UIPanGestureRecognizer class]]) {
            if (otherGestureRecognizer.state !=
                UIGestureRecognizerStateFailed) {
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIButton class]]) {

        return NO;
    }

    return YES;
}

@end
