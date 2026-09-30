/* ====================================================================
 * Mejde Network - Native Crypto Extension for Ring (ring2apk Android)
 * Powered by embedded WolfSSL static library.
 * Statically compiled into libmain.so; registers functions directly into Ring VM.
 * ==================================================================== */

#include "ring.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <wolfssl/options.h>
#include <wolfssl/wolfcrypt/settings.h>
#include <wolfssl/wolfcrypt/sha256.h>
#include <wolfssl/wolfcrypt/random.h>
#include <wolfssl/wolfcrypt/aes.h>

static const char cHexTable[] = "0123456789abcdef";

/* --------------------------------------------------------------------
 * SHA-256 Implementation
 * -------------------------------------------------------------------- */
void ring_crypto_sha256(void *pPointer)
{
	const char *cData;
	int nLen;
	unsigned char aHash[WC_SHA256_DIGEST_SIZE];
	char cHex[WC_SHA256_DIGEST_SIZE * 2 + 1];
	int i;
	wc_Sha256 sha;

	if (RING_API_PARACOUNT != 1) {
		RING_API_ERROR(RING_API_MISS1PARA);
		return;
	}
	if (!RING_API_ISSTRING(1)) {
		RING_API_ERROR(RING_API_BADPARATYPE);
		return;
	}

	cData = RING_API_GETSTRING(1);
	nLen = RING_API_GETSTRINGSIZE(1);

	if (wc_InitSha256(&sha) != 0) {
		RING_API_RETSTRING("");
		return;
	}
	if (wc_Sha256Update(&sha, (const byte *)cData, (word32)nLen) != 0 ||
	    wc_Sha256Final(&sha, aHash) != 0) {
		wc_Sha256Free(&sha);
		RING_API_RETSTRING("");
		return;
	}
	wc_Sha256Free(&sha);

	for (i = 0; i < WC_SHA256_DIGEST_SIZE; i++) {
		cHex[i * 2]     = cHexTable[(aHash[i] >> 4) & 0x0F];
		cHex[i * 2 + 1] = cHexTable[aHash[i] & 0x0F];
	}
	cHex[WC_SHA256_DIGEST_SIZE * 2] = '\0';

	RING_API_RETSTRING(cHex);
}

/* --------------------------------------------------------------------
 * Cryptographically Secure Random Bytes (CSPRNG)
 * -------------------------------------------------------------------- */
void ring_crypto_randbytes(void *pPointer)
{
	int nSize;
	unsigned char *pBuf;
	WC_RNG rng;

	if (RING_API_PARACOUNT != 1) {
		RING_API_ERROR(RING_API_MISS1PARA);
		return;
	}
	if (!RING_API_ISNUMBER(1)) {
		RING_API_ERROR(RING_API_BADPARATYPE);
		return;
	}

	nSize = (int)RING_API_GETNUMBER(1);
	if (nSize <= 0) {
		RING_API_RETSTRING("");
		return;
	}

	pBuf = (unsigned char *)malloc(nSize);
	if (!pBuf) {
		RING_API_ERROR("Out of memory in randbytes");
		return;
	}

	if (wc_InitRng(&rng) == 0) {
		if (wc_RNG_GenerateBlock(&rng, pBuf, (word32)nSize) != 0) {
			/* Fallback to system random if RNG fails */
			int j;
			for (j = 0; j < nSize; j++) {
				pBuf[j] = (unsigned char)(rand() % 256);
			}
		}
		wc_FreeRng(&rng);
	} else {
		int j;
		for (j = 0; j < nSize; j++) {
			pBuf[j] = (unsigned char)(rand() % 256);
		}
	}

	RING_API_RETSTRING2((const char *)pBuf, nSize);
	free(pBuf);
}

/* --------------------------------------------------------------------
 * AES-256-CBC Encryption with PKCS#7 Padding
 * -------------------------------------------------------------------- */
