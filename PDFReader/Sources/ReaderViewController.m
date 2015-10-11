//
//	ReaderViewController.m
//	Reader v2.6.0
//
//	Created by Julius Oklamcak on 2011-07-01.
//	Copyright © 2011-2013 Julius Oklamcak. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderConstants.h"
#import "ReaderViewController.h"
#import "ThumbsViewController.h"
#import "ReaderMainToolbar.h"
#import "ReaderMainPagebar.h"
#import "ReaderContentView.h"
#import "ReaderContentViewController.h"
#import "ReaderThumbCache.h"
#import "ReaderThumbQueue.h"
#import "ReaderContentPage.h"
#import "MusicPlayerControlleriPad.h"
#import <AirTurnInterface/AirTurnManager.h>
#import "AirTurnHelper.h"
#import "CurrentQueue.h"
#import <MessageUI/MessageUI.h>


@interface ReaderViewController () <UIGestureRecognizerDelegate, MFMailComposeViewControllerDelegate,
									ReaderMainToolbarDelegate, ReaderMainPagebarDelegate, ReaderContentViewDelegate, ThumbsViewControllerDelegate>
@end

@implementation ReaderViewController
{
	ReaderDocument *document;

    UIPageViewController *thePageViewController;

	ReaderMainToolbar *mainToolbar;

	ReaderMainPagebar *mainPagebar;
    UIBarButtonItem *actionButton;

	UIPrintInteractionController *printInteraction;

	CGSize lastAppearSize;

	NSDate *lastHideTime;

	BOOL isVisible;
}

#pragma mark Constants

//#define PAGING_VIEWS 3

#define TOOLBAR_HEIGHT 44.0f
#define PAGEBAR_HEIGHT 48.0f

#define TAP_AREA_SIZE 48.0f

#pragma mark Properties

@synthesize delegate;

#pragma mark Support methods

- (void)updateToolbarBookmarkIcon
{
	NSInteger page = [document.pageNumber integerValue];

	BOOL bookmarked = [document.bookmarks containsIndex:page];

	[mainToolbar setBookmarkState:bookmarked]; // Update
}

- (void)showDocumentForPage:(NSInteger)page
{
	assert(page <= [document.pageCount integerValue]);

    UIPageViewControllerNavigationDirection direction= page > [document.pageNumber integerValue]?
                                                        UIPageViewControllerNavigationDirectionForward:
                                                        UIPageViewControllerNavigationDirectionReverse;
	
    ReaderContentViewController *currentViewController = [self viewControllerForPage:page];
    _pageIsAnimating = NO;
    NSArray *viewControllers =
    [NSArray arrayWithObject:currentViewController];
    
    [thePageViewController setViewControllers:viewControllers
                          direction:direction
                           animated:NO
                         completion:nil];
    
    if ([document.pageNumber integerValue] != page) // Only if different
    {
        document.pageNumber = [NSNumber numberWithInteger:page]; // Update page number
    }
    
    [mainPagebar updatePagebar]; // Update the pagebar display
    
    [self updateToolbarBookmarkIcon]; // Update bookmark
    
}

- (void)showDocument:(id)object
{
	[self showDocumentForPage:[document.pageNumber integerValue]];

	document.lastOpen = [NSDate date]; // Update last opened date

	isVisible = YES; // iOS present modal bodge
}

#pragma mark UIViewController methods

- (id)initWithReaderDocument:(ReaderDocument *)object
{
	id reader = nil; // ReaderViewController object

	if ((object != nil) && ([object isKindOfClass:[ReaderDocument class]]))
	{
		if ((self = [super initWithNibName:nil bundle:nil])) // Designated initializer
		{
			NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

			[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillTerminateNotification object:nil];

			[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillResignActiveNotification object:nil];

			[object updateProperties]; document = object; // Retain the supplied ReaderDocument object for our use

			[ReaderThumbCache touchThumbCacheWithGUID:object.guid]; // Touch the document thumb cache directory

			reader = self; // Return an initialized ReaderViewController object
		}
	}
	return reader;
}

