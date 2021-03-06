#import <Foundation/Foundation.h>
#include <err.h>
#include "kern_utils.h"
#include "patchfinder64.h"
#include "jelbrek.h"
#include <AppSupport/CPDistributedMessagingCenter.h>
#include "offsets.h"

mach_port_t tfp0;
uint64_t kernel_base;
uint64_t kernel_slide;
int pid;


@interface Listener : NSObject
- (NSDictionary *)rootme:(NSString *)name message:(NSDictionary *)userInfo;
- (NSDictionary *)unsandbox:(NSString *)name message:(NSDictionary *)userInfo;
- (NSDictionary *)platformize:(NSString *)name message:(NSDictionary *)userInfo;
- (NSDictionary *)entitle:(NSString *)name message:(NSDictionary *)userInfo;
- (NSDictionary *)setcsflags:(NSString *)name message:(NSDictionary *)userInfo;
-(id)init;
@end

@implementation Listener
-(id)init {
    
    NSLog(@"Listening...");
    
    CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"com.jakeashacks.jbclient"]; //CPDistributedMessagingCenter is a great way to send messages between processes, without advanced knowledge at all. Why bother with Electra's way when the system offers APIs to handle all the messages?
    [messagingCenter runServerOnCurrentThread];
    [messagingCenter registerForMessageName:@"rootme" target:self selector:@selector(rootme:message:)];
    [messagingCenter registerForMessageName:@"unsandbox" target:self selector:@selector(unsandbox:message:)];
    [messagingCenter registerForMessageName:@"platformize" target:self selector:@selector(platformize:message:)];
    [messagingCenter registerForMessageName:@"entitle" target:self selector:@selector(entitle:message:)];
    [messagingCenter registerForMessageName:@"setcsflags" target:self selector:@selector(setcsflags:message:)];
    
    CFRunLoopRun(); //this ensures that the binary will keep running
}

- (NSDictionary *)rootme:(NSString *)name message:(NSDictionary *)userInfo {
    pid = atoi([[userInfo objectForKey:@"pid"] UTF8String]);
    printf("[*] Got request from pid %d\n", pid);
    get_root(pid);
    return 0;
}

- (NSDictionary *)unsandbox:(NSString *)name message:(NSDictionary *)userInfo {
    pid = atoi([[userInfo objectForKey:@"pid"] UTF8String]);
    printf("[*] Got request from pid %d\n", pid);
    unsandbox(pid);
    return 0;
}
- (NSDictionary *)platformize:(NSString *)name message:(NSDictionary *)userInfo {
    pid = atoi([[userInfo objectForKey:@"pid"] UTF8String]);
    printf("[*] Got request from pid %d\n", pid);
    platformize(pid);
    return 0;
}
- (NSDictionary *)entitle:(NSString *)name message:(NSDictionary *)userInfo {
    pid = atoi([[userInfo objectForKey:@"pid"] UTF8String]);
    printf("[*] Got request from pid %d\n", pid);
    char *ent = [[userInfo objectForKey:@"ent"] UTF8String];
    NSString *val = [[userInfo objectForKey:@"value"] UTF8String];
    BOOL valb;
    if ([val isEqualToString:@"true"]) valb = true;
    else if ([val isEqualToString:@"false"]) valb = false;
    else  {
        fprintf(stderr, "Error, entitlement value not a boolean\n");
        return 0;
    }
    entitlePid(pid, ent, val);
    return 0;
}
- (NSDictionary *)setcsflags:(NSString *)name message:(NSDictionary *)userInfo {
    pid = atoi([[userInfo objectForKey:@"pid"] UTF8String]);
    printf("[*] Got request from pid %d\n", pid);
    setcsflags(pid);
    return 0;
}
@end

kern_return_t init_tfp0() {
    fprintf(stdout, "[*] Initializing jailbreakd\n");
    
    kern_return_t ret = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
    
    if (ret != KERN_SUCCESS) {
        fprintf(stderr,"[*] ERROR: host_get_special_port 4: %s\n", mach_error_string(err));
        return -1;
    }
    fprintf(stdout, "[*] Got tfp0!\n");
    
    kernel_base = strtoull(getenv("KernelBase"), NULL, 16);
    kernel_slide = kernel_base - 0xFFFFFFF007004000;
    fprintf(stdout,"[*] kaslr slide: 0x%016llx\n", kernel_slide);
    
    init_jelbrek(tfp0, kernel_base);
    
    return ret;
}


int main(int argc, char **argv, char **envp) {
    remove_memory_limit(); //Electra's jailbreakd does this and since I don't wanna run into trouble with memory I'm doing it too
    offsets_init();
    init_tfp0();
    
    //caches addresses, idea stolen from Electra but I used some more common sense and did it the obvious way
    find_allproc();
    find_zone_map_ref();
    find_OSBoolean_True();
    find_OSBoolean_False();
    find_osunserializexml();
    
    [[Listener alloc] init]; //allocate a new listener and start listening!
	return 0;
}

// vim:ft=objc
