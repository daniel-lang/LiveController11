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
#include <arpa/inet.h>
#import "ATEMCommander.h"


@interface ORSSerialPortHelper : NSObject <ORSSerialPortDelegate>
@property (nonatomic, strong) ORSSerialPort *serialPort;
@property (nonatomic, strong) NSString *lastBitOfMessage;
@property (nonatomic, strong) NSString *activePreview;
@property (nonatomic, strong) NSString *activeLive;
@property (nonatomic, strong) NSString *activeEffects;

- (void)sendToSerialWithMessage: (NSString *) message;
- (void)setLights;
- (NSString*)changeLiveToPreviewWithKey: (NSString*)key;
- (NSString*)changePreviewToLiveWithKey: (NSString*)key;

@end

typedef NS_ENUM(NSUInteger, ORSApplicationState) {
	ORSInitializationState = 0,
	ORSWaitingForPortSelectionState,
	ORSWaitingForBaudRateInput,
	ORSWaitingForUserInputState,
};

static ORSApplicationState gCurrentApplicationState = ORSInitializationState;
static ORSSerialPortHelper *serialPortHelper = nil;

static ATEMCommanderDelegate *atem;

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

bool isIp(NSString* string) {
    struct in_addr pin;
    int success = inet_aton([string UTF8String],&pin);
    if (success == 1) return TRUE;
    return FALSE;
}




