//
//  main.m
//  LiveControllerConsole
//
//  Created by Daniel Lang on 29/05/14.
//  Copyright (c) 2014 KISI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ORSSerialPortManager.h"
#import "ORSSerialPort.h"

@interface ORSSerialPortHelper : NSObject <ORSSerialPortDelegate>
@property (nonatomic, strong) ORSSerialPort *serialPort;
@property (nonatomic, strong) NSString *lastBitOfMessage;
@property (nonatomic, strong) NSString *activePreview;
@property (nonatomic, strong) NSString *activeLive;
@property (nonatomic, strong) NSString *activeEffects;

- (void)sendToSerialWithMessage: (NSString *) message;
- (void)setLights;

@end

typedef NS_ENUM(NSUInteger, ORSApplicationState) {
	ORSInitializationState = 0,
	ORSWaitingForPortSelectionState,
	ORSWaitingForBaudRateInput,
	ORSWaitingForUserInputState,
};

static ORSApplicationState gCurrentApplicationState = ORSInitializationState;
static ORSSerialPortHelper *serialPortHelper = nil;

void printPrompt(void)
{
	printf("\n> ");
}

void listAvailablePorts(void)
{
	printf("\nPlease select a serial port: \n");
	ORSSerialPortManager *manager = [ORSSerialPortManager sharedSerialPortManager];
	NSArray *availablePorts = manager.availablePorts;
	[availablePorts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		ORSSerialPort *port = (ORSSerialPort *)obj;
		printf("%lu. %s (%s)\n", (unsigned long)idx, [port.name UTF8String], [port.path UTF8String]);
	}];
	printPrompt();
}

void promptForBaudRate(void)
{
	printf("\nPlease enter a baud rate:");
}

BOOL setupAndOpenPortWithSelectionString()
{
//	selectionString = [selectionString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//	NSCharacterSet *invalidChars = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
//	if ([selectionString rangeOfCharacterFromSet:invalidChars].location != NSNotFound) return NO;
//	
//	ORSSerialPortManager *manager = [ORSSerialPortManager sharedSerialPortManager];
//	NSArray *availablePorts = manager.availablePorts;
//	
//	NSInteger index = [selectionString integerValue];
//	index = MIN(MAX(index, 0), [availablePorts count]-1);
	
//	ORSSerialPort *port = [availablePorts objectAtIndex:index];
    ORSSerialPort *port = [ORSSerialPort serialPortWithPath:@"/dev/cu.usbserial-FTR6TP9F"];
	serialPortHelper = [[ORSSerialPortHelper alloc] init];
	serialPortHelper.serialPort = port;
    serialPortHelper.lastBitOfMessage = [[NSString alloc] init];
	port.delegate = serialPortHelper;
	[port open];
    [serialPortHelper sendToSerialWithMessage:@"*I"];
    serialPortHelper.activePreview = @"~17FF";
    serialPortHelper.activeLive = @"~27FF";
    serialPortHelper.activeEffects = @"~F7FF";
    [serialPortHelper setLights];
	return YES;
}

BOOL setBaudRateOnPortWithString()
{
//	string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//	NSCharacterSet *invalidChars = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
//	if ([string rangeOfCharacterFromSet:invalidChars].location != NSNotFound) return NO;
//    
//	NSInteger baudRate = [string integerValue];
//	serialPortHelper.serialPort.baudRate = @(baudRate);
    serialPortHelper.serialPort.baudRate = @(9600);
//	printf("Baud rate set to %li", (long)baudRate);
	return YES;
}

