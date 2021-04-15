// This is a generated source file for Chilkat version 9.5.0.83
#ifndef _C_CkSpider_H
#define _C_CkSpider_H
#include "chilkatDefs.h"

#include "Chilkat_C.h"


CK_C_VISIBLE_PUBLIC void CkSpider_setAbortCheck(HCkSpider cHandle, BOOL (*fnAbortCheck)(void));
CK_C_VISIBLE_PUBLIC void CkSpider_setPercentDone(HCkSpider cHandle, BOOL (*fnPercentDone)(int pctDone));
CK_C_VISIBLE_PUBLIC void CkSpider_setProgressInfo(HCkSpider cHandle, void (*fnProgressInfo)(const char *name, const char *value));
CK_C_VISIBLE_PUBLIC void CkSpider_setTaskCompleted(HCkSpider cHandle, void (*fnTaskCompleted)(HCkTask hTask));

CK_C_VISIBLE_PUBLIC void CkSpider_setAbortCheck2(HCkSpider cHandle, BOOL (*fnAbortCheck2)(void *pContext));
CK_C_VISIBLE_PUBLIC void CkSpider_setPercentDone2(HCkSpider cHandle, BOOL (*fnPercentDone2)(int pctDone, void *pContext));
CK_C_VISIBLE_PUBLIC void CkSpider_setProgressInfo2(HCkSpider cHandle, void (*fnProgressInfo2)(const char *name, const char *value, void *pContext));
CK_C_VISIBLE_PUBLIC void CkSpider_setTaskCompleted2(HCkSpider cHandle, void (*fnTaskCompleted2)(HCkTask hTask, void *pContext));

// setExternalProgress is for C callback functions defined in the external programming language (such as Go)
CK_C_VISIBLE_PUBLIC void CkSpider_setExternalProgress(HCkSpider cHandle, BOOL on);
CK_C_VISIBLE_PUBLIC void CkSpider_setCallbackContext(HCkSpider cHandle, void *pContext);

