/*
 * local-hostname.so: resolves assinador-desktop.serpro.gov.br to 127.0.0.1
 * inside the sandbox.
 *
 * The signer opens its local server on this name, which is not in public DNS:
 * the native installer adds it to /etc/hosts, which a sandboxed app cannot do.
 * Only this name is answered here; every other one goes to the C library.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <netdb.h>
#include <string.h>

#define LOCAL_NAME "assinador-desktop.serpro.gov.br"
#define LOCAL_ADDRESS "127.0.0.1"

int getaddrinfo(const char *name, const char *service,
                const struct addrinfo *hints, struct addrinfo **result)
{
    int (*original)(const char *, const char *, const struct addrinfo *,
                    struct addrinfo **);

    *(void **)&original = dlsym(RTLD_NEXT, "getaddrinfo");
    if (original == NULL)
        return EAI_SYSTEM;
    if (name != NULL && strcmp(name, LOCAL_NAME) == 0)
        name = LOCAL_ADDRESS;
    return original(name, service, hints, result);
}
