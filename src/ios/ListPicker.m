#import "ListPicker.h"
#import <Cordova/CDVDebug.h>

#define IS_WIDESCREEN ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )
#define IS_IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
#define DEVICE_ORIENTATION [UIDevice currentDevice].orientation
#define EMPTY_ITEMS @[ @{ @"value": @"", @"text": @"" } ]
#define MAX_NUMBER_OF_COLUMNS 3

// UIInterfaceOrientationMask vs. UIInterfaceOrientation
// A function like this isn't available in the API. It is derived from the enum def for
// UIInterfaceOrientationMask.
#define OrientationMaskSupportsOrientation(mask, orientation)   ((mask & (1 << orientation)) != 0)


@implementation ListPicker

@synthesize callbackId = _callbackId;
@synthesize pickerView = _pickerView;
@synthesize popoverController = _popoverController;
@synthesize modalView = _modalView;
@synthesize options = _options;

- (int)rowOfValue:(NSString * )name inItems:(NSArray*)items {
  for(int i = 0; i < items.count; i++) {
    if([name isEqualToString:items[i][@"value"]]) {
      return i;
    }
  }
  return -1;
}

- (int)getNumberOfColumnsByItems:(NSArray *)items withIteration:(NSInteger)iteration {
    if (iteration > MAX_NUMBER_OF_COLUMNS || !items)
        return 0;

    NSInteger maxDepth = 0;
    for (NSDictionary *data in items) {
        NSDictionary *next = data[@"next"];
        NSInteger depth = 1 + [self getNumberOfColumnsByItems:next[@"items"] withIteration:iteration + 1];
        maxDepth = MAX(maxDepth, depth);
    }

    return maxDepth;
}

- (int)getNumberOfColumnsByItems:(NSArray *)items {
    return [self getNumberOfColumnsByItems:items withIteration:1];
}

- (void)showPicker:(CDVInvokedUrlCommand*)command {

    self.callbackId = command.callbackId;
    NSDictionary *options = command.arguments[0];
  
    // Compiling options with defaults
    NSString *title = options[@"title"] ?: @" ";
    NSString *doneButtonLabel = options[@"doneButtonLabel"] ?: @"Done";
    NSString *cancelButtonLabel = options[@"cancelButtonLabel"] ?: @"Cancel";

    // Hold items in an instance variable
    self.options = options;
    self.numberOfColumns = [self getNumberOfColumnsByItems:options[@"items"]];
    self.selectedRows = [NSMutableArray array];
    for (NSInteger i = 0; i < self.numberOfColumns; i++) {
        [self.selectedRows addObject:@(0)];
    }

    // Initialize the toolbar with Cancel and Done buttons and title
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame: CGRectMake(0, 0, self.viewSize.width, 44)];
    toolbar.barStyle = (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) ? UIBarStyleDefault : UIBarStyleBlackTranslucent;
    NSMutableArray *buttons =[[NSMutableArray alloc] init];
    
    // Create Cancel button
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]initWithTitle:cancelButtonLabel style:UIBarButtonItemStylePlain target:self action:@selector(didDismissWithCancelButton:)];
    [buttons addObject:cancelButton];
    
    // Create title label aligned to center and appropriate spacers
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [buttons addObject:flexSpace];
    UILabel *label =[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
    [label setTextAlignment:NSTextAlignmentCenter];
    [label setTextColor: (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) ? [UIColor blackColor] : [UIColor whiteColor]];
    [label setFont: [UIFont boldSystemFontOfSize:16]];
    [label setBackgroundColor:[UIColor clearColor]];
    label.text = title;
    UIBarButtonItem *labelButton = [[UIBarButtonItem alloc] initWithCustomView:label];
    [buttons addObject:labelButton];
    [buttons addObject:flexSpace];
     
     // Create Done button
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonLabel style:UIBarButtonItemStyleDone target:self action:@selector(didDismissWithDoneButton:)];
     [buttons addObject:doneButton];
     [toolbar setItems:buttons animated:YES];
     
    // Initialize the picker
    self.pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 40.0f, self.viewSize.width, 216)];
    self.pickerView.showsSelectionIndicator = YES;
    self.pickerView.delegate = self;

    // Define selected value
    if (options[@"selectedValue"] && [options[@"selectedValue"] isKindOfClass:[NSArray class]]) {
        NSDictionary *currentOptions = options;
        for (NSInteger i = 0; i < self.numberOfColumns && i < [options[@"selectedValue"] count]; i++) {
            int rowIndex = [self rowOfValue:options[@"selectedValue"][i] inItems:currentOptions[@"items"]];
            if (rowIndex == -1) {
                // reset other rows' index
                for (NSInteger j = i; j < self.numberOfColumns; j++) {
                    self.selectedRows[j] = @(0);
                }
                break;
            }
            [self.pickerView selectRow:rowIndex inComponent:i animated:NO];
            self.selectedRows[i] = @(rowIndex);
            currentOptions = currentOptions[@"items"][rowIndex][@"next"];
        }
    }
   
    // Initialize the View that should conain the toolbar and picker
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.viewSize.width, 260)];
    if(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
      [view setBackgroundColor:[UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1.0]];
    }
    [view addSubview: toolbar];
    
    //ios7 picker draws a darkened alpha-only region on the first and last 8 pixels horizontally, but blurs the rest of its background.  To make the whole popup appear to be edge-to-edge, we have to add blurring to the remaining left and right edges.
    if ( NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 )
    {
        CGRect f = CGRectMake(0, toolbar.frame.origin.y, 8, view.frame.size.height - toolbar.frame.origin.y);
        UIToolbar *leftEdge = [[UIToolbar alloc] initWithFrame:f];
        f.origin.x = view.frame.size.width - 8;
        UIToolbar *rightEdge = [[UIToolbar alloc] initWithFrame:f];
        [view insertSubview:leftEdge atIndex:0];
        [view insertSubview:rightEdge atIndex:0];
    }
    

    [view addSubview:self.pickerView];
  
    // Check if device is iPad to display popover
    if ( IS_IPAD ) {
        return [self presentPopoverForView:view];
    } else {
        return [self presentModalViewForView:view];
    }
}
     
