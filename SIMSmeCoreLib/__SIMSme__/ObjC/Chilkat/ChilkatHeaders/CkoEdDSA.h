// Chilkat Objective-C header.
// This is a generated header file for Chilkat version 9.5.0.83

// Generic/internal class name =  EdDSA
// Wrapped Chilkat C++ class name =  CkEdDSA

@class CkoPrng;
@class CkoPrivateKey;
@class CkoPublicKey;
@class CkoBinData;


@interface CkoEdDSA : NSObject {

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
@property (nonatomic) BOOL VerboseLogging;
@property (nonatomic, readonly, copy) NSString *Version;
// method: GenEd25519Key
- (BOOL)GenEd25519Key: (CkoPrng *)prng 
	privKey: (CkoPrivateKey *)privKey;
// method: SaveLastError
- (BOOL)SaveLastError: (NSString *)path;
// method: SharedSecretENC
- (NSString *)SharedSecretENC: (CkoPrivateKey *)privkey 
	pubkey: (CkoPublicKey *)pubkey 
	encoding: (NSString *)encoding;
// method: SignBdENC
- (NSString *)SignBdENC: (CkoBinData *)bd 
	encoding: (NSString *)encoding 
	privkey: (CkoPrivateKey *)privkey;
// method: VerifyBdENC
- (BOOL)VerifyBdENC: (CkoBinData *)bd 
	encodedSig: (NSString *)encodedSig 
	enocding: (NSString *)enocding 
	pubkey: (CkoPublicKey *)pubkey;

@end