- (id)initWithReaderDocument:(ReaderDocument *)object withActionButton: (UIBarButtonItem *)button
{
	id reader = nil; // ReaderViewController object
    
	if ((object != nil) && ([object isKindOfClass:[ReaderDocument class]]))
	{
		if ((self = [super initWithNibName:nil bundle:nil])) // Designated initializer
		{
			NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            
			[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillTerminateNotification object:nil];
            
			[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillResignActiveNotification object:nil];
            
			[object updateProperties]; document = object; // Retain the supplied ReaderDocument object for our use
            
			[ReaderThumbCache touchThumbCacheWithGUID:object.guid]; // Touch the document thumb cache directory
            
            actionButton = button;
            
			reader = self; // Return an initialized ReaderViewController object
		}
	}
	return reader;
}

- (BOOL)prefersStatusBarHidden {
    return !self.showStatusBar;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	assert(document != nil); // Must have a valid ReaderDocument

	self.view.backgroundColor = [UIColor colorWithRed:0.8f green:0.8f blue:0.8f alpha:1.0f];

	CGRect viewRect = self.view.bounds; // View controller's view bounds

 
	CGRect toolbarRect = viewRect;
	toolbarRect.size.height = TOOLBAR_HEIGHT;

	mainToolbar = [[ReaderMainToolbar alloc] initWithFrame:toolbarRect document:document withActionButton:actionButton]; // At top
    [mainToolbar sizeToFit];
    [mainToolbar setFrame:toolbarRect];

	mainToolbar.delegate = self;

	[self.view addSubview:mainToolbar];


	UITapGestureRecognizer *singleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	singleTapOne.numberOfTouchesRequired = 1; singleTapOne.numberOfTapsRequired = 1; singleTapOne.delegate = self;
	[self.view addGestureRecognizer:singleTapOne];

	UITapGestureRecognizer *doubleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapOne.numberOfTouchesRequired = 1; doubleTapOne.numberOfTapsRequired = 2; doubleTapOne.delegate = self;
	[self.view addGestureRecognizer:doubleTapOne];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

	UITapGestureRecognizer *doubleTapTwo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapTwo.numberOfTouchesRequired = 2; doubleTapTwo.numberOfTapsRequired = 2; doubleTapTwo.delegate = self;
	[self.view addGestureRecognizer:doubleTapTwo];

	[singleTapOne requireGestureRecognizerToFail:doubleTapOne]; // Single tap requires double tap to fail

    // create pageViewController
    NSDictionary *options =
    [NSDictionary dictionaryWithObject:
    [NSNumber numberWithInteger:UIPageViewControllerSpineLocationMin]
                                forKey: UIPageViewControllerOptionSpineLocationKey];
    self->thePageViewController = [[UIPageViewController alloc]
                         initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl
                         navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                         options: options];
    
    thePageViewController.dataSource = self;
    thePageViewController.delegate = self;
    
	[AirTurnViewManager sharedViewManager].enabled = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(airTurnEvent:) name:AirTurnPedalPressNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleAirTurnEvent:)
												 name:kHandleAirTurnEvent object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(mediaPlayerDidHide)
												 name:kMediaPlayerDidHide object:nil];

	[[self view] addSubview:[thePageViewController view]];
    [thePageViewController didMoveToParentViewController:self];
    
    CGRect pagebarRect = viewRect;
	pagebarRect.size.height = PAGEBAR_HEIGHT;
	pagebarRect.origin.y = (viewRect.size.height - PAGEBAR_HEIGHT);
    
	mainPagebar = [[ReaderMainPagebar alloc] initWithFrame:pagebarRect document:document]; // At bottom
    
	mainPagebar.delegate = self;
    
	self.mediaPlayer = [[MusicPlayerControlleriPad alloc] initWithNibName: @"MediaPlayerView" bundle: nil];
    [self addChildViewController:self.mediaPlayer]; // "will" is called for us
    self.mediaPlayer.view.frame = CGRectMake(214, 262, 320, 400);
    [self.view addSubview:self.mediaPlayer.view];
    // when we call "add", we must call "did" afterwards
    [self.mediaPlayer didMoveToParentViewController:self];

	[self.view addSubview:mainPagebar];

	lastHideTime = [NSDate date];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	mainPagebar.hidden = YES;
	mainToolbar.hidden = YES;
    if (document != nil) {
        [self showDocumentForPage:[document.pageNumber integerValue]];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	if (CGSizeEqualToSize(thePageViewController.view.frame.size, CGSizeZero)) // First time
	{
		[self performSelector:@selector(showDocument:) withObject:nil afterDelay:0.02];
	}

#if (READER_DISABLE_IDLE == TRUE) // Option

	[UIApplication sharedApplication].idleTimerDisabled = YES;

#endif // end of READER_DISABLE_IDLE Option
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	lastAppearSize = self.view.bounds.size; // Track view size

#if (READER_DISABLE_IDLE == TRUE) // Option

	[UIApplication sharedApplication].idleTimerDisabled = NO;

#endif // end of READER_DISABLE_IDLE Option
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (void)viewDidUnload
{
#ifdef DEBUG
	NSLog(@"%s", __FUNCTION__);
#endif

	mainToolbar = nil; mainPagebar = nil;

	thePageViewController = nil; lastHideTime = nil;

	lastAppearSize = CGSizeZero;

	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (isVisible == NO) return; // iOS present modal bodge

	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		if (printInteraction != nil) [printInteraction dismissAnimated:NO];
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	if (isVisible == NO) return; // iOS present modal bodge

	lastAppearSize = CGSizeZero; // Reset view size tracking
}

/*
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	//if (isVisible == NO) return; // iOS present modal bodge

	//if (fromInterfaceOrientation == self.interfaceOrientation) return;
}
*/

- (void)didReceiveMemoryWarning
{
#ifdef DEBUG
	NSLog(@"%s", __FUNCTION__);
#endif

	[super didReceiveMemoryWarning];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
	if ([touch.view isKindOfClass:[UIScrollView class]]) return YES;

	return NO;
}

#pragma mark UIGestureRecognizer action methods

- (void)decrementPageNumber
{
	if (thePageViewController.view.tag == 0) // Scroll view did end
	{
		NSInteger page = [document.pageNumber integerValue];
		NSInteger minPage = 0; // Minimum

		if (page > minPage)
		{
            thePageViewController.view.tag = (page - 1); // Increment page number
            document.pageNumber = [NSNumber numberWithLong:page-1];
            [self updateMarkButtonOnToolbar:mainToolbar];
		}
	}
}

- (void)incrementPageNumber
{
	if (thePageViewController.view.tag == 0) // Scroll view did end
	{
		NSInteger page = [document.pageNumber integerValue];
		NSInteger maxPage = [document.pageCount integerValue];

		if (page < maxPage)
		{
			thePageViewController.view.tag = (page + 1); // Increment page number
            document.pageNumber = [NSNumber numberWithLong:page+1];
            [self updateMarkButtonOnToolbar:mainToolbar];
		}
	}
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateRecognized)
	{
		CGRect viewRect = recognizer.view.bounds; // View bounds

		CGPoint point = [recognizer locationInView:recognizer.view];

		CGRect areaRect = CGRectInset(viewRect, TAP_AREA_SIZE, 0.0f); // Area

		if (CGRectContainsPoint(areaRect, point)) // Single tap is inside the area
		{
			//NSInteger page = [document.pageNumber integerValue]; // Current page #

			ReaderContentView *rcv = _currentContentView;
            ReaderContentPage *targetView = [rcv getContentView];

			id target = [targetView processSingleTap:recognizer]; // Target

			if (target != nil) // Handle the returned target object
			{
				if ([target isKindOfClass:[NSURL class]]) // Open a URL
				{
					NSURL *url = (NSURL *)target; // Cast to a NSURL object

					if (url.scheme == nil) // Handle a missing URL scheme
					{
						NSString *www = url.absoluteString; // Get URL string

						if ([www hasPrefix:@"www"] == YES) // Check for 'www' prefix
						{
							NSString *http = [NSString stringWithFormat:@"http://%@", www];

							url = [NSURL URLWithString:http]; // Proper http-based URL
						}
					}

					if ([[UIApplication sharedApplication] openURL:url] == NO)
					{
						#ifdef DEBUG
							NSLog(@"%s '%@'", __FUNCTION__, url); // Bad or unknown URL
						#endif
					}
				}
				else // Not a URL, so check for other possible object type
				{
					if ([target isKindOfClass:[NSNumber class]]) // Goto page
					{
						NSInteger value = [target integerValue]; // Number

						[self showDocumentForPage:value]; // Show the page
					}
				}
			}
			else // Nothing active tapped in the target content view
			{
				if ([lastHideTime timeIntervalSinceNow] < -0.75) // Delay since hide
				{
					if ((mainToolbar.hidden == YES) || (mainPagebar.hidden == YES))
					{
						if (self.mediaPlayer.isPlaying)
						{
							[mainToolbar showToolbar];
							[mainPagebar showPagebar]; // Show
							[self.mediaPlayer showPlayer];
						}
						else if (self.mediaPlayer.playerIsShowing)
							[self.mediaPlayer hidePlayer];
						else
						{
							[mainToolbar showToolbar];
							[mainPagebar showPagebar]; // Show
						}

                        self.showStatusBar = NO;
                        [self setNeedsStatusBarAppearanceUpdate];
					}
				}
			}

			return;
		}

		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);

		if (CGRectContainsPoint(nextPageRect, point)) // page++ area
		{
			[self incrementPageNumber]; return;
		}

		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;

		if (CGRectContainsPoint(prevPageRect, point)) // page-- area
		{
			[self decrementPageNumber]; return;
		}
	}
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateRecognized)
	{
		CGRect viewRect = recognizer.view.bounds; // View bounds

		CGPoint point = [recognizer locationInView:recognizer.view];

		CGRect zoomArea = CGRectInset(viewRect, TAP_AREA_SIZE, TAP_AREA_SIZE);

		if (CGRectContainsPoint(zoomArea, point)) // Double tap is in the zoom area
		{
			NSInteger page = [document.pageNumber integerValue]; // Current page #

			ReaderContentView *targetView = (ReaderContentView *) [self viewControllerForPage:page].view;
            _pageIsAnimating = NO;

			switch (recognizer.numberOfTouchesRequired) // Touches count
			{
				case 1: // One finger double tap: zoom ++
				{
					[targetView zoomIncrement]; break;
				}

				case 2: // Two finger double tap: zoom --
				{
					[targetView zoomDecrement]; break;
				}
			}

			return;
		}

		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);

		if (CGRectContainsPoint(nextPageRect, point)) // page++ area
		{
			[self incrementPageNumber]; return;
		}

		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;

		if (CGRectContainsPoint(prevPageRect, point)) // page-- area
		{
			[self decrementPageNumber]; return;
		}
	}
}