-(void)presentModalViewForView:(UIView *)view {

    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didRotate:) 
                                                 name:UIApplicationWillChangeStatusBarOrientationNotification 
                                               object:nil];

    CGRect viewFrame = CGRectMake(0, 0, self.viewSize.width, self.viewSize.height);
    [view setFrame: CGRectMake(0, viewFrame.size.height, viewFrame.size.width, 260)];
    
    // Create the modal view to display
    self.modalView = [[UIView alloc] initWithFrame: viewFrame];
    [self.modalView setBackgroundColor:[UIColor clearColor]];
    [self.modalView addSubview: view];
    
    // Add the modal view to current controller
    [self.webView.superview addSubview:self.modalView];
    [self.webView.superview bringSubviewToFront:self.modalView];
    
    //Present the view animated
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options: 0
                     animations:^{
                         [self.modalView.subviews[0] setFrame:CGRectOffset(viewFrame, 0, viewFrame.size.height - 260)];;
                         [self.modalView setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.5]];
                     }
                     completion:nil];
}

-(void)presentPopoverForView:(UIView *)view {

    // Create a generic content view controller
    UIViewController* popoverContent = [[UIViewController alloc] initWithNibName:nil bundle:nil];
    popoverContent.view = view;

    // Resize the popover to the view's size
    popoverContent.preferredContentSize = view.frame.size;

    // Create a popover controller
    self.popoverController = [[UIPopoverController alloc] initWithContentViewController:popoverContent];
    self.popoverController.delegate = self;
    
    // display the picker at the center of the view
    CGRect sourceRect = CGRectMake(self.webView.superview.center.x, self.webView.superview.center.y, 1, 1);

    //present the popover view non-modal with a
    //refrence to the button pressed within the current view
    [self.popoverController presentPopoverFromRect:sourceRect
                                            inView:self.webView.superview
                          permittedArrowDirections: 0
                                          animated:YES];

}

//
// Dismiss methods
//

- (void) didRotate:(NSNotification *)notification
{
    UIInterfaceOrientationMask supportedInterfaceOrientations = (UIInterfaceOrientationMask) [[UIApplication sharedApplication]
                                                     supportedInterfaceOrientationsForWindow:
                                                     [UIApplication sharedApplication].keyWindow];

    if (OrientationMaskSupportsOrientation(supportedInterfaceOrientations, DEVICE_ORIENTATION)) {
        // Check if device is iPad
        if ( IS_IPAD ) {
            [self dismissPopoverController:self.popoverController withButtonIndex:0 animated:YES];
        } else {
            [self dismissModalView:self.modalView withButtonIndex:0 animated:YES];
        }
    }
}

// Picker with toolbar dismissed with done
- (IBAction)didDismissWithDoneButton:(id)sender {
    // Check if device is iPad
    if ( IS_IPAD ) {
        // Emulate a new delegate method
        [self dismissPopoverController:self.popoverController withButtonIndex:1 animated:YES];
    } else {
        [self dismissModalView:self.modalView withButtonIndex:1 animated:YES];
    }
}

