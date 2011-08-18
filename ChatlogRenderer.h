//
//  ChatlogRenderer.h
//  AdiumChatQuickLook
//
//  Created by Moritz Ulrich on 11.08.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChatlogRenderer : NSObject {
    NSURL* _url;
    NSString* _account;
    NSString* _service;
    
    BOOL stripFontStyles;
    BOOL debugLog;
}

@property(retain) NSURL* url;
@property(retain) NSString* account;
@property(retain) NSString* service;

- (NSString*)generateHTMLForURL:(NSURL*)url;

- (NSXMLElement*)generateHead;
- (NSXMLElement*)generateTableFromChatElement:(NSXMLElement*)chatElement;
- (NSXMLElement*)generateMessageRow:(NSXMLElement*)message;

+ (NSString*)formatDate:(NSString*)s;
+ (void)removeStyleRecursive:(NSXMLElement*)el;

@end