int main(int argc, const char * argv[])
{
    @autoreleasepool {
        if ([[[ORSSerialPortManager sharedSerialPortManager] availablePorts] count] == 0)
        {
            printf("No connected serial ports found. Please connect your USB to serial adapter(s) and run the program again.\n\n");
			return 0;
        }
        
        
        //     listAvailablePorts();
        //        gCurrentApplicationState = ORSWaitingForPortSelectionState;
        
        setupAndOpenPortWithSelectionString();
        setBaudRateOnPortWithString();
        
        
        // asks for valid ip address at startup from the command line
        // for example ./LiveController 10.0.0.127
        
        // improves startup time and usability of programm
        
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        if ([arguments count] != 2) {
            printf("Invalid number of arguments. Please specify a valid IP Adress.\n\n");
            return 0;
        }
        if (!isIp([arguments objectAtIndex:1])) {
            printf("Please specify a valid IP Adress.\n\n");
            return 0;
        }
      

        //  connect to ATEM

        atem = [[ATEMCommanderDelegate alloc] initWithIP:[arguments objectAtIndex:1]];
        
        if([atem connectToATEM]) {
            NSLog(@"Connected to ATEM");
        } else {
            NSLog(@"Connection unsuccessfull\nQuitting now\n\n");
            [atem quit];
            return 0;
        }
        
                
        
        NSFileHandle *standardInputHandle = [NSFileHandle fileHandleWithStandardInput];
		standardInputHandle.readabilityHandler = ^(NSFileHandle *fileHandle) { handleUserInputData([fileHandle availableData]); };
		
		[[NSRunLoop currentRunLoop] run]; // Required to receive data from ORSSerialPort and to process user input
		
		// Cleanup
        [atem quit];
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
    // how is this possible? string not object of nsmutablestring
    
    
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
    
    
    if((![string isEqualToString:@"~1FFF"] && ![string isEqualToString:@"~2FFF"] && ![string isEqualToString:@"~FFFF"] && ![string isEqualToString:@"~^1FF"] && [string length] == 5)
       || ([string isEqualToString:@"~3F7"] || [string isEqualToString:@"~3FD"] || [string isEqualToString:@"~^17F"] || [string isEqualToString:@"~37F"] || [string isEqualToString:@"~3BF"])) {
        NSString *button = [[NSString alloc] init];
        
        if([string isEqualToString:@"~17FF"]) {
            button = @"Preview 1";
            [atem switchPreviewButtonPressed:1];
        }
        else if ([string isEqualToString:@"~1BFF"]) {
            button = @"Preview 2";
            [atem switchPreviewButtonPressed:2];
        }
        else if([string isEqualToString:@"~1DFF"]) {
            button = @"Preview 3";
            [atem switchPreviewButtonPressed:3];
        }
        else if([string isEqualToString:@"~1EFF"]) {
            button = @"Preview 4";
            [atem switchPreviewButtonPressed:4];
        }
        else if([string isEqualToString:@"~1F7F"]) {
            button = @"Preview 5";
            [atem switchPreviewButtonPressed:5];
        }
        else if([string isEqualToString:@"~1FBF"]) {
            button = @"Preview 6";
            [atem switchPreviewButtonPressed:6];
        }
        else if([string isEqualToString:@"~1FDF"]) {
            button = @"Preview EXT";
            [atem switchPreviewButtonPressed:7];
        }
        else if([string isEqualToString:@"~1FEF"]) {
            button = @"Preview DDR1";
            [atem switchPreviewButtonPressed:8];
        }
        else if([string isEqualToString:@"~1FF7"]) {
            button = @"Preview DDR2";
            [atem switchPreviewButtonPressed:9];
        }
        else if([string isEqualToString:@"~1FFB"]) {
            button = @"Preview TXT";
            [atem switchPreviewButtonPressed:10];
        }
        else if([string isEqualToString:@"~1FFD"]) {
            button = @"Preview BKG";
            [atem switchPreviewButtonPressed:11];
        }
        
        else if([string isEqualToString:@"~27FF"]) {
            button = @"Live 1";
            [atem switchLiveButtonPressed:1];
        }
        else if([string isEqualToString:@"~2BFF"]) {
            button = @"Live 2";
            [atem switchLiveButtonPressed:2];
        }
        else if([string isEqualToString:@"~2DFF"]) {
            button = @"Live 3";
            [atem switchLiveButtonPressed:3];
        }
        else if([string isEqualToString:@"~2EFF"]) {
            button = @"Live 4";
            [atem switchLiveButtonPressed:4];
        }
        else if([string isEqualToString:@"~2F7F"]) {
            button = @"Live 5";
            [atem switchLiveButtonPressed:5];
        }
        else if([string isEqualToString:@"~2FBF"]) {
            button = @"Live 6";
            [atem switchLiveButtonPressed:6];
        }
        else if([string isEqualToString:@"~2FDF"]) {
            button = @"Live EXT";
            [atem switchLiveButtonPressed:7];
        }
        else if([string isEqualToString:@"~2FEF"]) {
            button = @"Live DDR1";
            [atem switchLiveButtonPressed:8];
        }
        else if([string isEqualToString:@"~2FF7"]) {
            button = @"Live DDR2";
            [atem switchLiveButtonPressed:9];
        }
        else if([string isEqualToString:@"~2FFB"]) {
            button = @"Live TXT";
            [atem switchLiveButtonPressed:10];
        }
        else if([string isEqualToString:@"~2FFD"]) {
            button = @"Live BKG";
            [atem switchLiveButtonPressed:11];
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
            [atem autoButtonPressed];
            
            NSString* a = [self.activeLive copy];
            
            self.activeLive = [self changePreviewToLiveWithKey:self.activePreview];
            self.activePreview = [self changeLiveToPreviewWithKey:a];
            
        }
        else if([string isEqualToString:@"~3FD"]) {
            button = @"Take";
            [atem cutButtonPressed];
            
            NSString* a = [self.activeLive copy];
            
            self.activeLive = [self changePreviewToLiveWithKey:self.activePreview];
            self.activePreview = [self changeLiveToPreviewWithKey:a];
        }
        else if([string isEqualToString:@"~^17F"]) {
            button = @"FTB";
            [atem FTBButtonPressed];
        }
        else if([string isEqualToString:@"~37F"]) {
            [atem fadeOverlayButtonPressed];
            button = @"Fade Overlay";
        }
        else if([string isEqualToString:@"~3BF"]) {
            [atem takeOverlayButtonPressed];
            button = @"Take Overlay";
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
    
        // set lights accordingly to pressed key
        [self setLights];
        
        
        // find button for FTBButton fade to black
        
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

- (NSString*)changeLiveToPreviewWithKey: (NSString*)key {
    if([key isEqualToString:@"~27FF"]) {
        return @"~17FF";
    }
    else if([key isEqualToString:@"~2BFF"]) {
        return @"~1BFF";
    }
    else if([key isEqualToString:@"~2DFF"]) {
        return @"~1DFF";
    }
    else if([key isEqualToString:@"~2EFF"]) {
        return @"~1EFF";
    }
    else if([key isEqualToString:@"~2F7F"]) {
        return @"~1F7F";
    }
    else if([key isEqualToString:@"~2FBF"]) {
        return @"~1FBF";
    }
    else if([key isEqualToString:@"~2FDF"]) {
        return @"~1FDF";
    }
    else if([key isEqualToString:@"~2FEF"]) {
        return @"~1FEF";
    }
    else if([key isEqualToString:@"~2FF7"]) {
        return @"~1FF7";
    }
    else if([key isEqualToString:@"~2FFB"]) {
        return @"~1FFB";
    }
    else if([key isEqualToString:@"~2FFD"]) {
        return @"~1FFD";
    }
    else if([key isEqualToString:@"~27FF"]) {
        return @"~17FF";
    }
    return [[NSString alloc] init];
}

- (NSString*)changePreviewToLiveWithKey: (NSString*)key {
    if([key isEqualToString:@"~17FF"]) {
        return @"~27FF";
    }
    else if([key isEqualToString:@"~1BFF"]) {
        return @"~2BFF";
    }
    else if([key isEqualToString:@"~1DFF"]) {
        return @"~2DFF";
    }
    else if([key isEqualToString:@"~1EFF"]) {
        return @"~2EFF";
    }
    else if([key isEqualToString:@"~1F7F"]) {
        return @"~2F7F";
    }
    else if([key isEqualToString:@"~1FBF"]) {
        return @"~2FBF";
    }
    else if([key isEqualToString:@"~1FDF"]) {
        return @"~2FDF";
    }
    else if([key isEqualToString:@"~1FEF"]) {
        return @"~2FEF";
    }
    else if([key isEqualToString:@"~1FF7"]) {
        return @"~2FF7";
    }
    else if([key isEqualToString:@"~1FFB"]) {
        return @"~2FFB";
    }
    else if([key isEqualToString:@"~1FFD"]) {
        return @"~2FFD";
    }
    else if([key isEqualToString:@"~17FF"]) {
        return @"~27FF";
    }
    return [[NSString alloc] init];
}
@end