// Picker with toolbar dismissed with cancel
- (IBAction)didDismissWithCancelButton:(id)sender {

    // Check if device is iPad
    if ( IS_IPAD ) {
        // Emulate a new delegate method
        [self dismissPopoverController:self.popoverController withButtonIndex:0 animated:YES];
    } else {
        [self dismissModalView:self.modalView withButtonIndex:0 animated:YES];
    }
}

// Popover generic dismiss - iPad
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {

    // Simulate a cancel click
    [self sendResultsFromPickerView:self.pickerView withButtonIndex:0];
}

// Popover emulated button-powered dismiss - iPad
- (void)dismissPopoverController:(UIPopoverController *)popoverController withButtonIndex:(NSInteger)buttonIndex animated:(Boolean)animated {
  
  // Manually dismiss the popover
  [popoverController dismissPopoverAnimated:animated];

  // Send the result according to the button selected
  [self sendResultsFromPickerView:self.pickerView withButtonIndex:buttonIndex];
}

// View generic dismiss - iPhone (iOS8)
- (void)dismissModalView:(UIView *)modalView withButtonIndex:(NSInteger)buttonIndex animated:(Boolean)animated {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillChangeStatusBarOrientationNotification
                                                  object:nil];
        
    //Hide the view animated and then remove it.
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options: 0
                     animations:^{
                        CGRect viewFrame = CGRectMake(0, 0, self.viewSize.width, self.viewSize.height);
                        [self.modalView.subviews[0] setFrame: CGRectOffset(viewFrame, 0, viewFrame.size.height)];
                        [self.modalView setBackgroundColor:[UIColor clearColor]];
                     }
                     completion:^(BOOL finished) {
                        [self.modalView removeFromSuperview];
                     }];
  
    // Retreive pickerView
    [self sendResultsFromPickerView:self.pickerView withButtonIndex:buttonIndex];
}

//
// Results
//

- (void)sendResultsFromPickerView:(UIPickerView *)pickerView withButtonIndex:(NSInteger)buttonIndex {

    NSMutableArray *assignedValues = [NSMutableArray array];
    NSDictionary *currentOptions = self.options;
    for (NSInteger i = 0; i < self.numberOfColumns; i++) {
        int rowIndex = [self.selectedRows[i] intValue];
        [assignedValues addObject:currentOptions[@"items"][rowIndex][@"value"]];
        currentOptions = currentOptions[@"items"][rowIndex][@"next"];
    }
    
    // Create Plugin Result
    CDVPluginResult* pluginResult;
    if (buttonIndex == 0) {
        // Create ERROR result if cancel was clicked
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }else {
        // Create OK result otherwise
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:assignedValues];
    }
    
    // Call appropriate javascript function
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];;
}

//
// Picker delegate
//

// Listen picker selected row
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    for (NSInteger j = component + 1; j < self.numberOfColumns; j++) {
        self.selectedRows[j] = @(0);
        [self.pickerView selectRow:0 inComponent:j animated:NO];
    }
    self.selectedRows[component] = @(row);
    [self.pickerView reloadAllComponents];
}

// Tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSDictionary* options = self.options;
    NSInteger count = 0;
    for (NSInteger i = 0; i < self.numberOfColumns && i <= component; i++) {
        if (!options) {
            break;
        }
        if (i == component) {
            count = [options[@"items"] count];
            break;
        }

        int selectedRow = [self.selectedRows[i] intValue];
        options = options[@"items"][selectedRow][@"next"];
    }
    return count;
}

// Tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
  return self.numberOfColumns;
}

// Tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSDictionary* options = self.options;
    NSString* title = @"";
    for (NSInteger i = 0; i < self.numberOfColumns && i <= component; i++) {
        if (!options) {
            break;
        }
        if (i == component) {
            title = options[@"items"][row][@"text"];
            break;
        }

        int selectedRow = [self.selectedRows[i] intValue];
        options = options[@"items"][selectedRow][@"next"];

    }
    return title;
}

// Tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
  return (pickerView.frame.size.width - 30) / self.numberOfColumns;
}

//
// Utilities
//

- (CGSize)viewSize
{
    if ( IS_IPAD )
    {
        return CGSizeMake(320, 320);
    }

    #if defined(__IPHONE_8_0)
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        //iOS 7.1 or earlier
        if ( [self isViewPortrait] )
            return CGSizeMake(320 , IS_WIDESCREEN ? 568 : 480);
        return CGSizeMake(IS_WIDESCREEN ? 568 : 480, 320);

    }else{
        //iOS 8 or later
        return [[UIScreen mainScreen] bounds].size;
    }
    #else
        if ( [self isViewPortrait] )
            return CGSizeMake(320 , IS_WIDESCREEN ? 568 : 480);
        return CGSizeMake(IS_WIDESCREEN ? 568 : 480, 320);
    #endif
}

- (BOOL) isViewPortrait {
    return UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
}

@end
