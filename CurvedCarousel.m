/*******************************************************************************
 * This file is part of the C4MiOS_CurvedCarousel project.
 * 
 * Copyright (c) 2012 C4M PROD.
 * 
 * C4MiOS_CurvedCarousel is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * C4MiOS_CurvedCarousel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with C4MiOS_CurvedCarousel. If not, see <http://www.gnu.org/licenses/lgpl.html>.
 * 
 * Contributors:
 * C4M PROD - initial API and implementation
 ******************************************************************************/

#import "CurvedCarousel.h"
#import <QuartzCore/QuartzCore.h>

#define degreesToRadian(x) (M_PI * x / 180.0)
#define radiansToDegrees(x) {x * 180 / M_PI;
#define DEZOOM_FACTOR 0.70f
#define SCROLL_DURATION 0.4

@interface CurvedCarousel () <UIGestureRecognizerDelegate>

@property (nonatomic, retain) UIView*          contentView;
@property (nonatomic, retain) NSArray*         itemViews;

- (void) reloadData;

@end


@interface CurvedCarousel (PrivateMethods)
- (NSInteger)currentItemIndex;
@end

@implementation CurvedCarousel

@synthesize dataSource;
@synthesize delegate;
@synthesize itemViews;
@synthesize numberOfItems;
@synthesize contentView;
@synthesize scrollOffset;
@synthesize startOffset;
@synthesize lastOffset;
@synthesize endOffset;
@synthesize scrolling;
@synthesize scrollDuration;
@synthesize startTime;
@synthesize currentVelocity;
@synthesize timer;
@synthesize previousTime;
@synthesize previousItemIndex;
@synthesize decelerationRate;
@synthesize decelerating;
@synthesize previousTranslation;
@synthesize contentOffset;
@synthesize curvePoints;
@synthesize animType;
@synthesize mAnimIndex;


#pragma mark -
#pragma mark Setup

- (void)setup
{
    
    animType = TYPE_NORMAL;
	scrollOffset = 0;
    contentOffset = CGSizeZero;
    previousTranslation = 0;
    
	self.itemViews = [NSMutableArray array];
	
    contentView = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:contentView];
	
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
	panGesture.delegate = self;
    [contentView addGestureRecognizer:panGesture];
    [panGesture release];
    
}

- (id)initWithCoder:(NSCoder *)aDecoder
{	
	if ((self = [super initWithCoder:aDecoder]))
    {
		[self setup];
        [self reloadData];
	}
	return self;
}

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
    {
		[self setup];
	}
	return self;
}

- (void)setDataSource:(id<CurvedCarouselDataSource>)_dataSource
{
    dataSource = _dataSource;
    [self reloadData];
}

- (void)transformForItemView:(UIView *)view withOffset:(float)offset
{
    //float scale = 1 - ((((int)view.layer.timeOffset)%100)*0.01f)*DEZOOM_FACTOR;
    float scale = 1/(fmodf(view.layer.timeOffset,100)*0.1f+1) + 0.3;  //y = 1/(x+1) + 0.3
    view.layer.timeOffset += offset;
    
    //WORKAROUND when moving backward
    if (view.layer.timeOffset < ([itemViews indexOfObject:view]+0.5)*(100/numberOfItems) ) view.layer.timeOffset+=100;
    
    //layer not updated if offset goes backward
    view.layer.speed = 1.0;
    [view.layer setTransform:CATransform3DMakeScale( scale, scale, 1.0 )];
    
    view.layer.speed = 0.0;
    
    //VERY BAD!!---
    view.layer.position = P(((((int)view.layer.timeOffset)%100)*contentView.bounds.size.width/100)+20, contentView.bounds.size.height/2);
    //---
}

