#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <UserNotificationsUI/UserNotificationsUI.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>

#define IS_BUNDLE_EQUAL_TO(bundleId) CFEqual(CFBundleGetIdentifier(CFBundleGetMainBundle()), CFSTR(bundleId))
// #define LOG(str, ...) NSLog(@"[MusicRecognitionMoreApps] " str, ##__VA_ARGS__)


@interface SHNotificationViewController : UIViewController
- (void)didReceiveNotification:(UNNotification *)notification;
- (void)didReceiveNotificationResponse:(UNNotificationResponse *)response completionHandler:(void (^)(UNNotificationContentExtensionResponseOption option))completion;
@end

@interface EXExtensionContextImplementation : NSObject
- (NSArray *)notificationActions;
- (void)setNotificationActions:(NSArray *)actions;
@end

@interface SHLocalization : NSObject
+ (NSString *)localizedStringForKey:(NSString *)key;
@end


typedef NS_ENUM(short, MRMAEncoding) {
	MRMAEncodingQuery,
	MRMAEncodingPath
};

NSString *titleFormat;
NSDictionary *supportedApps;
NSMutableDictionary *availableApplications;


%hook SHNotificationViewController

- (void)didReceiveNotification:(UNNotification *)notification {
	%orig;

	[availableApplications removeAllObjects];

	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];

	for (NSString *appId in supportedApps) {
		NSDictionary *app = supportedApps[appId];
		NSArray *available = [workspace applicationsAvailableForHandlingURLScheme:app[@"scheme"]];
		if (available.count != 0) {
			availableApplications[appId] = app;
		}
	}

	EXExtensionContextImplementation *context = (EXExtensionContextImplementation *)self.extensionContext;
	NSMutableArray *actions = [context.notificationActions mutableCopy];

	NSString *identifierFormat = @"com.apple.ShazamNotifications.%@-action";

	for (NSString *appId in availableApplications) {
		NSString *title = [NSString stringWithFormat:titleFormat, availableApplications[appId][@"name"]];
		NSString *identifier = [NSString stringWithFormat:identifierFormat, appId];
		[actions addObject:[UNNotificationAction actionWithIdentifier:identifier title:title options:0]];
	}

	[context setNotificationActions:actions];
}

- (void)didReceiveNotificationResponse:(UNNotificationResponse *)response completionHandler:(void (^)(UNNotificationContentExtensionResponseOption option))completion {
	NSString *actionIdentifier = response.actionIdentifier;

	BOOL ourAction = NO;
	NSString *identifierFormat = @"com.apple.ShazamNotifications.%@-action";

	for (NSString *appId in availableApplications) {
		NSString *identifier = [NSString stringWithFormat:identifierFormat, appId];

		if ([identifier isEqualToString:actionIdentifier]) {
			NSDictionary *app = availableApplications[appId];

			// body -> artist, title -> track
			UNNotificationContent *content = response.notification.request.content;
			NSString *query = [NSString stringWithFormat:@"%@ - %@", content.body, content.title];


			MRMAEncoding encoding = [app[@"encoding"] shortValue];
			if (encoding == MRMAEncodingQuery) {
				query = [query stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
			} else {
				query = [query stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
			}

			NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:app[@"url"], query]];
			[self.extensionContext openURL:url completionHandler:nil];

			ourAction = YES;
			break;
		}
	}

	if (ourAction) {
		completion(UNNotificationContentExtensionResponseOptionDismiss);
	}
	else {
		%orig;
	}
}

%end


%ctor {
	if (IS_BUNDLE_EQUAL_TO("com.apple.ShazamKit.ShazamNotificationContentExtension")) {
		supportedApps = @{
			@"youtube": @{
				@"name": @"YouTube",
				@"scheme": @"youtube",
				@"url": @"youtube://www.youtube.com/results?search_query=%@",
				@"encoding": @(MRMAEncodingQuery)
			},
			@"youtube-music": @{
				@"name": @"YouTube Music",
				@"scheme": @"youtubemusic",
				@"url": @"youtubemusic://music.youtube.com/search?q=%@",
				@"encoding": @(MRMAEncodingQuery)
			},
			@"spotify": @{
				@"name": @"Spotify",
				@"scheme": @"spotify",
				@"url": @"spotify:search:%@",
				@"encoding": @(MRMAEncodingPath)
			},
			@"deezer": @{
				@"name": @"Deezer",
				@"scheme": @"deezer",
				@"url": @"deezer://www.deezer.com/search/%@",
				@"encoding": @(MRMAEncodingPath)
			}
		};

		availableApplications = [NSMutableDictionary dictionary];

		// try to localise the actions fall back to english
		NSString *appleMusicTitle = [objc_getClass("SHLocalization") localizedStringForKey:@"SHAZAM_MODULE_NOTIFICATION_ACTION_TITLE"];
		if (appleMusicTitle) {
			titleFormat = [appleMusicTitle stringByReplacingOccurrencesOfString:@"Apple Music" withString:@"%@"];
		}

		if (!appleMusicTitle || ![titleFormat containsString:@"%@"]) {
			titleFormat = @"Listen dsadon %@";
		}

		%init;
	}
}
