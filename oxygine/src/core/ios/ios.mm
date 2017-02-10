#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIImage.h>
#import <UIKit/UIApplication.h>
#else
#import <AppKit/AppKit.h>
#endif


#include "ios.h"
#include "Image.h"

#import <mach/mach.h>

namespace oxygine
{
	namespace file
	{
		std::string getSupportFolder()
		{
            NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSFileManager*fm = [NSFileManager defaultManager];
            NSURL*    dirPath = nil;
            
            // Find the application support directory in the home directory.
            NSArray* appSupportDir = [fm URLsForDirectory:NSApplicationSupportDirectory
                                                inDomains:NSUserDomainMask];
            if ([appSupportDir count] > 0)
            {
                // Append the bundle ID to the URL for the
                // Application Support directory
                dirPath = [[appSupportDir objectAtIndex:0] URLByAppendingPathComponent:bundleID];
                
                // If the directory does not exist, this method creates it.
                // This method is only available in OS X v10.7 and iOS 5.0 or later.
                NSError*    theError = nil;
                if (![fm createDirectoryAtURL:dirPath withIntermediateDirectories:YES
                                   attributes:nil error:&theError])
                {
                    // Handle the error.
                    
                    return nil;
                }
            }
            
            return dirPath.fileSystemRepresentation;
        }
	}
    
    namespace operations
    {
        void blit(const ImageData &src, const ImageData &dest);
        void blitPremultiply(const ImageData &src, const ImageData &dest);
    }
    
#ifdef __APPLE__
    bool nsImageLoad(Image &mt, void * pData, int nDatalen, bool premultiplied, TextureFormat destFormat)
    {
        // We need copy here...
        // If you don't copy, this NSData will take ownership of the pointer.
        // In oxygine, the pointer is freed elsewhere, so we need a copy here
        NSData *data = [NSData dataWithBytes:pData length:nDatalen];
#if TARGET_OS_IPHONE
        UIImage *image = [UIImage imageWithData:data];
#else
        NSBitmapImageRep *image = [NSBitmapImageRep imageRepWithData:data];
#endif
        
        GLuint width = (GLuint)CGImageGetWidth(image.CGImage);
        GLuint height = (GLuint)CGImageGetHeight(image.CGImage);
        
        int bits = (int)CGImageGetBitsPerPixel(image.CGImage);
        int pitch = (int)CGImageGetBytesPerRow(image.CGImage);
        
        CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image.CGImage);
        TextureFormat srcFormat = bits == 32 ? TF_R8G8B8A8 : TF_R8G8B8;
        
        if (destFormat == TF_UNDEFINED)
            destFormat = srcFormat;

        
        Image temp;
        temp.init(width, height, srcFormat);
        
        
        ImageData src = temp.lock();
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef imgcontext = CGBitmapContextCreate( src.data, width, height, 8, src.pitch, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
        CGColorSpaceRelease(colorSpace);
        CGContextClearRect(imgcontext, CGRectMake( 0, 0, width, height ) );
        //CGContextTranslateCTM( imgcontext, 0, height - height );
        CGContextDrawImage(imgcontext, CGRectMake( 0, 0, width, height ), image.CGImage );
        
        CGContextRelease(imgcontext);
        
        temp.unlock();

        mt.init(width, height, destFormat);
        ImageData dest = mt.lock();
        
        if (!premultiplied)
        {
            operations::blitPremultiply(src, dest);
        }
        else
        {
            operations::blit(src, dest);
        }
        
        mt.unlock();
        
        
        return true;
    }
#endif
    
    void iosGetMemoryUsage(size_t &a)
    {
        struct task_basic_info info;
        mach_msg_type_number_t size = sizeof(info);
        kern_return_t kerr = task_info(mach_task_self(),
                                       TASK_BASIC_INFO,
                                       (task_info_t)&info,
                                       &size);
        if( kerr == KERN_SUCCESS ) {
            a = info.resident_size;
        } else {
            a = 0;
        }
    }
    
    void iosNavigate(const char *url_)
    {
#if TARGET_OS_IPHONE
        NSURL *url = [NSURL URLWithString: [NSString stringWithUTF8String:url_]];
        [[UIApplication sharedApplication] openURL:url];
#endif
    }
}
