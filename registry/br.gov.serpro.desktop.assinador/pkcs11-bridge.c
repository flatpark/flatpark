/*
 * pkcs11-bridge.so: the PKCS#11 module Assinador Serpro loads for A3 tokens.
 *
 * Everything goes to the runtime's p11-kit-client.so, which talks to the user's
 * p11-kit server over $XDG_RUNTIME_DIR/p11-kit/pkcs11, the same path PJeOffice
 * Pro uses. A plain symlink to the client is not enough, because three calls
 * are adjusted here.
 *
 * C_GetSlotList: the app configures SunPKCS11 with "name" and "library" and no
 * "slot", so SunPKCS11 uses the first slot with a token. On this socket the
 * first ones are p11-kit-trust's (System Trust and Default Trust), which hold
 * no private key, so they are hidden.
 *
 * C_Initialize: the app's device listing calls it without CKF_OS_LOCKING_OK,
 * which p11-kit's RPC client requires. The client is multithreaded either way,
 * so the flag is added here.
 *
 * C_FindObjectsInit: the same listing passes CKA_TOKEN as an 8-byte value.
 * p11-kit's RPC checks the size of this 1-byte boolean, so it is converted here.
 */
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

#include <p11-kit/pkcs11.h>

#ifndef CLIENT_MODULE
#error "define CLIENT_MODULE as the path of p11-kit-client.so"
#endif

#define TRUST_MODEL "p11-kit-trust"

static CK_FUNCTION_LIST *client;
static CK_FUNCTION_LIST functions;

static int is_trust_token(CK_SLOT_ID slot)
{
    CK_TOKEN_INFO info;

    if (client->C_GetTokenInfo(slot, &info) != CKR_OK)
        return 0;
    return memcmp(info.model, TRUST_MODEL, strlen(TRUST_MODEL)) == 0;
}

static CK_RV initialize(void *args)
{
    CK_C_INITIALIZE_ARGS copy;

    if (args == NULL)
        return client->C_Initialize(NULL);

    copy = *(CK_C_INITIALIZE_ARGS *)args;
    copy.flags |= CKF_OS_LOCKING_OK;
    return client->C_Initialize(&copy);
}

static CK_RV find_objects_init(CK_SESSION_HANDLE session, CK_ATTRIBUTE *template,
                               CK_ULONG count)
{
    if (count == 1 && template[0].type == CKA_TOKEN
        && template[0].ulValueLen == sizeof(CK_ULONG)) {
        CK_BBOOL value = *(CK_ULONG *)template[0].pValue != 0;
        CK_ATTRIBUTE converted = { CKA_TOKEN, &value, sizeof(value) };

        return client->C_FindObjectsInit(session, &converted, 1);
    }
    return client->C_FindObjectsInit(session, template, count);
}

static CK_RV get_slot_list(CK_BBOOL token_present, CK_SLOT_ID *slots, CK_ULONG *count)
{
    CK_SLOT_ID *all;
    CK_ULONG total = 0;
    CK_ULONG visible = 0;
    CK_RV rv;

    if (count == NULL)
        return CKR_ARGUMENTS_BAD;

    rv = client->C_GetSlotList(token_present, NULL, &total);
    if (rv != CKR_OK)
        return rv;

    all = calloc(total ? total : 1, sizeof(*all));
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

/*
 * Only C_GetFunctionList is exported: without C_GetInterface SunPKCS11 uses the
 * 2.x list, and the version is fixed at 2.40 so nothing looks for the 3.0
 * functions past the end of this structure.
 */
CK_RV C_GetFunctionList(CK_FUNCTION_LIST **list)
{
    if (list == NULL)
        return CKR_ARGUMENTS_BAD;

    if (client == NULL) {
        CK_RV (*get_list)(CK_FUNCTION_LIST **);
        void *module = dlopen(CLIENT_MODULE, RTLD_NOW | RTLD_LOCAL);
        CK_RV rv;

        if (module == NULL)
            return CKR_GENERAL_ERROR;
        *(void **)&get_list = dlsym(module, "C_GetFunctionList");
        if (get_list == NULL)
            return CKR_GENERAL_ERROR;
        rv = get_list(&client);
        if (rv != CKR_OK)
            return rv;

        functions = *client;
        functions.version.major = 2;
        functions.version.minor = 40;
        functions.C_Initialize = initialize;
        functions.C_GetSlotList = get_slot_list;
        functions.C_FindObjectsInit = find_objects_init;
    }

    *list = &functions;
    return CKR_OK;
}
