/*
 * pkcs11.so - the PKCS#11 module PJeOffice Pro loads for A3 tokens.
 *
 * PJeOffice finds its token driver through the PKCS11_DRIVER environment
 * variable, which the wrapper points at /app/lib/pkcs11, where this file is
 * installed as pkcs11.so. It hands every call to the runtime's
 * p11-kit-client.so, which talks to a p11-kit server on the host over
 * $XDG_RUNTIME_DIR/p11-kit/pkcs11: the token's own driver runs on the host,
 * where it and pcscd are installed, and the sandbox only sees the PKCS#11
 * calls.
 *
 * Three reasons this is a small module of its own rather than a symlink to
 * p11-kit-client.so:
 *
 * - PJeOffice calls C_Initialize without CKF_OS_LOCKING_OK and without mutex
 *   callbacks, and p11-kit-client.so refuses that with CKR_CANT_LOCK. When the
 *   caller supplies no mutex callbacks the standard lets the module use the
 *   operating system's locking primitives, so this sets CKF_OS_LOCKING_OK in
 *   that case and passes everything else through unchanged.
 * - C_GetSlotList hides p11-kit's trust slots ("System Trust", "Default
 *   Trust", model p11-kit-trust), which the host's server lists first and
 *   which hold no private key. PJeOffice (signer4j) keeps one device per
 *   token serial number, and the trust tokens' serial is "1": a token that
 *   also reports "1" (SerproID's cloud certificate does) was dropped as a
 *   duplicate of them. Assinador Serpro's bridge does the same.
 * - PJeOffice stores the canonical path of the driver it loaded in its
 *   configuration. A symlink would be saved as the runtime's versioned file
 *   name and break on the next runtime update; this file's path is its own.
 */
#include <dlfcn.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <p11-kit/pkcs11.h>

#ifndef CLIENT_MODULE
#error "CLIENT_MODULE must be set to the path of p11-kit-client.so"
#endif

#define TRUST_MODEL "p11-kit-trust"

static CK_FUNCTION_LIST bridged;
static CK_FUNCTION_LIST_PTR client;
static CK_C_Initialize client_initialize;

static CK_RV bridge_initialize(CK_VOID_PTR init_args)
{
    CK_C_INITIALIZE_ARGS args = { 0 };
    CK_C_INITIALIZE_ARGS_PTR in = init_args;

    if (in != NULL) {
        if (in->CreateMutex != NULL || in->DestroyMutex != NULL ||
            in->LockMutex != NULL || in->UnlockMutex != NULL)
            return client_initialize(init_args);
        args = *in;
    }
    args.flags |= CKF_OS_LOCKING_OK;
    return client_initialize(&args);
}

static int is_trust_token(CK_SLOT_ID slot)
{
    CK_TOKEN_INFO info;

    if (client->C_GetTokenInfo(slot, &info) != CKR_OK)
        return 0;
    return memcmp(info.model, TRUST_MODEL, strlen(TRUST_MODEL)) == 0;
}

static CK_RV bridge_get_slot_list(CK_BBOOL token_present, CK_SLOT_ID_PTR slots,
                                  CK_ULONG_PTR count)
{
    CK_SLOT_ID_PTR all;
    CK_ULONG total = 0;
    CK_ULONG visible = 0;
    CK_RV rv;

    if (count == NULL)
        return CKR_ARGUMENTS_BAD;

    rv = client->C_GetSlotList(token_present, NULL, &total);
    if (rv != CKR_OK)
        return rv;
    /* No second call for an empty list: p11-kit's RPC answers it with
     * CKR_BUFFER_TOO_SMALL. */
    if (total == 0) {
        *count = 0;
        return CKR_OK;
    }

    all = calloc(total, sizeof(*all));
    if (all == NULL)
        return CKR_HOST_MEMORY;
    rv = client->C_GetSlotList(token_present, all, &total);
    if (rv != CKR_OK) {
        free(all);
        return rv;
    }

    for (CK_ULONG i = 0; i < total; i++) {
        if (!is_trust_token(all[i]))
            all[visible++] = all[i];
    }

    if (slots != NULL) {
        if (*count < visible)
            rv = CKR_BUFFER_TOO_SMALL;
        else
            memcpy(slots, all, visible * sizeof(*all));
    }
    *count = visible;
    free(all);
    return rv;
}

CK_RV C_GetFunctionList(CK_FUNCTION_LIST_PTR_PTR list)
{
    static void *handle;
    CK_C_GetFunctionList get;
    CK_RV rv;

    if (list == NULL)
        return CKR_ARGUMENTS_BAD;
    if (handle == NULL) {
        handle = dlopen(CLIENT_MODULE, RTLD_NOW | RTLD_LOCAL);
        if (handle == NULL)
            return CKR_GENERAL_ERROR;
        get = (CK_C_GetFunctionList) dlsym(handle, "C_GetFunctionList");
        if (get == NULL)
            return CKR_GENERAL_ERROR;
        rv = get(&client);
        if (rv != CKR_OK)
            return rv;
        bridged = *client;
        client_initialize = client->C_Initialize;
        bridged.C_Initialize = bridge_initialize;
        bridged.C_GetSlotList = bridge_get_slot_list;
        bridged.C_GetFunctionList = C_GetFunctionList;
    }
    *list = &bridged;
    return CKR_OK;
}