#pragma mark ReaderContentViewDelegate methods

- (void)contentView:(ReaderContentView *)contentView touchesBegan:(NSSet *)touches
{
	if ((mainToolbar.hidden == NO) || (mainPagebar.hidden == NO))
	{
		if (touches.count == 1) // Single touches only
		{
			UITouch *touch = [touches anyObject]; // Touch info

			CGPoint point = [touch locationInView:self.view]; // Touch location

			CGRect areaRect = CGRectInset(self.view.bounds, TAP_AREA_SIZE, TAP_AREA_SIZE);

			if (CGRectContainsPoint(areaRect, point) == false) return;
		}

		[self hideAll];
        self.showStatusBar = YES;
        [self setNeedsStatusBarAppearanceUpdate];

		lastHideTime = [NSDate date];
	}
}

#pragma mark ReaderMainToolbarDelegate methods

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar doneButton:(UIButton *)button
{
#if (READER_STANDALONE == FALSE) // Option

	[self.mediaPlayer stopPlayer];
	[document archiveDocumentProperties]; // Save any ReaderDocument object changes

	[[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:document.guid];

	[[ReaderThumbCache sharedInstance] removeAllObjects]; // Empty the thumb cache

	if (printInteraction != nil) [printInteraction dismissAnimated:NO]; // Dismiss

	if ([delegate respondsToSelector:@selector(dismissReaderViewController:)] == YES)
	{
		[delegate dismissReaderViewController:self]; // Dismiss the ReaderViewController
	}
	else // We have a "Delegate must respond to -dismissReaderViewController: error"
	{
		NSAssert(NO, @"Delegate must respond to -dismissReaderViewController:");
	}

#endif // end of READER_STANDALONE Option
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar thumbsButton:(UIBarButtonItem *)button
{
	if (printInteraction != nil) [printInteraction dismissAnimated:NO]; // Dismiss

	ThumbsViewController *thumbsViewController = [[ThumbsViewController alloc] initWithReaderDocument:document];

	thumbsViewController.delegate = self; thumbsViewController.title = self.title;

	thumbsViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	thumbsViewController.modalPresentationStyle = UIModalPresentationFullScreen;

	[self presentViewController:thumbsViewController animated:NO completion:NULL];
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar printButton:(UIBarButtonItem *)button
{
#if (READER_ENABLE_PRINT == TRUE) // Option

	Class printInteractionController = NSClassFromString(@"UIPrintInteractionController");

	if ((printInteractionController != nil) && [printInteractionController isPrintingAvailable])
	{
		NSURL *fileURL = document.fileURL; // Document file URL

		printInteraction = [printInteractionController sharedPrintController];

		if ([printInteractionController canPrintURL:fileURL] == YES) // Check first
		{
			UIPrintInfo *printInfo = [NSClassFromString(@"UIPrintInfo") printInfo];

			printInfo.duplex = UIPrintInfoDuplexLongEdge;
			printInfo.outputType = UIPrintInfoOutputGeneral;
			printInfo.jobName = document.fileName;

			printInteraction.printInfo = printInfo;
			printInteraction.printingItem = fileURL;
			printInteraction.showsPageRange = YES;

			if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
			{
				[printInteraction presentFromBarButtonItem:button animated:YES completionHandler:
					^(UIPrintInteractionController *pic, BOOL completed, NSError *error)
					{
						#ifdef DEBUG
							if ((completed == NO) && (error != nil)) NSLog(@"%s %@", __FUNCTION__, error);
						#endif
					}
				];
			}
			else // Presume UIUserInterfaceIdiomPhone
			{
				[printInteraction presentAnimated:YES completionHandler:
					^(UIPrintInteractionController *pic, BOOL completed, NSError *error)
					{
						#ifdef DEBUG
							if ((completed == NO) && (error != nil)) NSLog(@"%s %@", __FUNCTION__, error);
						#endif
					}
				];
			}
		}
	}

#endif // end of READER_ENABLE_PRINT Option
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar emailButton:(UIButton *)button
{
#if (READER_ENABLE_MAIL == TRUE) // Option

	if ([MFMailComposeViewController canSendMail] == NO) return;

	if (printInteraction != nil) [printInteraction dismissAnimated:YES];

	unsigned long long fileSize = [document.fileSize unsignedLongLongValue];

	if (fileSize < (unsigned long long)15728640) // Check attachment size limit (15MB)
	{
		NSURL *fileURL = document.fileURL; NSString *fileName = document.fileName; // Document

		NSData *attachment = [NSData dataWithContentsOfURL:fileURL options:(NSDataReadingMapped|NSDataReadingUncached) error:nil];

		if (attachment != nil) // Ensure that we have valid document file attachment data
		{
			MFMailComposeViewController *mailComposer = [MFMailComposeViewController new];

			[mailComposer addAttachmentData:attachment mimeType:@"application/pdf" fileName:fileName];

			[mailComposer setSubject:fileName]; // Use the document file name for the subject

			mailComposer.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
			mailComposer.modalPresentationStyle = UIModalPresentationFormSheet;

			mailComposer.mailComposeDelegate = self; // Set the delegate

			[self presentViewController:mailComposer animated:YES completion:NULL];
		}
	}

#endif // end of READER_ENABLE_MAIL Option
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar markButton:(UIButton *)button
{
	if (printInteraction != nil) [printInteraction dismissAnimated:YES];

	NSInteger page = [document.pageNumber integerValue];

	if ([document.bookmarks containsIndex:page]) // Remove bookmark
	{
		[mainToolbar setBookmarkState:NO]; [document.bookmarks removeIndex:page];
	}
	else // Add the bookmarked page index to the bookmarks set
	{
		[mainToolbar setBookmarkState:YES]; [document.bookmarks addIndex:page];
	}
}

- (void)updateMarkButtonOnToolbar:(ReaderMainToolbar *)toolbar 
{
	if (printInteraction != nil) [printInteraction dismissAnimated:YES];
    
	NSInteger page = [document.pageNumber integerValue];
    
	if ([document.bookmarks containsIndex:page]) // Remove bookmark
	{
		[mainToolbar setBookmarkState:YES];
	}
	else // Add the bookmarked page index to the bookmarks set
	{
		[mainToolbar setBookmarkState:NO]; 
	}
}

- (void)tappedInToolbar:(UIBarButtonItem *)button
{
	if ([self.popover isPopoverVisible])
		[self.popover dismissPopoverAnimated:YES];
	else
	{
		if (!self.popover)
		{
			MusicListControlleriPad *musicController = [[MusicListControlleriPad alloc] initWithNibName:@"MusicTableView" bundle:nil];
			musicController.delegate = self;
			UINavigationController *modalController = [[UINavigationController alloc] initWithRootViewController:musicController];
			self.popover = [[UIPopoverController alloc] initWithContentViewController:modalController];
		}
		[self.popover presentPopoverFromBarButtonItem:button permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	}
}

- (void) willEnterForeground:(NSNotification *) n
{
	//[self showDocumentForPage:[document.pageNumber integerValue]];
    [[_currentContentView getContentView] setNeedsDisplay];

}

#pragma mark - Airturn

- (void)airTurnEvent:(NSNotification *)notification
{
	[[AirTurnHelper sharedHelper] handleAirTurnNotification:notification];
}

- (void)handleAirTurnEvent:(NSNotification *)notification
{
	NSDictionary *airTurnEvents = [notification object];
	NSInteger airEvent = [[airTurnEvents objectForKey:@"event"] integerValue];

	if (self.mediaPlayer.playerIsShowing)
		[self.mediaPlayer handleAirTurnEvent:airEvent];
	else
	{
		switch (airEvent)
		{
			case AirTurnPort1:
				if ([document.pageCount integerValue] == 1)
					return;
				if ([document.pageNumber integerValue] > 1)
					[self showDocumentForPage:[document.pageNumber integerValue]-1];
				else
					[self showDocumentForPage:[document.pageCount integerValue]];
				break;
				
			case AirTurnPort3:
				if ([document.pageCount integerValue] == 1)
					return;
				if ([document.pageNumber integerValue] < [document.pageCount integerValue])
					[self showDocumentForPage:[document.pageNumber integerValue]+1];
				else
					[self showDocumentForPage:1];
				break;
				
			case AirTurnShowPlayer:
				[self showPlayer];
				break;
		}
	}
	
}

#pragma mark MusicTableViewControllerDelegate methods

- (void) playSong:(CurrentQueue *)songQueue index:(NSInteger)index
{
	[self.mediaPlayer playSong:songQueue index:index];
	[self.popover dismissPopoverAnimated:YES];
	[NSTimer scheduledTimerWithTimeInterval:2.0
									 target:self
								   selector:@selector(hideAll)
								   userInfo:nil
									repeats:NO];
}

- (void) showPlayer
{
	if (self.mediaPlayer.isPlaying)
		[self.mediaPlayer showPlayer];
	else
		{
			CurrentQueue* songQueue = [[CurrentQueue alloc] initWithName:[self documentName]];
			if (songQueue.count > 0)
				[self.mediaPlayer presentPlayer:songQueue];
			else
			{
				[[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can not show the music player because there are is no music in the Songbook playlist. Tap on the screen and select Player in the navigation bar at the top to add music."
										   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]
				 show];
			}
		}
}

- (void)mediaPlayerDidHide
{
 	[self hideReader];
    [[_currentContentView getContentView] setNeedsDisplay];
}

- (NSString *) documentName
{
	return document.fileName;
}

- (void) hideAll
{
	[self hideReader];
	[self.mediaPlayer hidePlayer];
}

- (void) hideReader
{
	[mainToolbar hideToolbar];
	[mainPagebar hidePagebar]; // Hide

	lastHideTime = [NSDate new];
}

#pragma mark MFMailComposeViewControllerDelegate methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	#ifdef DEBUG
		if ((result == MFMailComposeResultFailed) && (error != NULL)) NSLog(@"%@", error);
	#endif

	[self dismissViewControllerAnimated:YES completion:nil]; // Dismiss
}

#pragma mark ThumbsViewControllerDelegate methods

- (void)dismissThumbsViewController:(ThumbsViewController *)viewController
{
	[self updateToolbarBookmarkIcon]; // Update bookmark icon

	[self dismissViewControllerAnimated:NO completion:nil]; // Dismiss
}

- (void)thumbsViewController:(ThumbsViewController *)viewController gotoPage:(NSInteger)page
{
	[self showDocumentForPage:page]; // Show the page
	[NSTimer scheduledTimerWithTimeInterval:2.0
									 target:self
								   selector:@selector(hideAll)
								   userInfo:nil
									repeats:NO];
}

#pragma mark ReaderMainPagebarDelegate methods

- (void)pagebar:(ReaderMainPagebar *)pagebar gotoPage:(NSInteger)page
{
	[self showDocumentForPage:page]; // Show the page
	
	[NSTimer scheduledTimerWithTimeInterval:2.0
									 target:self
								   selector:@selector(hideAll)
								   userInfo:nil
									repeats:NO];
}

#pragma mark UIApplication notification methods

- (void)applicationWill:(NSNotification *)notification
{
	[document archiveDocumentProperties]; // Save any ReaderDocument object changes

	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		if (printInteraction != nil) [printInteraction dismissAnimated:NO];
	}
}

#pragma mark data source for UIPageViewController

- (ReaderContentViewController *)viewControllerForPage:(NSUInteger)page
{
    // Return the data view controller for the given index.
    if (([document.pageCount intValue] == 0) ||
        (page > [document.pageCount intValue])) {
        return nil;
    }
    
    // Create a new view controller and pass suitable data.
    ReaderContentViewController *dataViewController = [[ReaderContentViewController alloc] initWithNibName:nil bundle:nil];
    
    NSURL *fileURL = document.fileURL; NSString *phrase = document.password;
    CGRect viewRect = CGRectZero; viewRect.size = thePageViewController.view.bounds.size;

    ReaderContentView *contentView = [[ReaderContentView alloc] initWithFrame:viewRect fileURL:fileURL page:page password:phrase];
    
    contentView.message = self;
    
    dataViewController.view = contentView;
    _currentContentView = contentView;
    return dataViewController;
}

- (NSUInteger)pageOfViewController:(ReaderContentViewController *)viewController
{
    ReaderContentView *rv = (ReaderContentView *) viewController.view;
    return (rv.pageNbr);
}

- (UIViewController *)pageViewController:
(UIPageViewController *)pageViewController viewControllerBeforeViewController:
(UIViewController *)viewController
{
    if (_pageIsAnimating)
        return nil;
    NSUInteger page = [self pageOfViewController:
                        (ReaderContentViewController *)viewController];
    if ((page == 1) || (page == NSNotFound))
        return nil;
    
    page--;
    return [self viewControllerForPage:page];
}

- (UIViewController *)pageViewController:
(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    if (_pageIsAnimating)
        return nil;
    
    NSUInteger page = [self pageOfViewController:
                        (ReaderContentViewController *)viewController];
    if (page == NSNotFound)
        return nil;
    
    page++;
    if (page > [document.pageCount intValue])
        return nil;

    return [self viewControllerForPage:page];
}

#pragma mark delegate for UIPageViewController

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray *)pendingViewControllers
{
    _pageIsAnimating = YES;
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
	_pageIsAnimating = NO;

    if(completed)
	{
        _currentContentView = (ReaderContentView *)[(UIViewController *)[pageViewController.viewControllers lastObject] view];
		document.pageNumber = [NSNumber numberWithLong: _currentContentView.pageNbr];
		[mainPagebar updatePagebar];
		[self updateMarkButtonOnToolbar:mainToolbar];
   }
}

@end
