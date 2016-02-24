//
//  KYCircleMenu.m
//  KYCircleMenu
//
//  Created by Kaijie Yu on 2/1/12.
//  Copyright (c) 2012 Kjuly. All rights reserved.
//

#import "KYCircleMenu.h"

@interface KYCircleMenu () {
 @private
  NSInteger buttonCount_;
  CGRect    buttonOriginFrame_;
  
  NSString * buttonImageNameFormat_;
  NSString * centerButtonImageName_;
  NSString * centerButtonBackgroundImageName_;
  
  
  BOOL shouldRecoverToNormalStatusWhenViewWillAppear_;
}

@property (nonatomic, copy) NSString * buttonImageNameFormat,
                                     * centerButtonImageName,
                                     * centerButtonBackgroundImageName;

- (void)_setupNotificationObserver;

// Toggle menu beween open & closed
- (void)_toggle:(id)sender;
// Close menu to hide all buttons around
- (void)_close:(NSNotification *)notification;
// Update buttons' layout with the value of triangle hypotenuse that given
- (void)_updateButtonsLayoutWithTriangleHypotenuse:(CGFloat)triangleHypotenuse;
// Update button's origin value
- (void)_setButtonWithTag:(NSInteger)buttonTag origin:(CGPoint)origin;

@end


// Basic configuration for the Circle Menu
static CGFloat menuSize_,         // size of menu
               buttonSize_,       // size of buttons around
               centerButtonSize_; // size of center button
static CGFloat defaultTriangleHypotenuse_,
               minBounceOfTriangleHypotenuse_,
               maxBounceOfTriangleHypotenuse_,
               maxTriangleHypotenuse_;

static CGFloat startAngle_, endAngle_;  // SZD

@implementation KYCircleMenu

@synthesize menu           = menu_,
            centerButton   = centerButton_;
@synthesize isOpening      = isOpening_,
            isInProcessing = isInProcessing_,
            isClosed       = isClosed_;
@synthesize buttonImageNameFormat = buttonImageNameFormat_,
            centerButtonImageName = centerButtonImageName_,
  centerButtonBackgroundImageName = centerButtonBackgroundImageName_;

