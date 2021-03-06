//
//  ChatlogRenderer.m
//  AdiumChatQuickLook
//
//  Created by Moritz Ulrich on 11.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ChatlogRenderer.h"

@implementation ChatlogRenderer

#define PROJECT_ID @"im.adium.quicklookImporter"

@synthesize url=_url;
@synthesize account=_account;
@synthesize service=_service;

- (void)dealloc {
    [rendererBundle release];
    [super dealloc];
}

- (NSString*)generateHTMLForURL:(NSURL*)url {
    self.url = url;
    
    NSDictionary* userDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:PROJECT_ID];
    debugLog = [[userDefaults valueForKey:@"debugLog"] boolValue];
    stripFontStyles = [[userDefaults valueForKey:@"stripStyles"] boolValue];
    //NSUInteger messageLimit = [[userDefaults valueForKey:@"messageLimit"] unsignedIntegerValue];
    
#warning This is a workaround for getting a working NSBundle. When included in Adium, [NSBundle mainBundle] should work
    rendererBundle = [[NSBundle bundleWithIdentifier:PROJECT_ID] retain];
    
    NSError* error = nil;
    NSXMLDocument *document = [[[NSXMLDocument alloc] initWithContentsOfURL:url
                                                                    options:0
                                                                      error:&error] autorelease];
    
    if (!document || error) {
        return [NSString stringWithFormat:@"Error reading the XML, %@", error];
    }
    
    if(debugLog)
        NSLog(@"wholeTree: %@", document);
    
    NSXMLElement* chatNode = [[document nodesForXPath:@"/chat" error:&error] objectAtIndex:0];
    self.account = [[chatNode attributeForName:@"account"] stringValue];
    self.service = [[chatNode attributeForName:@"service"] stringValue];

    NSXMLElement* bodyElement = [NSXMLElement
                                 elementWithName:@"body" 
                                 children:[NSArray arrayWithObject:[self generateTableFromChatElement:chatNode]]
                                 attributes:nil];
    NSXMLDocument* htmlElement = [NSXMLElement elementWithName:@"html"
                                                     children:[NSArray arrayWithObjects:
                                                               [self generateHead],
                                                               bodyElement, nil]
                                                   attributes:nil];
    
    if(debugLog)
        NSLog(@"html: %@", htmlElement);
    
    return [NSString stringWithFormat:@"%@", htmlElement];
}
                                 
#pragma mark - Methods to generate HTML
                                 
