// Chilkat Objective-C header.
// This is a generated header file for Chilkat version 9.5.0.83

// Generic/internal class name =  Pfx
// Wrapped Chilkat C++ class name =  CkPfx

@class CkoCert;
@class CkoPrivateKey;
@class CkoCertChain;
@class CkoJsonObject;
@class CkoJavaKeyStore;
@class CkoXmlCertVault;


@interface CkoPfx : NSObject {

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

@property (nonatomic, copy) NSString *AlgorithmId;
@property (nonatomic, copy) NSString *DebugLogFilePath;
@property (nonatomic, readonly, copy) NSString *LastErrorHtml;
@property (nonatomic, readonly, copy) NSString *LastErrorText;
@property (nonatomic, readonly, copy) NSString *LastErrorXml;
@property (nonatomic) BOOL LastMethodSuccess;
@property (nonatomic, readonly, copy) NSNumber *NumCerts;
@property (nonatomic, readonly, copy) NSNumber *NumPrivateKeys;
@property (nonatomic, copy) NSString *Pbes2CryptAlg;
@property (nonatomic, copy) NSString *Pbes2HmacAlg;
@property (nonatomic, copy) NSString *UncommonOptions;
@property (nonatomic) BOOL VerboseLogging;
@property (nonatomic, readonly, copy) NSString *Version;
// method: AddCert
- (BOOL)AddCert: (CkoCert *)cert 
	includeChain: (BOOL)includeChain;
// method: AddPrivateKey
- (BOOL)AddPrivateKey: (CkoPrivateKey *)privKey 
	certChain: (CkoCertChain *)certChain;
// method: FindCertByLocalKeyId
- (CkoCert *)FindCertByLocalKeyId: (NSString *)localKeyId 
	encoding: (NSString *)encoding;
// method: GetCert
- (CkoCert *)GetCert: (NSNumber *)index;
// method: GetPrivateKey
- (CkoPrivateKey *)GetPrivateKey: (NSNumber *)index;
// method: GetSafeBagAttr
- (NSString *)GetSafeBagAttr: (BOOL)forPrivateKey 
	index: (NSNumber *)index 
	attrName: (NSString *)attrName;
// method: LastJsonData
- (CkoJsonObject *)LastJsonData;
// method: LoadPem
- (BOOL)LoadPem: (NSString *)pemStr 
	password: (NSString *)password;
// method: LoadPfxBytes
- (BOOL)LoadPfxBytes: (NSData *)pfxData 
	password: (NSString *)password;
// method: LoadPfxEncoded
- (BOOL)LoadPfxEncoded: (NSString *)encodedData 
	encoding: (NSString *)encoding 
	password: (NSString *)password;
// method: LoadPfxFile
- (BOOL)LoadPfxFile: (NSString *)path 
	password: (NSString *)password;
// method: SaveLastError
- (BOOL)SaveLastError: (NSString *)path;
// method: SetSafeBagAttr
- (BOOL)SetSafeBagAttr: (BOOL)forPrivateKey 
	index: (NSNumber *)index 
	name: (NSString *)name 
	value: (NSString *)value 
	encoding: (NSString *)encoding;
// method: ToBinary
- (NSData *)ToBinary: (NSString *)password;
// method: ToEncodedString
- (NSString *)ToEncodedString: (NSString *)password 
	encoding: (NSString *)encoding;
// method: ToFile
- (BOOL)ToFile: (NSString *)password 
	path: (NSString *)path;
// method: ToJavaKeyStore
- (CkoJavaKeyStore *)ToJavaKeyStore: (NSString *)alias 
	password: (NSString *)password;
// method: ToPem
- (NSString *)ToPem;
// method: ToPemEx
- (NSString *)ToPemEx: (BOOL)extendedAttrs 
	noKeys: (BOOL)noKeys 
	noCerts: (BOOL)noCerts 
	noCaCerts: (BOOL)noCaCerts 
	encryptAlg: (NSString *)encryptAlg 
	password: (NSString *)password;
// method: UseCertVault
- (BOOL)UseCertVault: (CkoXmlCertVault *)vault;

@end