- (void)dealloc
{
  // Release subvies & remove notification observer
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// Designated initializer
- (instancetype)initWithButtonCount:(NSInteger)buttonCount
                           menuSize:(CGFloat)menuSize
                         buttonSize:(CGFloat)buttonSize
              buttonImageNameFormat:(NSString *)buttonImageNameFormat
                   centerButtonSize:(CGFloat)centerButtonSize
              centerButtonImageName:(NSString *)centerButtonImageName
    centerButtonBackgroundImageName:(NSString *)centerButtonBackgroundImageName
                startAngleInRadians:(CGFloat)startAngle
                  endAngleInRadians:(CGFloat)endAngle

{
  if (self = [self init]) {
    buttonCount_                     = buttonCount;
    menuSize_                        = menuSize;
    buttonSize_                      = buttonSize;
    buttonImageNameFormat_           = buttonImageNameFormat;
    centerButtonSize_                = centerButtonSize;
    centerButtonImageName_           = centerButtonImageName;
    centerButtonBackgroundImageName_ = centerButtonBackgroundImageName;
    
    startAngle_ = startAngle; // SZD 
    endAngle_ = endAngle;
    
    // Defualt value for triangle hypotenuse
    defaultTriangleHypotenuse_     = (menuSize - buttonSize) * .5f;
    minBounceOfTriangleHypotenuse_ = defaultTriangleHypotenuse_ - 12.f;
    maxBounceOfTriangleHypotenuse_ = defaultTriangleHypotenuse_ + 12.f;
    maxTriangleHypotenuse_         = kKYCircleMenuViewHeight * .5f;
    
    // Buttons' origin frame
    CGFloat originX = (menuSize_ - centerButtonSize_) * .5f;
    buttonOriginFrame_ =
      (CGRect){{originX, originX}, {centerButtonSize_, centerButtonSize_}};
  }
  return self;
}

// Secondary initializer
- (id)init
{
  if (self = [super init]) {
    isInProcessing_ = NO;
    isOpening_      = NO;
    isClosed_       = YES;
    shouldRecoverToNormalStatusWhenViewWillAppear_ = NO;
#ifndef KY_CIRCLEMENU_WITH_NAVIGATIONBAR
    [self.navigationController setNavigationBarHidden:YES];
#endif
  }
  return self;
}

- (void)didReceiveMemoryWarning
{
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
  CGFloat viewHeight =
    (self.navigationController.isNavigationBarHidden
      ? kKYCircleMenuViewHeight : kKYCircleMenuViewHeight - kKYCircleMenuNavigationBarHeight);
  CGRect frame = CGRectMake(0.f, 0.f, kKYCircleMenuViewWidth, viewHeight);
  UIView * view = [[UIView alloc] initWithFrame:frame];
  self.view = view;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // Constants
  CGFloat viewHeight = CGRectGetHeight(self.view.frame);
  CGFloat viewWidth  = CGRectGetWidth(self.view.frame);
  
  // Center Menu View
  CGRect centerMenuFrame =
    CGRectMake((viewWidth - menuSize_) * .5f, (viewHeight - menuSize_) * .5f, menuSize_, menuSize_);
  menu_ = [[UIView alloc] initWithFrame:centerMenuFrame];
  [menu_ setAlpha:0.f];
  [self.view addSubview:menu_];
  
  // Add buttons to |ballMenu_|, set it's origin frame to center
  NSString * imageName = nil;
  for (int i = 1; i <= buttonCount_; ++i) {
    UIButton * button = [[UIButton alloc] initWithFrame:buttonOriginFrame_];
    [button setOpaque:NO];
    [button setTag:i];
    imageName = [NSString stringWithFormat:self.buttonImageNameFormat, button.tag];
    [button setImage:[UIImage imageNamed:imageName]
            forState:UIControlStateNormal];
    [button addTarget:self action:@selector(runButtonActions:) forControlEvents:UIControlEventTouchUpInside];
    [self.menu addSubview:button];
  }
  
  // Main Button
  CGRect mainButtonFrame =
    CGRectMake((CGRectGetWidth(self.view.frame) - centerButtonSize_) * .5f,
               (CGRectGetHeight(self.view.frame) - centerButtonSize_) * .5f,
               centerButtonSize_, centerButtonSize_);
  centerButton_ = [[UIButton alloc] initWithFrame:mainButtonFrame];
  [centerButton_ setBackgroundImage:[UIImage imageNamed:self.centerButtonBackgroundImageName]
                           forState:UIControlStateNormal];
  [centerButton_ setImage:[UIImage imageNamed:self.centerButtonImageName]
                 forState:UIControlStateNormal];
  [centerButton_ addTarget:self
                    action:@selector(_toggle:)
          forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:centerButton_];
  
  // Setup notification observer
  [self _setupNotificationObserver];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
#ifndef KY_CIRCLEMENU_WITH_NAVIGATIONBAR
  [self.navigationController setNavigationBarHidden:YES animated:YES];
#endif
  
  // If it is from child view by press the buttons,
  //   recover menu to normal state
  if (shouldRecoverToNormalStatusWhenViewWillAppear_)
    [self performSelector:@selector(recoverToNormalStatus)
               withObject:nil
               afterDelay:.3f];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  // Return YES for supported orientations
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Publich Button Action

// Run action depend on button, it'll be implemented by subclass
- (void)runButtonActions:(id)sender
{
#ifndef KY_CIRCLEMENU_WITH_NAVIGATIONBAR
  [self.navigationController setNavigationBarHidden:NO animated:YES];
#endif
  // Close center menu
//  [self _closeCenterMenuView:nil];
  shouldRecoverToNormalStatusWhenViewWillAppear_ = YES;
}

// Push View Controller
- (void)pushViewController:(id)viewController
{
  [UIView animateWithDuration:.3f
                        delay:0.f
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     // Slide away buttons in center view & hide them
                     [self _updateButtonsLayoutWithTriangleHypotenuse:maxTriangleHypotenuse_];
                     [self.menu setAlpha:0.f];
                     
                     /*/ Show Navigation Bar
                     [self.navigationController setNavigationBarHidden:NO];
                     CGRect navigationBarFrame = self.navigationController.navigationBar.frame;
                     if (navigationBarFrame.origin.y < 0) {
                       navigationBarFrame.origin.y = 0;
                       [self.navigationController.navigationBar setFrame:navigationBarFrame];
                     }*/
                   }
                   completion:^(BOOL finished) {
                     [self.navigationController pushViewController:viewController animated:YES];
                   }];
}

// Open center menu view
- (void)open
{
  if (isOpening_) return;
  
  isInProcessing_ = YES;
  // Show buttons with animation
  [UIView animateWithDuration:.3f
                        delay:0.f
                      options:UIViewAnimationCurveEaseInOut
                   animations:^{
                     [self.menu setAlpha:1.f];
                     // Compute buttons' frame and set for them, based on |buttonCount|
                     [self _updateButtonsLayoutWithTriangleHypotenuse:maxBounceOfTriangleHypotenuse_];
                   }
                   completion:^(BOOL finished) {
                     [UIView animateWithDuration:.1f
                                           delay:0.f
                                         options:UIViewAnimationCurveEaseInOut
                                      animations:^{
                                        [self _updateButtonsLayoutWithTriangleHypotenuse:defaultTriangleHypotenuse_];
                                      }
                                      completion:^(BOOL finished) {
                                        isOpening_ = YES;
                                        isClosed_ = NO;
                                        isInProcessing_ = NO;
                                      }];
                   }];
}

// Recover to normal status
- (void)recoverToNormalStatus
{
  [self _updateButtonsLayoutWithTriangleHypotenuse:maxTriangleHypotenuse_];
  [UIView animateWithDuration:.3f
                        delay:0.f
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     // Show buttons & slide in to center
                     [self.menu setAlpha:1.f];
                     [self _updateButtonsLayoutWithTriangleHypotenuse:minBounceOfTriangleHypotenuse_];
                   }
                   completion:^(BOOL finished) {
                     [UIView animateWithDuration:.1f
                                           delay:0.f
                                         options:UIViewAnimationOptionCurveEaseInOut
                                      animations:^{
                                        [self _updateButtonsLayoutWithTriangleHypotenuse:defaultTriangleHypotenuse_];
                                      }
                                      completion:nil];
                   }];
}

