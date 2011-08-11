#include <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#define HTML_HEADER \
@"<html><head><style>%@</style></head><body bgcolor=white>"

#define HTML_FOOTER @"</body></html>"

#define CHATLOG_STYLE \
@"h1 {font-family: Helvetica, sans-serif;font-size: 10pt}" \
@".other { color:blue; }" \
@".me { color: green; }" \
@"td.time {font-size: 10pt; color: grey;} "\
@"tr {font-family: Helvetica; vertical-align: top;}" \
@"td.who {font-size: 10pt; text-align: right; width: 15%;}" \
@"td.status {font-size: 10pt; color: grey;}" \
@"td.what {font-size: 10pt;}" 

#define HTMLLOG_STYLE \
@"h1 {font-family: Helvetica, sans-serif; font-size: 10pt;}" \
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
	NSMutableString *dateString = [[s mutableCopy] autorelease];
	if ([dateString characterAtIndex: [dateString length] - 3] == ':')
		[dateString deleteCharactersInRange: NSMakeRange([dateString length] - 3, 1)];
	
	// Create NSDate
	NSDateFormatter *ISO8601Formatter = [[[NSDateFormatter alloc] init] autorelease];
	[ISO8601Formatter setTimeStyle:NSDateFormatterFullStyle];
	[ISO8601Formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZ"];
	NSDate *date = [ISO8601Formatter dateFromString:dateString];
	
	// Extract the hours
	NSDateFormatter *hoursFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[hoursFormatter setTimeStyle:NSDateFormatterShortStyle];
	[hoursFormatter	setDateFormat:@"HH:mm:ss"];
	
	return [hoursFormatter stringFromDate:date];
}

void removeStyleRecursive(NSXMLElement* el) {
    if(el.kind == NSXMLElementKind) {
        [el removeAttributeForName:@"class"];
        [el removeAttributeForName:@"style"];
    }
    
    for(NSXMLElement* child in [el children]) {
        removeStyleRecursive(child);
    }
}


OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options)
{
	NSAutoreleasePool *  pool = [[NSAutoreleasePool alloc] init];

    //Looks like "normal" NSUserDefaults doesn't work with QuicklookImporter
    NSDictionary* userDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"im.adium.quicklookImporter"];
    BOOL debugLog = [[userDefaults valueForKey:@"debugLog"] boolValue];
    BOOL stripFontStyles = [[userDefaults valueForKey:@"stripStyles"] boolValue];
    
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
        
        if(debugLog)
            NSLog(@"wholeTree: %@", document);
	  
		// Get the account name and protocol from the root node
		NSXMLElement *chatNode = [[document nodesForXPath:@"//chat" error:&error] objectAtIndex:0];
		NSString *account = [[chatNode attributeForName:@"account"] stringValue];
		NSString *service = [[chatNode attributeForName:@"service"] stringValue];

		NSArray *messageNodes = [document nodesForXPath:@"//message | //event | //status" error:nil];

        if(debugLog)
            NSLog(@"Found %lu message nodes", [messageNodes count]);
        
		[html appendFormat: HTML_HEADER, CHATLOG_STYLE];
		[html appendFormat:@"<h1>Adium %@ chat log</h1>\n", service];
	  
		if ([messageNodes count] > 0) {
			[html appendString:@"<table border=\"0\" cellpadding=\"2\">"];

			NSUInteger maxMessages = [[userDefaults valueForKey:@"messageLimit"] unsignedIntegerValue];
            if(maxMessages <= 0)
                maxMessages = 50;
            
            
            NSUInteger messageCount = [messageNodes count];
            NSUInteger currentMessage = 1;
			for (NSXMLElement *message in messageNodes) {
				if (currentMessage >= maxMessages) { 
                    //Append "xx more messages" message
                    [html appendFormat:@"<tr><td class=\"time\" colspan=\"3\">%u more messages</td></tr>\n", messageCount-currentMessage];
					break;
                }
                
                if([[message name] isEqualToString:@"event"]) {
                    if(debugLog)
                        NSLog(@"event node: %@", message);
                } else if([[message name] isEqualToString:@"status"]) { 
                    if(debugLog)
                        NSLog(@"status node: %@", message);

                    NSArray *divs = [message elementsForName:@"div"];
                    if([divs count] > 0) {
                        NSXMLElement* el = [divs objectAtIndex:0];
                        removeStyleRecursive(el);
                        [html appendFormat:@"<tr><td class=\"status\" colspan=\"3\">%@</td></tr>\n", el];
                    }
                } else if([[message name] isEqualToString:@"message"]) {
                    NSString *alias = [[message attributeForName:@"alias"] stringValue];
                    NSString *sender = [[message attributeForName:@"sender"] stringValue];
                    NSString *spanstyle = [sender caseInsensitiveCompare:account] == NSOrderedSame ? @"me" : @"other";
                    
                    NSString *date = [[message attributeForName:@"time"] stringValue];
                    NSString *time = formatDate(date);
                    
                    // Use alias if it is shorter
                    if (alias && [alias length] < [sender length])
                        sender = alias;
                    
                    // Extract the message tag, we could get rid of the span tag too.
                    NSXMLElement *content = [[message elementsForName:@"div"] objectAtIndex:0];
                    if(stripFontStyles == YES) {
                        removeStyleRecursive(content);
                    }
                    
                    if(debugLog)
                        NSLog(@"message node: %@", content);
                    
                    [html appendFormat: 
                     @"<tr><td class=\"time\">%@</td><td class=\"who\"><span class=\"%@\">%@</span>:</td><td class=\"what\">%@</td></tr>\n", 
                     time, spanstyle, sender, content];
                    
                    ++currentMessage;
                }
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

    if(debugLog)
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
