#include <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#define HTML_HEADER \
@"<html><head><style>%@</style></head><body bgcolor=white>"

#define HTML_FOOTER @"</body></html>"

#define CHATLOG_STYLE \
@"h1 {font-family: Helvetica, sans-serif;font-size: 13pt}" \
@".other { color:blue; }" \
@".me { color: green; }" \
@".time {font-size: 12pt;} "\
@"tr {font-family: Helvetica; vertical-align: top;}" \
@"td.who {text-align: right;}" \
@"td.what { }" 

#define HTMLLOG_STYLE \
@"h1 {font-family: Helvetica, sans-serif; font-size: 13pt;}" \
@"body {font-family: Helvetica; font-size: 10pt;}" \
@".receive { color:blue; }" \
@".send { color: green; }" \
@".timestamp { font-size:9pt; color: black;}" \
@".message { color: black; font-family: \"andale mono\"; font-size: 10pt;}" \
@"span ~ pre { margin-top: 0.1em; }"


/* -----------------------------------------------------------------------------
 Generate a preview for file
 
 This function's job is to create preview for designated file
 ----------------------------------------------------------------------------- */
NSString *formatDate(NSString *s)
{
	// Remove : of time zone
	NSMutableString *dateString = [s mutableCopy];
	if ([dateString characterAtIndex: [dateString length] - 3] == ':')
		[dateString deleteCharactersInRange: NSMakeRange([dateString length] - 3, 1)];
	
	// Create NSDate
	NSDateFormatter *ISO8601Formatter = [[NSDateFormatter alloc] init];
	[ISO8601Formatter setTimeStyle:NSDateFormatterFullStyle];
	[ISO8601Formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
	NSDate *date = [ISO8601Formatter dateFromString:dateString];
	
	// Extract the hours
	NSDateFormatter *hoursFormatter = [[NSDateFormatter alloc] init];
	[hoursFormatter setTimeStyle:NSDateFormatterShortStyle];
	[hoursFormatter	setDateFormat:@"HH:mm"];
	
	return [hoursFormatter stringFromDate:date];
}


OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options)
{
	NSAutoreleasePool *  pool = [[NSAutoreleasePool alloc] init];

	NSError *error = nil;
	NSMutableString *html = [NSMutableString string];
	NSString *path = [(NSURL *)url path];

	if ([[path pathExtension] isEqualToString:@"chatlog"]) {
		BOOL isDir;
		if (! [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
			goto bailout;
	  
		if (isDir) {
			// is bundle
			path = [path stringByAppendingPathComponent:[path lastPathComponent]];
			path = [[path stringByDeletingPathExtension] stringByAppendingPathExtension:@"xml"];
			if (! [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || isDir )
				goto bailout;
		}
	  
		NSXMLDocument *document = [[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] options:0 error:&error] autorelease];
	  
		if (!document && error) {
			NSLog(@"Error reading the XML, %@", error);
			goto bailout;
		}
	  
		// Get the account name and protocol from the root node
		NSXMLElement *chatNode = [[document nodesForXPath:@"//chat" error:&error] objectAtIndex:0];
		NSString *account = [[chatNode attributeForName:@"account"] stringValue];
		NSString *service = [[chatNode attributeForName:@"service"] stringValue];

		// Top level node should be chat, look at children, but only get those
		// that are messages (not events nor status)
		NSArray *messageNodes = [document nodesForXPath:@"//message" error:nil];

		[html appendFormat: HTML_HEADER, CHATLOG_STYLE];
		[html appendFormat:@"<h1>Adium %@ chat log</h1>\n", service];
	  
		if ([messageNodes count] > 0) {
			[html appendString:@"<table border=\"0\" cellpadding=\"2\">"];

			int maxMessages = 50 + 1;
			for (NSXMLElement *message in messageNodes) {
				if (! --maxMessages)
					break;
				
				NSString *alias = [[message attributeForName:@"alias"] stringValue];
				NSString *sender = [[message attributeForName:@"sender"] stringValue];
				NSString *spanstyle = [sender caseInsensitiveCompare:account] == NSOrderedSame ? @"me" : @"other";

				NSString *date = [[message attributeForName:@"time"] stringValue];
				NSString *time = formatDate(date);
								
				// Use alias if it is shorter
				if (alias && [alias length] < [sender length])
					sender = alias;
              
				// Extract the message tag, we could get rid of the span tag too.
				NSString *content = [[message elementsForName:@"div"] objectAtIndex:0];

				[html appendFormat: 
					@"<tr><td class=\"time\">%@</td><td class=\"who\"><span class=\"%@\">%@</span>:</td><td class=\"what\">%@</td></tr>\n", 
					time, spanstyle, sender, content];
			}
			[html appendString:@"</table>"];
		}
	} else if ([[path pathExtension] isEqualToString:@"AdiumHTMLLog"]) {
		[html appendFormat: HTML_HEADER, HTMLLOG_STYLE];
		[html appendFormat:@"<h1>Adium chat log</h1>\n"];

		[html appendString:[NSString stringWithContentsOfURL: (NSURL*)url encoding: NSUTF8StringEncoding error:nil]];
	} else {
		goto bailout;
	}

	[html appendString:HTML_FOOTER];	

	NSLog(@"%@", html);
	
	NSDictionary *props = [NSDictionary dictionaryWithObjectsAndKeys:
		@"UTF-8", (NSString *)kQLPreviewPropertyTextEncodingNameKey,
		@"text/html", (NSString *)kQLPreviewPropertyMIMETypeKey,
		nil];
	
	QLPreviewRequestSetDataRepresentation(preview, (CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding], kUTTypeHTML, (CFDictionaryRef)props);
	
bailout:		
	[pool release];
	return noErr;            // Apple's documentation states this is the only return code to be used
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
  // implement only if supported
}
