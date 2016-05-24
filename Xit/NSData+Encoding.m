#import "NSData+Encoding.h"

const unsigned int kEncodingCount = 7;
const TextEncoding kTextEncodings[kEncodingCount] = {
    kUnicodeUTF8Format,
    kUnicodeUTF16Format,
    kUnicodeUTF32Format,
    kUnicodeUTF16BEFormat,
    kUnicodeUTF16LEFormat,
    kUnicodeUTF32BEFormat,
    kUnicodeUTF32LEFormat,
    };

NSStringEncoding
TextEncodingToNSStringEncoding(TextEncoding encoding)
{
  const NSStringEncoding stringEncodings[kEncodingCount] = {
      NSUTF8StringEncoding,
      NSUTF16StringEncoding,
      NSUTF32StringEncoding,
      NSUTF16BigEndianStringEncoding,
      NSUTF16LittleEndianStringEncoding,
      NSUTF32BigEndianStringEncoding,
      NSUTF32LittleEndianStringEncoding,
      };
  
  for (unsigned int i = 0; i < kEncodingCount; ++i)
    if (kTextEncodings[i] == encoding)
      return stringEncodings[i];
  
  return 0;
}

@implementation NSData (Encoding)

-(NSStringEncoding)sniffTextEncoding
{
  TECSnifferObjectRef sniffer = NULL;
  NSStringEncoding result = 0;
  const ItemCount errorFeatureCount = self.length;
  
  TECCreateSniffer(&sniffer, kTextEncodings, kEncodingCount);
  if (sniffer != NULL) {
    TextEncoding encodings[kEncodingCount];
    ItemCount errors[kEncodingCount];
    ItemCount features[kEncodingCount];
    
    memcpy(encodings, kTextEncodings, sizeof(TextEncoding) * kEncodingCount);
    
    OSStatus err = TECSniffTextEncoding(
        sniffer, self.bytes, self.length,
        encodings, kEncodingCount,
        errors, errorFeatureCount,
        features, errorFeatureCount);
    
    if (err == noErr)
      result = TextEncodingToNSStringEncoding(encodings[0]);
    TECDisposeSniffer(sniffer);
  }
  return result;
}

@end
