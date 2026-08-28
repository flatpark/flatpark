#define _GNU_SOURCE

#include <dlfcn.h>
#include <limits.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

/* This library is already mapped into the fastpotify process by the time the
 * constructor runs, so the getpid() interposition below stays in effect for the
 * whole process lifetime. Drop LD_PRELOAD from the environment now so it is not
 * inherited by children: xdg-open and other GLib/GDBus helpers send getpid() to
 * the session bus as a kernel-checked SCM_CREDENTIALS credential, and a spoofed
 * value there is rejected with EPERM, which would break the OAuth browser
 * launch. The tray backend inside fastpotify still sees the fixed PID. */
__attribute__((constructor))
static void drop_ld_preload(void)
{
    unsetenv("LD_PRELOAD");
}

static pid_t real_getpid_value(void)
{
    static pid_t (*real_getpid)(void);

    if (real_getpid == NULL)
        real_getpid = dlsym(RTLD_NEXT, "getpid");

    if (real_getpid != NULL)
        return real_getpid();

    return (pid_t)syscall(SYS_getpid);
}

pid_t getpid(void)
{
    const char *value = getenv("FASTPOTIFY_FAKE_PID");
    char *end = NULL;
    long parsed;

    if (value == NULL || *value == '\0')
        return real_getpid_value();

    parsed = strtol(value, &end, 10);
    if (end == value || *end != '\0' || parsed <= 1 || parsed > INT_MAX)
        return real_getpid_value();

    return (pid_t)parsed;
}

pid_t __getpid(void)
{
    return getpid();
}