void handleUserInputData(NSData *dataFromUser)
{
	NSString *string = [[NSString alloc] initWithData:dataFromUser encoding:NSUTF8StringEncoding];
	if ([string rangeOfString:@"exit" options:NSCaseInsensitiveSearch].location == 0 ||
		[string rangeOfString:@"quit" options:NSCaseInsensitiveSearch].location == 0)
	{
		printf("Quitting...\n");
		exit(0);
		return;
	}
    
	switch (gCurrentApplicationState) {
		case ORSWaitingForPortSelectionState:
			if (!setupAndOpenPortWithSelectionString())
			{
				printf("\nError: Invalid port selection.");
				listAvailablePorts();
				return;
			}
//			promptForBaudRate();
//			gCurrentApplicationState = ORSWaitingForBaudRateInput;
			break;
		case ORSWaitingForBaudRateInput:
			if (!setBaudRateOnPortWithString())
			{
				printf("\nError: Invalid baud rate. Baud rate should consist only of numeric digits.");
				promptForBaudRate();
				return;
			}
			gCurrentApplicationState = ORSWaitingForUserInputState;
			printPrompt();
			break;
		case ORSWaitingForUserInputState:
			[serialPortHelper.serialPort sendData:dataFromUser];
			printPrompt();
			break;
		default:
			break;
	}
}

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        if ([[[ORSSerialPortManager sharedSerialPortManager] availablePorts] count] == 0)
        {
            printf("No connected serial ports found. Please connect your USB to serial adapter(s) and run the program again.\n\n");
			return 0;
        }

        
//        listAvailablePorts();
//        gCurrentApplicationState = ORSWaitingForPortSelectionState;
        
        setupAndOpenPortWithSelectionString();
        setBaudRateOnPortWithString();
        
        NSFileHandle *standardInputHandle = [NSFileHandle fileHandleWithStandardInput];
		standardInputHandle.readabilityHandler = ^(NSFileHandle *fileHandle) { handleUserInputData([fileHandle availableData]); };
		
		[[NSRunLoop currentRunLoop] run]; // Required to receive data from ORSSerialPort and to process user input
		
		// Cleanup
		standardInputHandle.readabilityHandler = nil;
		serialPortHelper = nil;
    }
    return 0;
}

@implementation ORSSerialPortHelper

