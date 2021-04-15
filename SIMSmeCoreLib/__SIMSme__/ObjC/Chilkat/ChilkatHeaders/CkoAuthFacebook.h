// Chilkat Objective-C header.
// This is a generated header file for Chilkat version 9.5.0.58

// Generic/internal class name =  AuthFacebook
// Wrapped Chilkat C++ class name =  CkAuthFacebook



@interface CkoAuthFacebook : NSObject {

	@private
		void *m_obj;

}

- (id)init;
- (void)dealloc;
- (void)dispose;
- (NSString *)stringWithUtf8: (const char *)s;
- (void *)CppImplObj;
- (void)setCppImplObj: (void *)pObj;

- (void)clearCppImplObj;

@property (nonatomic, copy) NSString *AppId;

@property (nonatomic, copy) NSString *AppSecret;

@property (nonatomic, copy) NSString *DebugLogFilePath;

@property (nonatomic, readonly, copy) NSString *LastErrorHtml;
@property (nonatomic, readonly, copy) NSString *LastErrorText;
@property (nonatomic, readonly, copy) NSString *LastErrorXml;
@property (nonatomic) BOOL LastMethodSuccess;

@property (nonatomic) BOOL VerboseLogging;

@property (nonatomic, readonly, copy) NSString *Version;
// method: SaveLastError
- (BOOL)SaveLastError: (NSString *)path;

@end