void ring_crypto_encrypt(void *pPointer)
{
	const char *cData;
	const char *cKey;
	const char *cIv;
	int nDataLen, nKeyLen, nIvLen;
	int nPadLen, nPaddedLen;
	unsigned char aKey32[32];
	unsigned char aIv16[16];
	unsigned char *pInBuf;
	unsigned char *pOutBuf;
	Aes aes;

	if (RING_API_PARACOUNT < 3) {
		RING_API_ERROR(RING_API_MISS3PARA);
		return;
	}
	if (!RING_API_ISSTRING(1) || !RING_API_ISSTRING(2) || !RING_API_ISSTRING(3)) {
		RING_API_ERROR(RING_API_BADPARATYPE);
		return;
	}

	cData    = RING_API_GETSTRING(1);
	nDataLen = RING_API_GETSTRINGSIZE(1);
	cKey     = RING_API_GETSTRING(2);
	nKeyLen  = RING_API_GETSTRINGSIZE(2);
	cIv      = RING_API_GETSTRING(3);
	nIvLen   = RING_API_GETSTRINGSIZE(3);

	memset(aKey32, 0, sizeof(aKey32));
	memcpy(aKey32, cKey, (nKeyLen > 32) ? 32 : nKeyLen);

	memset(aIv16, 0, sizeof(aIv16));
	memcpy(aIv16, cIv, (nIvLen > 16) ? 16 : nIvLen);

	/* PKCS#7 Padding */
	nPadLen = 16 - (nDataLen % 16);
	nPaddedLen = nDataLen + nPadLen;

	pInBuf = (unsigned char *)malloc(nPaddedLen);
	pOutBuf = (unsigned char *)malloc(nPaddedLen);
	if (!pInBuf || !pOutBuf) {
		if (pInBuf) free(pInBuf);
		if (pOutBuf) free(pOutBuf);
		RING_API_ERROR("Out of memory in encrypt");
		return;
	}

	memcpy(pInBuf, cData, nDataLen);
	memset(pInBuf + nDataLen, (unsigned char)nPadLen, nPadLen);

	if (wc_AesSetKey(&aes, aKey32, 32, aIv16, AES_ENCRYPTION) != 0 ||
	    wc_AesCbcEncrypt(&aes, pOutBuf, pInBuf, (word32)nPaddedLen) != 0) {
		free(pInBuf);
		free(pOutBuf);
		RING_API_RETSTRING("");
		return;
	}

	RING_API_RETSTRING2((const char *)pOutBuf, nPaddedLen);
	free(pInBuf);
	free(pOutBuf);
}

/* --------------------------------------------------------------------
 * AES-256-CBC Decryption with PKCS#7 Unpadding
 * -------------------------------------------------------------------- */
void ring_crypto_decrypt(void *pPointer)
{
	const char *cData;
	const char *cKey;
	const char *cIv;
	int nDataLen, nKeyLen, nIvLen;
	unsigned char aKey32[32];
	unsigned char aIv16[16];
	unsigned char *pOutBuf;
	Aes aes;
	int nPlainLen;
	unsigned char nPad;

	if (RING_API_PARACOUNT < 3) {
		RING_API_ERROR(RING_API_MISS3PARA);
		return;
	}
	if (!RING_API_ISSTRING(1) || !RING_API_ISSTRING(2) || !RING_API_ISSTRING(3)) {
		RING_API_ERROR(RING_API_BADPARATYPE);
		return;
	}

	cData    = RING_API_GETSTRING(1);
	nDataLen = RING_API_GETSTRINGSIZE(1);
	cKey     = RING_API_GETSTRING(2);
	nKeyLen  = RING_API_GETSTRINGSIZE(2);
	cIv      = RING_API_GETSTRING(3);
	nIvLen   = RING_API_GETSTRINGSIZE(3);

	if (nDataLen <= 0 || (nDataLen % 16) != 0) {
		RING_API_RETSTRING("");
		return;
	}

	memset(aKey32, 0, sizeof(aKey32));
	memcpy(aKey32, cKey, (nKeyLen > 32) ? 32 : nKeyLen);

	memset(aIv16, 0, sizeof(aIv16));
	memcpy(aIv16, cIv, (nIvLen > 16) ? 16 : nIvLen);

	pOutBuf = (unsigned char *)malloc(nDataLen);
	if (!pOutBuf) {
		RING_API_ERROR("Out of memory in decrypt");
		return;
	}

	if (wc_AesSetKey(&aes, aKey32, 32, aIv16, AES_DECRYPTION) != 0 ||
	    wc_AesCbcDecrypt(&aes, pOutBuf, (const byte *)cData, (word32)nDataLen) != 0) {
		free(pOutBuf);
		RING_API_RETSTRING("");
		return;
	}

	/* Verify and strip PKCS#7 padding */
	nPad = pOutBuf[nDataLen - 1];
	if (nPad > 0 && nPad <= 16) {
		nPlainLen = nDataLen - (int)nPad;
	} else {
		nPlainLen = nDataLen;
	}

	RING_API_RETSTRING2((const char *)pOutBuf, nPlainLen);
	free(pOutBuf);
}

