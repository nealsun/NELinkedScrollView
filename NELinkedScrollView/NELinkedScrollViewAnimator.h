//
//  NELinkedScrollViewAnimator.h
//  PRIS_iPhone
//
//  Created by Sun on 14/8/18.
//
//

#import <Foundation/Foundation.h>

@class NELinkedScrollViewAnimator;

@protocol NELinkedScrollViewAnimatorDelegate <NSObject>

- (void)animationDidStart:(NELinkedScrollViewAnimator *)animator;
- (void)animationDidFinish:(NELinkedScrollViewAnimator *)animator;

@required
- (BOOL)flipToNextPage:(NELinkedScrollViewAnimator *)animator;
- (BOOL)flipToPreviousPage:(NELinkedScrollViewAnimator *)animator;

@end

@protocol NEAnimatorActionDelegate <NSObject>

@required
- (void)panGestureRecognized:(UIPanGestureRecognizer *)panGestureRecognizer;

@end

@interface NELinkedScrollViewAnimator : NSObject <NEAnimatorActionDelegate, UIGestureRecognizerDelegate>

@end
