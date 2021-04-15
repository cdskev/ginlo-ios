// Chilkat Objective-C header.
// This is a generated header file for Chilkat version 9.5.0.83

// Generic/internal class name =  JsonArray
// Wrapped Chilkat C++ class name =  CkJsonArray

@class CkoJsonObject;
@class CkoDateTime;
@class CkoDtObj;
@class CkoStringBuilder;


@interface CkoJsonArray : NSObject {

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
@property (nonatomic) BOOL EmitCompact;
@property (nonatomic) BOOL EmitCrlf;
@property (nonatomic, readonly, copy) NSString *LastErrorHtml;
@property (nonatomic, readonly, copy) NSString *LastErrorText;
@property (nonatomic, readonly, copy) NSString *LastErrorXml;
@property (nonatomic) BOOL LastMethodSuccess;
@property (nonatomic, readonly, copy) NSNumber *Size;
@property (nonatomic) BOOL VerboseLogging;
@property (nonatomic, readonly, copy) NSString *Version;
// method: AddArrayAt
- (BOOL)AddArrayAt: (NSNumber *)index;
// method: AddBoolAt
- (BOOL)AddBoolAt: (NSNumber *)index 
	value: (BOOL)value;
// method: AddIntAt
- (BOOL)AddIntAt: (NSNumber *)index 
	value: (NSNumber *)value;
// method: AddNullAt
- (BOOL)AddNullAt: (NSNumber *)index;
// method: AddNumberAt
- (BOOL)AddNumberAt: (NSNumber *)index 
	numericStr: (NSString *)numericStr;
// method: AddObjectAt
- (BOOL)AddObjectAt: (NSNumber *)index;
// method: AddObjectCopyAt
- (BOOL)AddObjectCopyAt: (NSNumber *)index 
	jsonObj: (CkoJsonObject *)jsonObj;
// method: AddStringAt
- (BOOL)AddStringAt: (NSNumber *)index 
	value: (NSString *)value;
// method: AppendArrayItems
- (BOOL)AppendArrayItems: (CkoJsonArray *)jarr;
// method: ArrayAt
- (CkoJsonArray *)ArrayAt: (NSNumber *)index;
// method: BoolAt
- (BOOL)BoolAt: (NSNumber *)index;
// method: Clear
- (void)Clear;
// method: DateAt
- (BOOL)DateAt: (NSNumber *)index 
	dateTime: (CkoDateTime *)dateTime;
// method: DeleteAt
- (BOOL)DeleteAt: (NSNumber *)index;
// method: DtAt
- (BOOL)DtAt: (NSNumber *)index 
	bLocal: (BOOL)bLocal 
	dt: (CkoDtObj *)dt;
// method: Emit
- (NSString *)Emit;
// method: EmitSb
- (BOOL)EmitSb: (CkoStringBuilder *)sb;
// method: FindObject
- (NSNumber *)FindObject: (NSString *)name 
	value: (NSString *)value 
	caseSensitive: (BOOL)caseSensitive;
// method: FindString
- (NSNumber *)FindString: (NSString *)value 
	caseSensitive: (BOOL)caseSensitive;
// method: IntAt
- (NSNumber *)IntAt: (NSNumber *)index;
// method: IsNullAt
- (BOOL)IsNullAt: (NSNumber *)index;
// method: Load
- (BOOL)Load: (NSString *)jsonArray;
// method: LoadSb
- (BOOL)LoadSb: (CkoStringBuilder *)sb;
// method: ObjectAt
- (CkoJsonObject *)ObjectAt: (NSNumber *)index;
// method: SaveLastError
- (BOOL)SaveLastError: (NSString *)path;
// method: SetBoolAt
- (BOOL)SetBoolAt: (NSNumber *)index 
	value: (BOOL)value;
// method: SetIntAt
- (BOOL)SetIntAt: (NSNumber *)index 
	value: (NSNumber *)value;
// method: SetNullAt
- (BOOL)SetNullAt: (NSNumber *)index;
// method: SetNumberAt
- (BOOL)SetNumberAt: (NSNumber *)index 
	value: (NSString *)value;
// method: SetStringAt
- (BOOL)SetStringAt: (NSNumber *)index 
	value: (NSString *)value;
// method: StringAt
- (NSString *)StringAt: (NSNumber *)index;
// method: Swap
- (BOOL)Swap: (NSNumber *)index1 
	index2: (NSNumber *)index2;
// method: TypeAt
- (NSNumber *)TypeAt: (NSNumber *)index;

@end
