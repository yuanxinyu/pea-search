#include "env.h"
#include "sharelib.h"
#include "history.h"
#include <stdio.h>
#include <locale.h>
#include	<sys/types.h>	/* basic system data types */
#include	<sys/socket.h>	/* basic socket definitions */
#include	<sys/time.h>	/* timeval{} for select() */
#include	<time.h>		/* timespec{} for pselect() */
#include	<netinet/in.h>	/* sockaddr_in{} and other Internet defns */
#include	<arpa/inet.h>	/* inet(3) functions */
#include	<errno.h>
#include	<fcntl.h>		/* for nonblocking */
#include	<netdb.h>
#include	<signal.h>
#include	<sys/stat.h>	/* for S_xxx file mode constants */
#include	<sys/uio.h>		/* for iovec{} and readv/writev */
#include	<unistd.h>
#include	<sys/wait.h>
#include	<sys/un.h>		/* for Unix domain sockets */

#import <Foundation/Foundation.h>
#import "SpecialProtocol.h"

static BOOL connect_unix_socket(int *psock) {
	int	sockfd;
	sockfd = socket(AF_LOCAL, SOCK_STREAM, 0);
	if(sockfd<0) {
		printf("unix domain socket error");
		return 0;
	}else{
		struct sockaddr_un	servaddr;
		bzero(&servaddr, sizeof(servaddr));
		servaddr.sun_family = AF_LOCAL;
		strcpy(servaddr.sun_path, UNIXSTR_PATH);
		if(connect(sockfd, (SA *) &servaddr, sizeof(servaddr))!=0 ) {
			printf("connect error");
			return 0;
		}else{
			*psock = sockfd;
			return 1;
		}
	}
}

#import "browserAppDelegate.h"

@implementation browserAppDelegate

@synthesize window;
@synthesize webView;

-(id) init {
    self = [super init];
	if (self) {
		dir = [[NSString alloc] initWithString:@""];
	}
	return self;
}

- (void) dealloc {
	self.dir = nil;
	[super dealloc];
}

- (NSString *)dir {
	NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    return [[dir retain] autorelease];
}

- (void)setDir:(NSString *)value {
	NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    if (dir != value) {
        [dir release];
        dir = [value copy];
    }
}

- (void)setCaze:(bool)b {
    caze = b;
    NSUserDefaults *persistentDefaults = [NSUserDefaults standardUserDefaults];
    [persistentDefaults setObject:[NSNumber numberWithBool:b] forKey:@"caze"];  
}

- (void)setPersonal:(bool)b {
    personal = b;
    NSUserDefaults *persistentDefaults = [NSUserDefaults standardUserDefaults];
    [persistentDefaults setObject:[NSNumber numberWithBool:b] forKey:@"personal"];  
}

- (void)setFontSize:(int)size {
    fontSize = size;
    NSUserDefaults *persistentDefaults = [NSUserDefaults standardUserDefaults];
    [persistentDefaults setObject:[NSNumber numberWithInt:size] forKey:@"fontSize"];  
}

- (void)awakeFromNib {
    setlocale(LC_ALL, "");
    [SpecialProtocol registerSpecialProtocol];
	NSString *htmlPath = @"/Users/ylt/Documents/gigaso/browser/web/search2.htm";
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:htmlPath]]];
    [window setDelegate:self];
    [window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    [webView setUIDelegate: self];
    [webView setGroupName:@"Gigaso"];
    [webView setFrameLoadDelegate: self];
	[webView setResourceLoadDelegate: self];
    webView.autoresizesSubviews = YES; 
    //webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight );
    order=0;
    file_type=0;
    offline=false;
    NSUserDefaults *persistentDefaults = [NSUserDefaults standardUserDefaults];
    [persistentDefaults setObject:@"" forKey:@"myDefault"];
    caze = [[persistentDefaults objectForKey:@"caze"] boolValue];
    personal = [[persistentDefaults objectForKey:@"personal"] boolValue];
    fontSize =  [[persistentDefaults objectForKey:@"fontSize"] intValue];
    if(fontSize<6 || fontSize>18) fontSize=12;
}


- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return TRUE;
}

+ (NSArray *)restorableStateKeyPaths{
    return [[super restorableStateKeyPaths] arrayByAddingObject:@"frameForNonFullScreenMode"];
}

- (void)webView:(WebView *)webView windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject{
    [windowScriptObject setValue:self forKey:@"plugin"];
    [windowScriptObject evaluateWebScript: @"cef = {};cef.plugin=plugin;cef.gigaso=plugin;"];
    connect_unix_socket(&sockfd);
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{
    id win = [webView windowScriptObject];
    [win evaluateWebScript: @"init_dir('search.exe')"];
}

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message {
	NSLog(@"%@", message);
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    [alert release];
}

- (BOOL)webView:(WebView *)sender runJavaScriptConfirmPanelWithMessage:(NSString *)message{
    NSLog(@"%@", message);
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    NSInteger button = [alert runModal];
    [alert release];
    return button == NSAlertFirstButtonReturn;
}

- (WebView *)webView:(WebView *)sender createWebViewWithRequest:(NSURLRequest *)request{
    NSLog(@"%@", request);//为什么request is null?
    //[[webView mainFrame] loadRequest: request];
    NSLog(@"%@", [[[request URL] absoluteString ] UTF8String]);
    system([[[request URL] absoluteString ] UTF8String] );
    return webView;
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
    return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)property {
    return NO;
}

+ (NSString *)webScriptNameForKey:(const char *)name{
    if (strcmp(name, "dir")==0) {
		return @"dire";
	} else {
		return nil;
	}
}

+ (NSString *) webScriptNameForSelector:(SEL)sel {
    if (sel == @selector(search:)) {
		return @"search";
    } else if (sel == @selector(stat:)) {
		return @"stat";
    } else if (sel == @selector(hisDel:)) {
		return @"hisDel";
    } else if (sel == @selector(hisPin:)) {
		return @"hisPin";
    } else if (sel == @selector(hisUnpin:)) {
		return @"hisUnpin";
    } else if (sel == @selector(shellDefault:)) {
		return @"shellDefault";
    } else if (sel == @selector(shellExplore:)) {
		return @"shellExplore";
    } else if (sel == @selector(shell2:action:)) {
		return @"shell2";
    } else if (sel == @selector(copyPath:)) {
            return @"copyPath";
	} else if (sel == @selector(term:)) {
        return @"term";
	}else {
		return nil;
	}
}

static int MAX_ROW = 1000;

static ssize_t read_all(int fildes, char *buf, size_t nbyte){
    int read_bytes=0;
    char *buffer = buf;
    do{
        int ret = read(fildes,buffer,nbyte);
        if(ret<=0) return ret;
        read_bytes+=ret;
        buffer+=ret;
    }while(read_bytes<nbyte);
    return read_bytes;
}
- (NSString*) query: (NSString*) query row: (int) row{
    NSLog(query);
    SearchRequest req;
	SearchResponse resp;
	memset(&req,0,sizeof(SearchRequest));
	req.from = 0;
	req.rows = row;
	req.env.order = order;
	req.env.case_sensitive = caze;
	req.env.offline = offline? 1:0;
    req.env.personal = personal? 1:0;
	req.env.file_type = file_type;
	req.env.path_len = [dir length];
	if(req.env.path_len>0){
        const char * dutf8 = [dir UTF8String];
		strncpy(req.env.path_name, dutf8, MAX_PATH);
    }
	if([query length]==0) return @"";
    const char * qutf8 = [query UTF8String];
	mbsnrtowcs(req.str, (const char **)&qutf8,  strlen(qutf8), MAX_PATH, NULL);
    if (write(sockfd, &req, sizeof(SearchRequest))<=0) {
        printf("scoket write error");
        return @"error";
    }
    if(read(sockfd, &resp, sizeof(int))>0){
        char buffer[MAX_RESPONSE_LEN];
        DWORD len = resp.len;
        int err;
        memset(buffer,(char)0,MAX_RESPONSE_LEN);
        err=read_all(sockfd, buffer, len);
        printf("---len:%d, read:%d\n", len,err);
        if(err<=0){
            printf("scoket read error.\n");
            return @"error";
        }
        return [NSString stringWithUTF8String: buffer];
    }else{
        printf("scoket read error");
        return @"error";
    }
}

- (NSString*) search: (NSString*) query{
    return [self query:query row:MAX_ROW];
}

- (NSString*) stat: (NSString*) query{
    return [self query:query row:-1];
}

#if big_endian
#define WCHAR_ENCODING NSUTF32BigEndianStringEncoding
#else
#define WCHAR_ENCODING NSUTF32LittleEndianStringEncoding
#endif


- (NSString*) history{
	TCHAR buffer[VIEW_HISTORY*MAX_PATH];
	int len;
	history_load();
	len = history_to_json(buffer);
    NSString* ret = [[NSString alloc] initWithUTF8String:buffer];
    return ret;
}

- (BOOL) hisDel: (int) index{
    history_delete(index);
    return history_save();
}
- (BOOL) hisPin: (int) index{
    history_pin(index);
    return history_save(); 
}
- (BOOL) hisUnpin: (int) index{
    history_unpin(index);
    return history_save();
}

static BOOL shell_exec(NSString* file, char* param){
 	char buffer[MAX_PATH*2];
    const char *filename = [file cStringUsingEncoding:NSUTF8StringEncoding];
    snprintf(buffer,MAX_PATH*2,"open %s \"%s\"",param,filename);
	bool ret = system(buffer)==0;
	if(ret){
		if( history_add(filename) ) history_save();
	}
    return ret;   
}

- (BOOL) shellDefault: (NSString*) file{
    return shell_exec(file,"");
}
- (BOOL) shellExplore: (NSString*) file{
    return shell_exec(file,"-R");
}
- (BOOL) shell2: (NSString*) file action: (NSString*)action{
    if([action compare:@"copy"]==NSOrderedSame){
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:self];
        [pb clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:[NSURL fileURLWithPath:file]];
        return [pb writeObjects:copiedObjects];
    }else if([action compare:@"drag"]==NSOrderedSame){
        NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSDragPboard];
        [pb declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:self];
        [pb clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:[NSURL fileURLWithPath:file]];
        return [pb writeObjects:copiedObjects];
    }else if([action compare:@"delete"]==NSOrderedSame){
        FSRef fsRef;
        FSPathMakeRefWithOptions(
                                 (const UInt8 *)[file fileSystemRepresentation],
                                 kFSPathMakeRefDoNotFollowLeafSymlink,
                                 &fsRef,
                                 NULL // Boolean *isDirectory
                                 );
        OSStatus ret = FSMoveObjectToTrashSync(&fsRef, NULL, kFSFileOperationDefaultOptions);
        return ret==0;
        //return [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
    }else if([action compare:@"properties"]==NSOrderedSame){
        NSString *scpt = [NSString stringWithFormat:@"tell application \"Finder\"\n"
                          "	activate\n"
                          "	open information window of alias (POSIX file \"%@\")\n"
                          "end tell", file];
        NSAppleScript* appleScript = [[NSAppleScript alloc] initWithSource:scpt];
        [appleScript executeAndReturnError:nil];
        [appleScript release];
    }else if([action compare:@"openas"]==NSOrderedSame){
        //TODO: 
    }
}

- (BOOL) term: (NSString*) path{
    return shell_exec(path,"-a Terminal");
}

- (BOOL) copyPath: (NSString*) file{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType]
               owner:self];
    return [pb setString:file forType:NSStringPboardType];    
}


- (NSString*) selectDir{
    NSOpenPanel *panel;
    panel = [NSOpenPanel openPanel];
    [panel setFloatingPanel:YES];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    NSInteger i = [panel runModal];
    if(i == NSOKButton){
        return [panel filename];
    } 
    return @"";
}

@end