- (NSXMLElement*)generateHead {
    NSError* error = nil;
    NSString* cssStyle = [NSString stringWithContentsOfURL:[rendererBundle URLForResource:@"chatlog" withExtension:@"css"]
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    if(error) {
        NSLog(@"Error loading style: %@", [error description]);
        error = nil;
    }
    
    return [NSXMLElement elementWithName:@"head"
                                children:[NSArray arrayWithObject:[NSXMLElement elementWithName:@"style" stringValue:cssStyle]]
                              attributes:nil];
}

- (NSXMLElement*)generateTableFromChatElement:(NSXMLElement*)chatElement {
    NSXMLElement* table = [NSXMLElement elementWithName:@"table"];
    
    for(NSXMLElement* node in [chatElement children]) {
        if([node.name caseInsensitiveCompare:@"message"] == NSOrderedSame) {
            [table addChild:[self generateMessageRow:node]];
        } else if([node.name caseInsensitiveCompare:@"event"] == NSOrderedSame) {
            [table addChild:[self generateEventRow:node]];
        } else if([node.name caseInsensitiveCompare:@"status"] == NSOrderedSame) {
            [table addChild:[self generateStatusRow:node]];
        }
    }
    
    return table;
}

- (NSXMLElement*)generateTimestampFromMessage:(NSXMLElement*)message {
    NSString* timeString = [[message attributeForName:@"time"] stringValue];
    if(!timeString)
        return nil;
    
    return [NSXMLElement elementWithName:@"td" 
                                children:[NSArray arrayWithObject:[NSXMLElement textWithStringValue:[ChatlogRenderer 
                                                                                                     formatDate:timeString]]]
                              attributes:[NSArray arrayWithObject:[NSXMLElement attributeWithName:@"class" stringValue:@"time"]]];
}

- (NSXMLElement*)generateNameFromMessage:(NSXMLElement*)message {
    NSString* sender = [[message attributeForName:@"sender"] stringValue];
    NSString* name = [[message attributeForName:@"alias"] stringValue];
    if(!name) name = sender;
    
    NSString *spanstyle = [sender caseInsensitiveCompare:self.account] == NSOrderedSame ? @"me" : @"other";
    NSXMLElement* span = [NSXMLElement elementWithName:@"span"
                                              children:[NSArray arrayWithObject:[NSXMLElement textWithStringValue:name]]
                                            attributes:[NSArray arrayWithObject:[NSXMLElement attributeWithName:@"class" 
                                                                                                    stringValue:spanstyle]]];
    
    return [NSXMLElement elementWithName:@"td" 
                                children:[NSArray arrayWithObjects:span, [NSXMLElement textWithStringValue:@":"], nil]
                              attributes:[NSArray arrayWithObject:[NSXMLElement attributeWithName:@"class" stringValue:@"who"]]];
}

- (NSXMLElement*)generateTextFromMessage:(NSXMLElement*)message {
    NSXMLElement *content = [[[message objectsForXQuery:@".//div" error:NULL] objectAtIndex:0] copy];
    
    if(stripFontStyles == YES)
        [ChatlogRenderer removeStyleRecursive:content];
    
    return [NSXMLElement elementWithName:@"td" 
                                children:[NSArray arrayWithObject:content]
                              attributes:[NSArray arrayWithObject:[NSXMLElement attributeWithName:@"class" stringValue:@"what"]]];
}

- (NSXMLElement*)generateMessageRow:(NSXMLElement*)message {
    return [NSXMLElement elementWithName:@"tr"
                                children:[NSArray arrayWithObjects:
                                          [self generateTimestampFromMessage:message],
                                          [self generateNameFromMessage:message],
                                          [self generateTextFromMessage:message], nil]
                              attributes:nil];
}

- (NSXMLElement*)generateEventRow:(NSXMLElement*)event {
    return nil;
}

- (NSXMLElement*)generateStatusRow:(NSXMLElement*)status {
    NSLog(@"statusRow: %@:", status);
    
    NSString* sender = [[status attributeForName:@"sender"] stringValue];
    
    if([sender isEqual:self.account]) {
        //My own event!
        NSXMLElement* content = [[[status objectsForXQuery:@".//div" error:NULL] objectAtIndex:0] copy];
        if(stripFontStyles == YES)
            [ChatlogRenderer removeStyleRecursive:content];
        
        NSString* eventString = [NSString stringWithFormat:@"%@ (%@)", 
                                 [[content childAtIndex:0] stringValue],
                                 [ChatlogRenderer formatDate:[[status attributeForName:@"time"] stringValue]]];
        
        content = [NSXMLElement elementWithName:@"div" 
                                       children:[NSArray arrayWithObject:[NSXMLElement textWithStringValue:eventString]]
                                     attributes:nil];
        
        NSXMLElement* row = [NSXMLElement elementWithName:@"td"
                                                 children:[NSArray arrayWithObject:content]
                                               attributes:[NSArray arrayWithObjects:
                                                           [NSXMLElement attributeWithName:@"class" 
                                                                               stringValue:@"event"],
                                                           [NSXMLElement attributeWithName:@"colspan" 
                                                                               stringValue:@"3"], nil]];
        return [NSXMLElement elementWithName:@"tr"
                                    children:[NSArray arrayWithObject:row]
                                  attributes:nil];
    } else {
        return nil;
    }
}
    
#pragma mark - Utility Methods

+ (NSString*)formatDate:(NSString*)s {
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

+ (void)removeStyleRecursive:(NSXMLElement*)el {
    if(el.kind == NSXMLElementKind) {
        [el removeAttributeForName:@"class"];
        [el removeAttributeForName:@"style"];
    }

    for(NSXMLElement* child in [el children]) {
        [self removeStyleRecursive:child];
    }
}

@end