CK_C_VISIBLE_PUBLIC HCkSpider CkSpider_Create(void);
CK_C_VISIBLE_PUBLIC void CkSpider_Dispose(HCkSpider handle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getAbortCurrent(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putAbortCurrent(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getAvoidHttps(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putAvoidHttps(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_getCacheDir(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC void CkSpider_putCacheDir(HCkSpider cHandle, const char *newVal);
CK_C_VISIBLE_PUBLIC const char *CkSpider_cacheDir(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getChopAtQuery(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putChopAtQuery(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC int CkSpider_getConnectTimeout(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putConnectTimeout(HCkSpider cHandle, int newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_getDebugLogFilePath(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC void CkSpider_putDebugLogFilePath(HCkSpider cHandle, const char *newVal);
CK_C_VISIBLE_PUBLIC const char *CkSpider_debugLogFilePath(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getDomain(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_domain(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getFetchFromCache(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putFetchFromCache(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC int CkSpider_getHeartbeatMs(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putHeartbeatMs(HCkSpider cHandle, int newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastErrorHtml(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastErrorHtml(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastErrorText(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastErrorText(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastErrorXml(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastErrorXml(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getLastFromCache(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastHtml(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastHtml(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastHtmlDescription(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastHtmlDescription(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastHtmlKeywords(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastHtmlKeywords(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastHtmlTitle(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastHtmlTitle(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getLastMethodSuccess(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putLastMethodSuccess(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastModDate(HCkSpider cHandle, SYSTEMTIME * retval);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastModDateStr(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastModDateStr(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getLastUrl(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_lastUrl(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC int CkSpider_getMaxResponseSize(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putMaxResponseSize(HCkSpider cHandle, int newVal);
CK_C_VISIBLE_PUBLIC int CkSpider_getMaxUrlLen(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putMaxUrlLen(HCkSpider cHandle, int newVal);
CK_C_VISIBLE_PUBLIC int CkSpider_getNumAvoidPatterns(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC int CkSpider_getNumFailed(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC int CkSpider_getNumOutboundLinks(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC int CkSpider_getNumSpidered(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC int CkSpider_getNumUnspidered(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getPreferIpv6(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putPreferIpv6(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_getProxyDomain(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC void CkSpider_putProxyDomain(HCkSpider cHandle, const char *newVal);
CK_C_VISIBLE_PUBLIC const char *CkSpider_proxyDomain(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getProxyLogin(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC void CkSpider_putProxyLogin(HCkSpider cHandle, const char *newVal);
CK_C_VISIBLE_PUBLIC const char *CkSpider_proxyLogin(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_getProxyPassword(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC void CkSpider_putProxyPassword(HCkSpider cHandle, const char *newVal);
CK_C_VISIBLE_PUBLIC const char *CkSpider_proxyPassword(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC int CkSpider_getProxyPort(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putProxyPort(HCkSpider cHandle, int newVal);
CK_C_VISIBLE_PUBLIC int CkSpider_getReadTimeout(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putReadTimeout(HCkSpider cHandle, int newVal);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getUpdateCache(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putUpdateCache(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_getUserAgent(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC void CkSpider_putUserAgent(HCkSpider cHandle, const char *newVal);
CK_C_VISIBLE_PUBLIC const char *CkSpider_userAgent(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getUtf8(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putUtf8(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_getVerboseLogging(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putVerboseLogging(HCkSpider cHandle, BOOL newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_getVersion(HCkSpider cHandle, HCkString retval);
CK_C_VISIBLE_PUBLIC const char *CkSpider_version(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC int CkSpider_getWindDownCount(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_putWindDownCount(HCkSpider cHandle, int newVal);
CK_C_VISIBLE_PUBLIC void CkSpider_AddAvoidOutboundLinkPattern(HCkSpider cHandle, const char *pattern);
CK_C_VISIBLE_PUBLIC void CkSpider_AddAvoidPattern(HCkSpider cHandle, const char *pattern);
CK_C_VISIBLE_PUBLIC void CkSpider_AddMustMatchPattern(HCkSpider cHandle, const char *pattern);
CK_C_VISIBLE_PUBLIC void CkSpider_AddUnspidered(HCkSpider cHandle, const char *url);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_CanonicalizeUrl(HCkSpider cHandle, const char *url, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_canonicalizeUrl(HCkSpider cHandle, const char *url);
CK_C_VISIBLE_PUBLIC void CkSpider_ClearFailedUrls(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_ClearOutboundLinks(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC void CkSpider_ClearSpideredUrls(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_CrawlNext(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC HCkTask CkSpider_CrawlNextAsync(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_FetchRobotsText(HCkSpider cHandle, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_fetchRobotsText(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC HCkTask CkSpider_FetchRobotsTextAsync(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_GetAvoidPattern(HCkSpider cHandle, int index, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_getAvoidPattern(HCkSpider cHandle, int index);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_GetBaseDomain(HCkSpider cHandle, const char *domain, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_getBaseDomain(HCkSpider cHandle, const char *domain);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_GetFailedUrl(HCkSpider cHandle, int index, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_getFailedUrl(HCkSpider cHandle, int index);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_GetOutboundLink(HCkSpider cHandle, int index, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_getOutboundLink(HCkSpider cHandle, int index);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_GetSpideredUrl(HCkSpider cHandle, int index, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_getSpideredUrl(HCkSpider cHandle, int index);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_GetUnspideredUrl(HCkSpider cHandle, int index, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_getUnspideredUrl(HCkSpider cHandle, int index);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_GetUrlDomain(HCkSpider cHandle, const char *url, HCkString outStr);
CK_C_VISIBLE_PUBLIC const char *CkSpider_getUrlDomain(HCkSpider cHandle, const char *url);
CK_C_VISIBLE_PUBLIC void CkSpider_Initialize(HCkSpider cHandle, const char *domain);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_LoadTaskCaller(HCkSpider cHandle, HCkTask task);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_RecrawlLast(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC HCkTask CkSpider_RecrawlLastAsync(HCkSpider cHandle);
CK_C_VISIBLE_PUBLIC BOOL CkSpider_SaveLastError(HCkSpider cHandle, const char *path);
CK_C_VISIBLE_PUBLIC void CkSpider_SkipUnspidered(HCkSpider cHandle, int index);
CK_C_VISIBLE_PUBLIC void CkSpider_SleepMs(HCkSpider cHandle, int numMilliseconds);
#endif
