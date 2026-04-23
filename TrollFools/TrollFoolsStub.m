//
//  TrollFoolsStub.m
//  TrollFools
//
//  Created by Lessica on 2024/7/19.
//

#import <Foundation/Foundation.h>
#import <zstd.h>

#import <spawn.h>
#import <stdio.h>
#import <stdlib.h>
#import <sys/sysctl.h>

FOUNDATION_EXTERN void TFUtilKillAll(NSString *processPath, BOOL softly);

static void TFUtilEnumerateProcessesUsingBlock(void (^enumerator)(pid_t pid, NSString *executablePath, BOOL *stop)) {

    static int kMaximumArgumentSize = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      size_t valSize = sizeof(kMaximumArgumentSize);
      if (sysctl((int[]){CTL_KERN, KERN_ARGMAX}, 2, &kMaximumArgumentSize, &valSize, NULL, 0) < 0) {
          perror("sysctl argument size");
          kMaximumArgumentSize = 4096;
      }
    });

    size_t procInfoLength = 0;
    if (sysctl((int[]){CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0}, 3, NULL, &procInfoLength, NULL, 0) < 0) {
        return;
    }

    static struct kinfo_proc *procInfo = NULL;
    procInfo = (struct kinfo_proc *)realloc(procInfo, procInfoLength + 1);
    if (!procInfo) {
        return;
    }

    bzero(procInfo, procInfoLength + 1);
    if (sysctl((int[]){CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0}, 3, procInfo, &procInfoLength, NULL, 0) < 0) {
        return;
    }

    static char *argBuffer = NULL;
    int procInfoCnt = (int)(procInfoLength / sizeof(struct kinfo_proc));
    for (int i = 0; i < procInfoCnt; i++) {

        pid_t pid = procInfo[i].kp_proc.p_pid;
        if (pid <= 1) {
            continue;
        }

        size_t argSize = kMaximumArgumentSize;
        if (sysctl((int[]){CTL_KERN, KERN_PROCARGS2, pid, 0}, 3, NULL, &argSize, NULL, 0) < 0) {
            continue;
        }

        argBuffer = (char *)realloc(argBuffer, argSize + 1);
        if (!argBuffer) {
            continue;
        }

        bzero(argBuffer, argSize + 1);
        if (sysctl((int[]){CTL_KERN, KERN_PROCARGS2, pid, 0}, 3, argBuffer, &argSize, NULL, 0) < 0) {
            continue;
        }

        BOOL stop = NO;
        @autoreleasepool {
            enumerator(pid, [NSString stringWithUTF8String:(argBuffer + sizeof(int))], &stop);
        }

        if (stop) {
            break;
        }
    }
}

void TFUtilKillAll(NSString *processName, BOOL softly) {
    TFUtilEnumerateProcessesUsingBlock(^(pid_t pid, NSString *executablePath, BOOL *stop) {
      if ([executablePath containsString:[NSString stringWithFormat:@"/%@.app/%@", processName, processName]]) {
          if (softly) {
              kill(pid, SIGTERM);
          } else {
              kill(pid, SIGKILL);
          }
      }
    });
}

NSData * _Nullable TFZStdDecompressData(NSData * _Nonnull data) {
    if (data.length == 0) {
        return nil;
    }

    ZSTD_DStream *stream = ZSTD_createDStream();
    if (!stream) {
        return nil;
    }

    size_t initResult = ZSTD_initDStream(stream);
    if (ZSTD_isError(initResult)) {
        ZSTD_freeDStream(stream);
        return nil;
    }

    size_t chunkSize = ZSTD_DStreamOutSize();
    if (chunkSize == 0) {
        chunkSize = 1;
    }

    void *chunk = malloc(chunkSize);
    if (!chunk) {
        ZSTD_freeDStream(stream);
        return nil;
    }

    NSMutableData *output = [NSMutableData data];
    ZSTD_inBuffer input = { .src = data.bytes, .size = data.length, .pos = 0 };
    size_t streamResult = 1;
    BOOL succeeded = YES;

    while (input.pos < input.size || streamResult != 0) {
        size_t previousPos = input.pos;
        ZSTD_outBuffer outBuffer = { .dst = chunk, .size = chunkSize, .pos = 0 };
        streamResult = ZSTD_decompressStream(stream, &outBuffer, &input);
        if (ZSTD_isError(streamResult)) {
            succeeded = NO;
            break;
        }

        if (outBuffer.pos > 0) {
            [output appendBytes:chunk length:outBuffer.pos];
        } else if (input.pos == previousPos && input.pos >= input.size && streamResult != 0) {
            // No progress and frame not complete usually means truncated input.
            succeeded = NO;
            break;
        }
    }

    free(chunk);
    ZSTD_freeDStream(stream);

    if (!succeeded) {
        return nil;
    }

    return output;
}

static NSString *TFGetMarketingVersion(void) {
    return @MARKETING_VERSION;
}

static NSString *TFGetCurrentProjectVersion(void) {
    return @CURRENT_PROJECT_VERSION;
}

NSString *TFGetDisplayVersion(void) {
    static NSString *displayVersion = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        displayVersion = [NSString stringWithFormat:@"%@ (%@)", TFGetMarketingVersion(), TFGetCurrentProjectVersion()];
    });
    return displayVersion;
}