- (void) faderEdges:(UIView*) view
{
    if ((((int)view.layer.timeOffset)%100) > 90)
    {
        view.layer.opacity = 1 - ((((int)view.layer.timeOffset)%100)-90)*0.1f;
    } else if ((((int)view.layer.timeOffset)%100) < 10){
        view.layer.opacity = (((int)view.layer.timeOffset)%100)*0.1f;
    }
    else {
        view.layer.opacity = 1.0;
    }
}
- (void) reloadData {
    
    self.curvePoints = [NSMutableArray arrayWithArray:[dataSource pointsOfPath:self]];
    
    CGMutablePathRef path = CGPathCreateMutable();
    for (int i = 0; i<[self.curvePoints count]; i++)
    {
        NSValue *v = [self.curvePoints objectAtIndex:i];
        if (i==0){
            CGPathMoveToPoint(path,NULL,[v CGPointValue].x,[v CGPointValue].y);
        } else {
            CGPathAddLineToPoint(path, NULL, [v CGPointValue].x,[v CGPointValue].y);
        }
    }
    
//    CAShapeLayer *shape = [CAShapeLayer layer];
//    shape.path = path;
//    shape.strokeColor = [UIColor whiteColor].CGColor;
//    shape.fillColor = [UIColor clearColor].CGColor;
//    shape.lineWidth = 1.0;
//    [contentView.layer addSublayer:shape];
    
    //remove old views
    for (UIView *view in itemViews)
    {
		[view.superview removeFromSuperview];
	}
    
    //load new views
	numberOfItems = [dataSource numberOfItemsInCarousel:self];
	self.itemViews = [NSMutableArray arrayWithCapacity:numberOfItems];
	for (NSUInteger i = 0; i < numberOfItems; i++)
    {
        UIView *view = [dataSource carousel:self viewForItemAtIndex:i];
        if (view == nil)
        {
			view = [[[UIView alloc] init] autorelease];
        }
        
        //LAYER PROPERTIES
        view.layer.speed = 0.0;
        view.layer.beginTime = 0.0;
        view.layer.autoreverses = YES;
        view.layer.beginTime = 0;
        view.layer.timeOffset = (i+0.5)*(100/numberOfItems);
        view.layer.opacity = 0.0;
        
        //float scale = 1 - ((((int)view.layer.timeOffset)%100)*0.01f)*DEZOOM_FACTOR;   //linear
        float scale = 1/(fmodf(view.layer.timeOffset,100)*0.1f+1) + 0.3;  //y = 1/(x+1) + 0.3
        [view.layer setTransform:CATransform3DMakeScale( scale, scale, 1.0 )];

        //LAYER ANIMATION
        CAKeyframeAnimation* anim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        //anim.autoreverses = YES;
        anim.beginTime = 0.0;
        anim.path = path;
        anim.repeatCount = HUGE_VALF;
        anim.calculationMode = kCAAnimationLinear;
        anim.removedOnCompletion = NO;
        anim.duration = 100.0;
        anim.speed = 1.0;
        anim.beginTime = 0;
        anim.timeOffset = (i+0.5)*(100/numberOfItems);
        NSArray *times = [NSArray arrayWithObjects:
            [NSNumber numberWithFloat:0.0f],
            [NSNumber numberWithFloat:0.2f],
            [NSNumber numberWithFloat:0.4f],
            [NSNumber numberWithFloat:0.6f],
            [NSNumber numberWithFloat:0.8f],
            [NSNumber numberWithFloat:1.0f],nil];    
        [anim setKeyTimes:times];
        NSArray *timingFunctions = [NSArray arrayWithObjects:
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
            nil];
        [anim setTimingFunctions:timingFunctions];
        [view.layer addAnimation:anim forKey:@"curvedCarousel"];
        
        [(NSMutableArray *)itemViews addObject:view];
        [contentView addSubview:view];
	}
    
    CGPathRelease(path); //@@@ added by niki: was memory leak
    
    [self layoutSubviews];
}

- (void)layoutSubviews
{
    contentView.frame = self.bounds;
    
    if ([delegate respondsToSelector:@selector(carouselDidScroll:atIndex:)])
    {
        [delegate carouselDidScroll:self atIndex:0];
    }
}

#pragma mark -
#pragma mark Animation

- (void)didMoveToSuperview
{
	if (self.superview)
	{
		[self reloadData];
		[timer invalidate];
		self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0 target:self selector:@selector(step) userInfo:nil repeats:YES];
	}
	else
	{
		[timer invalidate];
		timer = nil;
	}
}

- (void)doScroll
{	
    //NSLog(@"doScroll");
    
    for (int i = 0; i<numberOfItems; i++)
    {
        UIView *view = [itemViews objectAtIndex:i];
        [self transformForItemView:view withOffset:scrollOffset];
        
        view = [itemViews objectAtIndex:i];
        if (animType == TYPE_INTRO) {
            
            UIView *first = [itemViews objectAtIndex:0];
            
            if ((((int)view.layer.timeOffset)%100) < (((int)first.layer.timeOffset)%100)){
                view.layer.opacity = 0.0;
            }
            else {
                [self faderEdges:view];
            }
            
        } else if (animType == TYPE_OUTRO) {
            
            UIView *first = [itemViews objectAtIndex:(mAnimIndex==numberOfItems?0:mAnimIndex)];
            
            if ((((int)view.layer.timeOffset)%100) > (((int)first.layer.timeOffset)%100)){
                view.layer.opacity = 0.0;
            }
            else {
                [self faderEdges:view];
            }
        } else {
            [self faderEdges:view];
        }
        
        int index = (numberOfItems-[self currentItemIndex]);
        index = (index==numberOfItems?0:index);
        
        //only first item clickable
        view.userInteractionEnabled = (i == index);
    }
    
}

- (void)step
{
    NSTimeInterval currentTime = CACurrentMediaTime();
    previousTime = currentTime;
    
    if (scrolling)
    {
        NSTimeInterval time = (currentTime - startTime ) / scrollDuration;
        if (time >= 1.0)
        {
            time = 1.0;
            scrolling = NO;
            int index = (numberOfItems-[self currentItemIndex]);

            if ([delegate respondsToSelector:@selector(carouselDidScroll:atIndex:)])
            {
                [delegate carouselDidScroll:self atIndex:((index==numberOfItems?0:index))];
            }
        }
        float delta = (time < 0.5f)? 0.5f * pow(time * 2.0, 3.0): 0.5f * pow(time * 2.0 - 2.0, 3.0) + 1.0; //ease in/out
        float currOffset = startOffset + (endOffset - startOffset) * delta;
        
        scrollOffset = currOffset - startOffset - lastOffset;
        lastOffset = currOffset - startOffset;
        //NSLog(@"startOffset=%f endOffset=%f currOffset=%f scrollOffset=%f", startOffset, endOffset,currOffset, scrollOffset);
        [self doScroll];
    }
    else if (decelerating)
    {
        decelerating = NO;
        [self scrollToItemAtIndex:[self currentItemIndex] animated:YES];
    }
}

