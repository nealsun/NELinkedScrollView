//
//  NELinkedScrollViewAnimator.m
//  PRIS_iPhone
//
//  Created by Sun on 14/8/18.
//
//

#import "NELinkedScrollViewAnimator.h"

@implementation NELinkedScrollViewAnimator

- (void)panGestureRecognized:(UIPanGestureRecognizer *)panGestureRecognizer {
    /*
     Do Nothing! Subclass should implement this method
     */
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
@end
