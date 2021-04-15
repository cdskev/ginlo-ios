// Chilkat Objective-C header.
// This is a generated header file for Chilkat version 9.5.0.83

// Generic/internal class name =  Pdf
// Wrapped Chilkat C++ class name =  CkPdf

@class CkoBinData;
@class CkoJsonObject;


@interface CkoPdf : NSObject {

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

@property (nonatomic, copy) NSString *DebugLogFilePath;
@property (nonatomic, readonly, copy) NSString *LastErrorHtml;
@property (nonatomic, readonly, copy) NSString *LastErrorText;
@property (nonatomic, readonly, copy) NSString *LastErrorXml;
@property (nonatomic) BOOL LastMethodSuccess;
@property (nonatomic, copy) NSString *LoadOwnerPassword;
@property (nonatomic, copy) NSString *LoadUserPassword;
@property (nonatomic, readonly, copy) NSNumber *NumSignatures;
@property (nonatomic, copy) NSString *UncommonOptions;
@property (nonatomic) BOOL VerboseLogging;
@property (nonatomic, readonly, copy) NSString *Version;
// method: LoadBd
- (BOOL)LoadBd: (CkoBinData *)pdfData;
// method: LoadFile
- (BOOL)LoadFile: (NSString *)filePath;
// method: SaveLastError
- (BOOL)SaveLastError: (NSString *)path;
// method: VerifySignature
- (BOOL)VerifySignature: (NSNumber *)index 
	sigInfo: (CkoJsonObject *)sigInfo;

@end