- (void)scrollToItemAtIndex:(NSInteger)index withDuration:(NSTimeInterval)time
{	
	
    scrolling = YES;
    lastOffset = 0;
    startTime = CACurrentMediaTime();
    scrollDuration = time;
    
    endOffset = (int)((index+0.5)*(100/numberOfItems));
}

- (void)scrollToItemAtIndex:(NSInteger)index animated:(BOOL)animated
{	
    [self scrollToItemAtIndex:(NSInteger)index withDuration:SCROLL_DURATION];
}

- (NSInteger)currentItemIndex
{	
    UIView *view = [itemViews objectAtIndex:0];
    int index = (int)((((int)view.layer.timeOffset)%100)/(100/numberOfItems));
    return (index<=0)?0:index;
}

- (NSInteger)viewItemIndex:(UIView*) view
{	
    int index = (int)((((int)view.layer.timeOffset)%100)/(100/numberOfItems));
    return (index<=0)?0:index;
}

- (void)animateCarousel:(int) type
{	
    
    animType = type;
    
    if (type == TYPE_INTRO) {
        
        mAnimIndex = 0;
        
        //Shift right immediately
        scrollOffset = 100 - 50/numberOfItems;
        [self doScroll];
        
        for (int i = 0; i<numberOfItems; i++)
        {
            UIView *view = [itemViews objectAtIndex:i];
            view.layer.opacity = 0.0;
        }
        
        startOffset = 100;
        [self scrollToItemAtIndex:0 withDuration:1.0];
        
    }
    else {
        
        mAnimIndex = (numberOfItems-[self currentItemIndex]);
        
        scrollOffset = 100;
        [self doScroll];
        
        for (int i = 0; i<numberOfItems; i++)
        {
            UIView *view = [itemViews objectAtIndex:i];
            view.layer.opacity = 1.0;
        }
        
        startOffset = 100;
        [self scrollToItemAtIndex:-1 withDuration:1.0];
    }
}

#pragma mark -
#pragma mark Touch

- (void)didPan:(UIPanGestureRecognizer *)panGesture
{
    animType = TYPE_NORMAL;
    switch (panGesture.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            scrolling = NO;
            decelerating = NO;
            previousTranslation = [panGesture translationInView:self].x;
            
            if ([delegate respondsToSelector:@selector(carouselWillScroll:)])
            {
                [delegate carouselWillScroll:self];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            decelerating = YES;
        }
        default:
        {
            scrollOffset = (([panGesture translationInView:self].x - previousTranslation)/contentView.bounds.size.width)*100;
            
            previousTranslation = [panGesture translationInView:self].x;
            
            UIView *view = [itemViews objectAtIndex:0];
            startOffset = (((int)view.layer.timeOffset)%100);
            
            [self doScroll];
        }
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    animType = TYPE_NORMAL;
    UITouch *currentTouch = [touches anyObject];
    CGPoint currPoint = [currentTouch locationInView:self];
    
    //NOT GOOD -> position item can be different from nb segments!!!
    int position = 0;
    for (int i = 0; i<[self.curvePoints count]-1; i++)
    {
        NSValue *v1 = [self.curvePoints objectAtIndex:i];
        NSValue *v2 = [self.curvePoints objectAtIndex:i+1];
        if (currPoint.x > [v1 CGPointValue].x && currPoint.x <= [v2 CGPointValue].x && currPoint.y < ([v1 CGPointValue].y+30)){
            position = i;
            break;
        }
    }
    
    if(position!=0) {
    
        if ([delegate respondsToSelector:@selector(carouselWillScroll:)])
        {
            [delegate carouselWillScroll:self];
        }
        
        startOffset = (position+0.5)*(100/numberOfItems);
        [self scrollToItemAtIndex:0 animated:YES];
    }
    
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture
{
    //NSLog(@"gestureRecognizerShouldBegin class=%@", [gesture class]);
	if ([gesture isKindOfClass:[UITapGestureRecognizer class]])
	{
		//if side items are tapped, center them
		UIView *itemView = [gesture.view.subviews objectAtIndex:0];
		NSInteger index = [itemViews indexOfObject:itemView];
		return (index != self.currentItemIndex);
	}
//	else if ([gesture isKindOfClass:[UIPanGestureRecognizer class]])
//	{
//		//ignore vertical swipes
//		UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gesture;
//		CGPoint translation = [panGesture translationInView:self];
//		return fabs(translation.x) >= fabs(translation.y);
//	}
	return YES;
}


#pragma mark -
#pragma mark Memory

- (void)dealloc {
    [super dealloc];
    [timer invalidate];
    [contentView release];
    [itemViews release];
}


@end