- (void)serialPort:(ORSSerialPort *)serialPort didReceiveData:(NSData *)data
{
    
    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    
    NSArray *parts = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"~"]];
    string = @"";
    
    if([parts count] == 2) {
        if([parts[0] isEqualToString:@""] && [parts[1] length] == 4) {
            string = [NSString stringWithFormat:@"~%@", parts[1]];
        }
        else {
            string = [NSString stringWithFormat:@"~%@%@", self.lastBitOfMessage, parts[0]];
            self.lastBitOfMessage = parts[1];
        }
    }
    else {
        if([parts[0] length] + [self.lastBitOfMessage length] == 4) {
            string = [NSString stringWithFormat:@"~%@%@", self.lastBitOfMessage, parts[0]];
            if([parts count] == 2) self.lastBitOfMessage = parts[1];
            else self.lastBitOfMessage = @"";
        }
        else {
            self.lastBitOfMessage = [NSString stringWithFormat:@"%@%@", self.lastBitOfMessage, parts[0]];
        }
    }
    
    if((![string isEqualToString:@"~1FFF"] && ![string isEqualToString:@"~2FFF"] && ![string isEqualToString:@"~FFFF"] && [string length] == 5)
       || ([string isEqualToString:@"~3F7"] || [string isEqualToString:@"~3FD"])) {
        NSString *button = [[NSString alloc] init];
        
        if([string isEqualToString:@"~17FF"]) {
            button = @"Preview 1";
        }
        else if ([string isEqualToString:@"~1BFF"]) {
            button = @"Preview 2";
        }
        else if([string isEqualToString:@"~1DFF"]) {
            button = @"Preview 3";
        }
        else if([string isEqualToString:@"~1EFF"]) {
            button = @"Preview 4";
        }
        else if([string isEqualToString:@"~1F7F"]) {
            button = @"Preview 5";
        }
        else if([string isEqualToString:@"~1FBF"]) {
            button = @"Preview 6";
        }
        else if([string isEqualToString:@"~1FDF"]) {
            button = @"Preview EXT";
        }
        else if([string isEqualToString:@"~1FEF"]) {
            button = @"Preview DDR1";
        }
        else if([string isEqualToString:@"~1FF7"]) {
            button = @"Preview DDR2";
        }
        else if([string isEqualToString:@"~1FFB"]) {
            button = @"Preview TXT";
        }
        else if([string isEqualToString:@"~1FFD"]) {
            button = @"Preview BKG";
        }
        
        else if([string isEqualToString:@"~27FF"]) {
            button = @"Live 1";
        }
        else if([string isEqualToString:@"~2BFF"]) {
            button = @"Live 2";
        }
        else if([string isEqualToString:@"~2DFF"]) {
            button = @"Live 3";
        }
        else if([string isEqualToString:@"~2EFF"]) {
            button = @"Live 4";
        }
        else if([string isEqualToString:@"~2F7F"]) {
            button = @"Live 5";
        }
        else if([string isEqualToString:@"~2FBF"]) {
            button = @"Live 6";
        }
        else if([string isEqualToString:@"~2FDF"]) {
            button = @"Live EXT";
        }
        else if([string isEqualToString:@"~2FEF"]) {
            button = @"Live DDR1";
        }
        else if([string isEqualToString:@"~2FF7"]) {
            button = @"Live DDR2";
        }
        else if([string isEqualToString:@"~2FFB"]) {
            button = @"Live TXT";
        }
        else if([string isEqualToString:@"~2FFD"]) {
            button = @"Live BKG";
        }
        
        
        else if ([string isEqualToString:@"~F7FF"]) {
            button = @"Effect 1";
        }
        else if ([string isEqualToString:@"~FBFF"]) {
            button = @"Effect 2";
        }
        else if ([string isEqualToString:@"~FDFF"]) {
            button = @"Effect 3";
        }
        else if ([string isEqualToString:@"~FEFF"]) {
            button = @"Effect 4";
        }
        else if ([string isEqualToString:@"~FF7F"]) {
            button = @"Effect 5";
        }
        else if ([string isEqualToString:@"~FFBF"]) {
            button = @"Effect 6";
        }
        else if ([string isEqualToString:@"~FFDF"]) {
            button = @"Effect EXT";
        }
        else if ([string isEqualToString:@"~FFEF"]) {
            button = @"Effect DDR1";
        }
        else if ([string isEqualToString:@"~FFF7"]) {
            button = @"Effect DDR2";
        }
        else if ([string isEqualToString:@"~FFFB"]) {
            button = @"Effect TXT";
        }
        else if ([string isEqualToString:@"~FFFD"]) {
            button = @"Effect BKG";
        }
        
        else if([string isEqualToString:@"~3F7"]) {
            button = @"Auto";
        }
        else if([string isEqualToString:@"~3FD"]) {
            button = @"Take";
        }
        
        if([button hasPrefix:@"Preview"]) {
            self.activePreview = string;
        }
        else if([button hasPrefix:@"Live"]) {
            self.activeLive = string;
        }
        else if([button hasPrefix:@"Effect"]) {
            self.activeEffects = string;
        }
        
        
        [self setLights];
        
        
        printf("\n%s (%s)", [button UTF8String], [string UTF8String]);
        printPrompt();
    }
}

- (void)serialPort:(ORSSerialPort *)serialPort didEncounterError:(NSError *)error
{
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, serialPort, error);
}

- (void)serialPortWasRemovedFromSystem:(ORSSerialPort *)serialPort
{
    self.serialPort = nil;
}

- (void)serialPortWasOpened:(ORSSerialPort *)serialPort
{
	printf("Serial port %s was opened", [serialPort.name UTF8String]);
	printPrompt();
}

- (void)serialPortWasClosed:(ORSSerialPort *)serialPort
{
    self.serialPort = nil;
}

- (void)sendToSerialWithMessage: (NSString *) message
{
    NSData *dataToSend = [[NSString stringWithFormat:@"%@\r", message] dataUsingEncoding:NSUTF8StringEncoding];
    [self.serialPort sendData:dataToSend];
}

- (void)setLights
{
    [self sendToSerialWithMessage:self.activeLive];
    [self sendToSerialWithMessage:self.activePreview];
    [self sendToSerialWithMessage:self.activeEffects];
    [self sendToSerialWithMessage:@"~3fa"];
    [self sendToSerialWithMessage:@"^1fb"];
    [self sendToSerialWithMessage:@"^F77"];
}

@end