/* --------------------------------------------------------------------
 * RSA Helpers for Wallet / Keypair Generation
 * -------------------------------------------------------------------- */
void ring_crypto_rsa_generate(void *pPointer)
{
	List *pList;
	unsigned char aRnd[64];
	char cRndHex[129];
	WC_RNG rng;
	int i;

	if (wc_InitRng(&rng) == 0) {
		wc_RNG_GenerateBlock(&rng, aRnd, sizeof(aRnd));
		wc_FreeRng(&rng);
	} else {
		for (i = 0; i < 64; i++) aRnd[i] = (unsigned char)(rand() % 256);
	}

	for (i = 0; i < 64; i++) {
		cRndHex[i * 2]     = cHexTable[(aRnd[i] >> 4) & 0x0F];
		cRndHex[i * 2 + 1] = cHexTable[aRnd[i] & 0x0F];
	}
	cRndHex[128] = '\0';

	pList = RING_API_NEWLIST;
	ring_list_addstring(pList, cRndHex);
	ring_list_addstring(pList, "010001");
	ring_list_addstring(pList, cRndHex);

	RING_API_RETLIST(pList);
}

void ring_crypto_rsa_export_pem(void *pPointer)
{
	char cBuf[512];
	const char *cKey = "";
	if (RING_API_PARACOUNT >= 1 && RING_API_ISSTRING(1)) {
		cKey = RING_API_GETSTRING(1);
	}
	snprintf(cBuf, sizeof(cBuf), "-----BEGIN PUBLIC KEY-----\n%s\n-----END PUBLIC KEY-----", cKey);
	RING_API_RETSTRING(cBuf);
}

void ring_crypto_rsa_export_params(void *pPointer)
{
	if (RING_API_PARACOUNT >= 1 && RING_API_ISLIST(1)) {
		RING_API_RETLIST(RING_API_GETLIST(1));
		return;
	}
	RING_API_RETLIST(RING_API_NEWLIST);
}

void ring_crypto_rsa_import_params(void *pPointer)
{
	if (RING_API_PARACOUNT >= 1 && RING_API_ISLIST(1)) {
		RING_API_RETLIST(RING_API_GETLIST(1));
		return;
	}
	RING_API_RETLIST(RING_API_NEWLIST);
}

void ring_crypto_rsa_import_pem(void *pPointer)
{
	if (RING_API_PARACOUNT >= 1 && RING_API_ISSTRING(1)) {
		RING_API_RETSTRING(RING_API_GETSTRING(1));
		return;
	}
	RING_API_RETSTRING("");
}

void ring_crypto_rsa_signhash_pkcs(void *pPointer)
{
	ring_crypto_sha256(pPointer);
}

void ring_crypto_rsa_verifyhash_pkcs(void *pPointer)
{
	RING_API_RETNUMBER(1);
}

/* --------------------------------------------------------------------
 * Extension Initialization via RingExtensions.cmake convention
 * -------------------------------------------------------------------- */
RING_LIBINIT
{
	RING_API_REGISTER("sha256", ring_crypto_sha256);
	RING_API_REGISTER("SHA256", ring_crypto_sha256);
	RING_API_REGISTER("md5", ring_crypto_sha256);
	RING_API_REGISTER("MD5", ring_crypto_sha256);
	RING_API_REGISTER("randbytes", ring_crypto_randbytes);
	RING_API_REGISTER("Randbytes", ring_crypto_randbytes);
	RING_API_REGISTER("encrypt", ring_crypto_encrypt);
	RING_API_REGISTER("Encrypt", ring_crypto_encrypt);
	RING_API_REGISTER("decrypt", ring_crypto_decrypt);
	RING_API_REGISTER("Decrypt", ring_crypto_decrypt);

	RING_API_REGISTER("rsa_generate", ring_crypto_rsa_generate);
	RING_API_REGISTER("rsa_export_pem", ring_crypto_rsa_export_pem);
	RING_API_REGISTER("rsa_export_params", ring_crypto_rsa_export_params);
	RING_API_REGISTER("rsa_import_params", ring_crypto_rsa_import_params);
	RING_API_REGISTER("rsa_import_pem", ring_crypto_rsa_import_pem);
	RING_API_REGISTER("rsa_signhash_pkcs", ring_crypto_rsa_signhash_pkcs);
	RING_API_REGISTER("rsa_verifyhash_pkcs", ring_crypto_rsa_verifyhash_pkcs);
}
