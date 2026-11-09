/*
 * A PKCS#11 module for Certisign WebSigner: p11-kit's client
 * (p11-kit-client.so, in the browser's runtime) without the slots of
 * p11-kit's trust module ("System Trust", "Default Trust").
 *
 * Through p11-kit's client, the browser reaches the system's p11-kit server,
 * which serves Tessera's tokens and also the system's trust store: a token
 * of some 150 CA certificates, with no keys. Certisign's program (2.9.5,
 * from 2019) crashes (SIGSEGV) while listing that token's certificates,
 * before it reaches the real tokens. So it loads this module instead, under
 * the name its plugin asks for: every call goes straight to p11-kit's
 * client, except the slot list, which leaves out the trust module's slots
 * (found by their token's model, "p11-kit-trust").
 *
 * TESSERA_FILTER_MODULE names another module to wrap (for tests).
 */
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

#include <p11-kit/pkcs11.h>

#define CLIENT "/usr/lib/x86_64-linux-gnu/pkcs11/p11-kit-client.so"
#define TRUST_MODEL "p11-kit-trust"

static CK_FUNCTION_LIST_PTR real;
static CK_FUNCTION_LIST ours;

static int
is_trust_slot (CK_SLOT_ID slot)
{
	CK_TOKEN_INFO info;

	if (real->C_GetTokenInfo (slot, &info) != CKR_OK)
		return 0;
	return memcmp (info.model, TRUST_MODEL, strlen (TRUST_MODEL)) == 0;
}

static CK_RV
get_slot_list (CK_BBOOL token_present, CK_SLOT_ID_PTR list, CK_ULONG_PTR count)
{
	CK_ULONG n = 0, kept = 0, i;
	CK_SLOT_ID_PTR all;
	CK_RV rv;

	if (count == NULL)
		return CKR_ARGUMENTS_BAD;
	rv = real->C_GetSlotList (token_present, NULL, &n);
	if (rv != CKR_OK)
		return rv;
	/* An empty list is asked for no further: p11-kit's RPC answers
	 * CKR_BUFFER_TOO_SMALL to a zero-length buffer. */
	all = calloc (n ? n : 1, sizeof (CK_SLOT_ID));
	if (all == NULL)
		return CKR_HOST_MEMORY;
	if (n > 0) {
		rv = real->C_GetSlotList (token_present, all, &n);
		if (rv != CKR_OK) {
			free (all);
			return rv;
		}
	}
	for (i = 0; i < n; i++) {
		if (!is_trust_slot (all[i]))
			all[kept++] = all[i];
	}
	if (list == NULL) {
		*count = kept;
		rv = CKR_OK;
	} else if (*count < kept) {
		*count = kept;
		rv = CKR_BUFFER_TOO_SMALL;
	} else {
		memcpy (list, all, kept * sizeof (CK_SLOT_ID));
		*count = kept;
		rv = CKR_OK;
	}
	free (all);
	return rv;
}

CK_RV
C_GetFunctionList (CK_FUNCTION_LIST_PTR_PTR list)
{
	CK_C_GetFunctionList get;
	const char *path;
	void *module;
	CK_RV rv;

	if (list == NULL)
		return CKR_ARGUMENTS_BAD;
	if (real == NULL) {
		path = getenv ("TESSERA_FILTER_MODULE");
		module = dlopen (path && *path ? path : CLIENT, RTLD_NOW | RTLD_LOCAL);
		if (module == NULL)
			return CKR_GENERAL_ERROR;
		get = (CK_C_GetFunctionList) dlsym (module, "C_GetFunctionList");
		if (get == NULL)
			return CKR_GENERAL_ERROR;
		rv = get (&real);
		if (rv != CKR_OK)
			return rv;
		ours = *real;
		ours.version.major = 2;
		ours.version.minor = 40;
		ours.C_GetSlotList = get_slot_list;
	}
	*list = &ours;
	return CKR_OK;
}
