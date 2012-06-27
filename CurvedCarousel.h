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
 
#import <UIKit/UIKit.h>
#define P(x,y) CGPointMake(x, y)

@protocol CurvedCarouselDataSource, CurvedCarouselDelegate;

@interface CurvedCarousel : UIView

typedef enum animTypes
{
    TYPE_INTRO,
    TYPE_NORMAL,
    TYPE_OUTRO
} AnimState;

@property (nonatomic, assign) IBOutlet id<CurvedCarouselDataSource> dataSource;
@property (nonatomic, assign) IBOutlet id<CurvedCarouselDelegate> delegate;
@property (nonatomic, retain, readonly) UIView *contentView;
@property (nonatomic, retain, readonly) NSArray *itemViews;
@property (nonatomic, readonly) NSInteger numberOfItems;
@property (nonatomic, assign) float scrollOffset;
@property (nonatomic, assign) float startOffset;
@property (nonatomic, assign) float lastOffset;
@property (nonatomic, assign) float endOffset;
@property (nonatomic, assign) BOOL scrolling;
@property (nonatomic, assign) NSTimeInterval scrollDuration;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) float currentVelocity;
@property (nonatomic, assign) NSTimer *timer;
@property (nonatomic, assign) NSTimeInterval previousTime;
@property (nonatomic, assign) NSInteger previousItemIndex;
@property (nonatomic, assign) float decelerationRate;
@property (nonatomic, assign) BOOL decelerating;
@property (nonatomic, assign) float previousTranslation;
@property (nonatomic, assign) CGSize contentOffset;
@property (nonatomic, retain) NSMutableArray *curvePoints;
@property (nonatomic, assign) int animType;
@property (nonatomic, assign) int mAnimIndex;


- (void)scrollToItemAtIndex:(NSInteger)index withDuration:(NSTimeInterval)time;
- (void)scrollToItemAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)animateCarousel:(int) type;

@end

@protocol CurvedCarouselDataSource <NSObject>

- (NSUInteger)numberOfItemsInCarousel:(CurvedCarousel *)carousel;
- (UIView *)carousel:(CurvedCarousel *)carousel viewForItemAtIndex:(NSUInteger)index;
- (NSArray*)pointsOfPath:(CurvedCarousel *)carousel;

@end

@protocol CurvedCarouselDelegate <NSObject>

@optional

- (void)carouselDidScroll:(CurvedCarousel *)carousel atIndex:(int) index;
- (void)carouselWillScroll:(CurvedCarousel *)carousel;

@end