#pragma mark - Private Methods

// Setup notification observer
- (void)_setupNotificationObserver
{
  // Add Observer for close self
  // If |centerMainButton_| post cancel notification, do it
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_close:)
                                               name:kKYNCircleMenuClose
                                             object:nil];
}

// Toggle Circle Menu
- (void)_toggle:(id)sender
{
  (isClosed_ ? [self open] : [self _close:nil]);
}

// Close menu to hide all buttons around
- (void)_close:(NSNotification *)notification
{
  if (isClosed_)
    return;
  
  isInProcessing_ = YES;
  // Hide buttons with animation
  [UIView animateWithDuration:.3f
                        delay:0.f
                      options:UIViewAnimationCurveEaseIn
                   animations:^{
                     for (UIButton * button in [self.menu subviews])
                       [button setFrame:buttonOriginFrame_];
                     [self.menu setAlpha:0.f];
                   }
                   completion:^(BOOL finished) {
                     isClosed_       = YES;
                     isOpening_      = NO;
                     isInProcessing_ = NO;
                   }];
}

- (CGFloat)r2d:(CGFloat)radian
{
  return (radian * 180.0) / M_PI;
}

// Update buttons' layout with the value of triangle hypotenuse that given
- (void)_updateButtonsLayoutWithTriangleHypotenuse:(CGFloat)triangleHypotenuse
{
  NSLog(@"startAngle: %f | endAngle: %f | hypotenuse: %f\n", [self r2d:startAngle_], [self r2d:endAngle_], triangleHypotenuse);
  
  // Check if both angles are less than 2PI
  // Calculate menuAngle
  CGFloat menuAngle;
  if(startAngle_ > endAngle_) {
    menuAngle = (2 * M_PI) - (startAngle_ - endAngle_);
  } else {
    menuAngle = endAngle_ - startAngle_;
  }
  
  NSInteger numberOfDivisions = buttonCount_ + 1;
  CGFloat divisionAngle = menuAngle / numberOfDivisions;
  
  CGFloat center = menuSize_ *.5f;
  CGFloat buttonRadius = centerButtonSize_ *.5f;
  
  NSLog(@"menuAngle: %f | divisionAngle: %f | numberOfDivisions: %lu", [self r2d:menuAngle],
        [self r2d: divisionAngle], numberOfDivisions);
  
  CGFloat prevAngle = startAngle_;
  
  for(int i = 1; i < buttonCount_+1; i++) {
    CGFloat buttonAngle = prevAngle + divisionAngle;
    CGFloat relativeButtonAngle = buttonAngle;
    if(relativeButtonAngle >= 2*M_PI) {
      relativeButtonAngle -= 2*M_PI;
    }
    //NSLog(@"%lu", [self r2d:buttonAngle]);
    CGFloat qx = 1;
    CGFloat qy = 1;
    CGFloat x, y;
    
    // Determine quadrant
    NSInteger quadrant;
    if ((0 <= relativeButtonAngle && relativeButtonAngle <= M_PI_2)) {  // 0 to PI/2
      quadrant = 1;
      NSLog(@"Q1: %f", [self r2d:relativeButtonAngle]);
    } else if (M_PI_2 < relativeButtonAngle && relativeButtonAngle <= M_PI) { // PI/2 to PI
      quadrant = 2;
      relativeButtonAngle = M_PI - relativeButtonAngle;
      qx = -1;
      NSLog(@"Q2: %f", [self r2d:relativeButtonAngle]);
    } else if (M_PI < relativeButtonAngle && relativeButtonAngle < 3*M_PI_2) {  // PI to 3PI/2
      quadrant = 3;
      relativeButtonAngle = relativeButtonAngle - M_PI;
      qx = -1;
      qy = -1;
      NSLog(@"Q3: %f", [self r2d:relativeButtonAngle]);
    } else if (3*M_PI_2 <= relativeButtonAngle && relativeButtonAngle < 2*M_PI) {  // 3PI/2 to 2PI
      quadrant = 4;
      relativeButtonAngle = 2*M_PI - relativeButtonAngle;
      qy = -1;
      NSLog(@"Q4: %f", [self r2d:relativeButtonAngle]);
    } else {
      NSLog(@"Line: %f", [self r2d:relativeButtonAngle]);
    }
    
    CGFloat a = triangleHypotenuse * cosf(relativeButtonAngle);
    CGFloat b = triangleHypotenuse * sinf(relativeButtonAngle);
    //NSLog(@"%f %f", cosf(buttonAngle), triangleHypotenuse);
    
    x = a * qx;
    y = b * qy;
    NSLog(@"a:%f b:%f x:%f y:%f", a, b, x, y);
    

    CGFloat x2 = center - buttonRadius + x;
    CGFloat y2 = center - buttonRadius - y;
    
    [self _setButtonWithTag:i origin:CGPointMake(x2, y2)];
    
    prevAngle = buttonAngle;
  }
  /*
  //
  //  Triangle Values for Buttons' Position
  // 
  //      /|      a: triangleA = c * cos(x)
  //   c / | b    b: triangleB = c * sin(x)
  //    /)x|      c: triangleHypotenuse
  //   -----      x: degree
  //     a
  //
  CGFloat centerBallMenuHalfSize = menuSize_         * .5f;
  //CGFloat buttonRadius           = centerButtonSize_ * .5f;
  if (! triangleHypotenuse) triangleHypotenuse = defaultTriangleHypotenuse_; // Distance to Ball Center
  
  //
  //      o       o   o      o   o     o   o     o o o     o o o
  //     \|/       \|/        \|/       \|/       \|/       \|/
  //  1 --|--   2 --|--    3 --|--   4 --|--   5 --|--   6 --|--
  //     /|\       /|\        /|\       /|\       /|\       /|\
  //                           o       o   o     o   o     o o o
  //
  switch (buttonCount_) {
    case 1:
      [self _setButtonWithTag:1 origin:CGPointMake(centerBallMenuHalfSize - buttonRadius,
                                                  centerBallMenuHalfSize - triangleHypotenuse - buttonRadius)];
      break;
      
    case 2: {
      CGFloat degree    = M_PI / 4.0f; // = 45 * M_PI / 180
      CGFloat triangleB = triangleHypotenuse * sinf(degree);
      CGFloat negativeValue = centerBallMenuHalfSize - triangleB - buttonRadius;
      CGFloat positiveValue = centerBallMenuHalfSize + triangleB - buttonRadius;
      [self _setButtonWithTag:1 origin:CGPointMake(negativeValue, negativeValue)];
      [self _setButtonWithTag:2 origin:CGPointMake(positiveValue, negativeValue)];
      break;
    }
      
    case 3: {
      // = 360.0f / self.buttonCount * M_PI / 180.0f;
      // E.g: if |buttonCount_ = 6|, then |degree = 60.0f * M_PI / 180.0f|;
      // CGFloat degree = 2 * M_PI / self.buttonCount;
      //
      CGFloat degree    = M_PI / 3.0f; // = 60 * M_PI / 180
      CGFloat triangleA = triangleHypotenuse * cosf(degree);
      CGFloat triangleB = triangleHypotenuse * sinf(degree);
      [self _setButtonWithTag:1 origin:CGPointMake(centerBallMenuHalfSize - triangleB - buttonRadius,
                                                  centerBallMenuHalfSize - triangleA - buttonRadius)];
      [self _setButtonWithTag:2 origin:CGPointMake(centerBallMenuHalfSize + triangleB - buttonRadius,
                                                  centerBallMenuHalfSize - triangleA - buttonRadius)];
      [self _setButtonWithTag:3 origin:CGPointMake(centerBallMenuHalfSize - buttonRadius,
                                                  centerBallMenuHalfSize + triangleHypotenuse - buttonRadius)];
      break;
    }
      
    case 4: {
      CGFloat degree    = M_PI / 4.0f; // = 45 * M_PI / 180
      CGFloat triangleB = triangleHypotenuse * sinf(degree);
      CGFloat negativeValue = centerBallMenuHalfSize - triangleB - buttonRadius;
      CGFloat positiveValue = centerBallMenuHalfSize + triangleB - buttonRadius;
      [self _setButtonWithTag:1 origin:CGPointMake(negativeValue, negativeValue)];
      [self _setButtonWithTag:2 origin:CGPointMake(positiveValue, negativeValue)];
      [self _setButtonWithTag:3 origin:CGPointMake(negativeValue, positiveValue)];
      [self _setButtonWithTag:4 origin:CGPointMake(positiveValue, positiveValue)];
      break;
    }
      
    case 5: {
      CGFloat degree    = M_PI / 2.5f; // = 72 * M_PI / 180
      CGFloat triangleA = triangleHypotenuse * cosf(degree);
      CGFloat triangleB = triangleHypotenuse * sinf(degree);
      [self _setButtonWithTag:1 origin:CGPointMake(centerBallMenuHalfSize - triangleB - buttonRadius,
                                                  centerBallMenuHalfSize - triangleA - buttonRadius)];
      [self _setButtonWithTag:2 origin:CGPointMake(centerBallMenuHalfSize - buttonRadius,
                                                  centerBallMenuHalfSize - triangleHypotenuse - buttonRadius)];
      [self _setButtonWithTag:3 origin:CGPointMake(centerBallMenuHalfSize + triangleB - buttonRadius,
                                                  centerBallMenuHalfSize - triangleA - buttonRadius)];
      
      degree    = M_PI / 5.0f;  // = 36 * M_PI / 180
      triangleA = triangleHypotenuse * cosf(degree);
      triangleB = triangleHypotenuse * sinf(degree);
      [self _setButtonWithTag:4 origin:CGPointMake(centerBallMenuHalfSize - triangleB - buttonRadius,
                                                  centerBallMenuHalfSize + triangleA - buttonRadius)];
      [self _setButtonWithTag:5 origin:CGPointMake(centerBallMenuHalfSize + triangleB - buttonRadius,
                                                  centerBallMenuHalfSize + triangleA - buttonRadius)];
      break;
    }
      
    case 6: {
      CGFloat degree    = M_PI / 3.0f; // = 60 * M_PI / 180
      CGFloat triangleA = triangleHypotenuse * cosf(degree);
      CGFloat triangleB = triangleHypotenuse * sinf(degree);
      [self _setButtonWithTag:1 origin:CGPointMake(centerBallMenuHalfSize - triangleB - buttonRadius,
                                                  centerBallMenuHalfSize - triangleA - buttonRadius)];
      [self _setButtonWithTag:2 origin:CGPointMake(centerBallMenuHalfSize - buttonRadius,
                                                  centerBallMenuHalfSize - triangleHypotenuse - buttonRadius)];
      [self _setButtonWithTag:3 origin:CGPointMake(centerBallMenuHalfSize + triangleB - buttonRadius,
                                                  centerBallMenuHalfSize - triangleA - buttonRadius)];
      [self _setButtonWithTag:4 origin:CGPointMake(centerBallMenuHalfSize - triangleB - buttonRadius,
                                                  centerBallMenuHalfSize + triangleA - buttonRadius)];
      [self _setButtonWithTag:5 origin:CGPointMake(centerBallMenuHalfSize - buttonRadius,
                                                  centerBallMenuHalfSize + triangleHypotenuse - buttonRadius)];
      [self _setButtonWithTag:6 origin:CGPointMake(centerBallMenuHalfSize + triangleB - buttonRadius,
                                                  centerBallMenuHalfSize + triangleA - buttonRadius)];
      break;
    }
      
    default:
      break;
  }*/
}

// Set Frame for button with special tag
- (void)_setButtonWithTag:(NSInteger)buttonTag origin:(CGPoint)origin
{
  UIButton * button = (UIButton *)[self.menu viewWithTag:buttonTag];
  [button setFrame:CGRectMake(origin.x, origin.y, centerButtonSize_, centerButtonSize_)];
  button = nil;
}

@end
