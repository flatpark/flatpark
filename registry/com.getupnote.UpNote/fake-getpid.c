#define _GNU_SOURCE

#include <dlfcn.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

/* This library is already mapped into the process by the time the constructor
 * runs, so the getpid() interposition below stays in effect for the whole
 * process lifetime. Drop LD_PRELOAD from the environment now so it is not
 * inherited by plain children: xdg-open and other GLib/GDBus helpers send
 * getpid() to the session bus as a kernel-checked SCM_CREDENTIALS credential,
 * and a spoofed value there is rejected with EPERM, which would break opening
 * a link in the browser. Chromium's own child processes are unaffected: zypak
 * spawns them through zypak-helper, which rebuilds LD_PRELOAD from
 * ZYPAK_LD_PRELOAD. The tray backend in the browser process still sees the
 * fixed PID. */
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
    const char *value = getenv("UPNOTE_FAKE_PID");
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

/* A spoofed getpid() must not reach the kernel as a credential. GLib's GDBus -
 * which GTK uses for the settings portal, and which xdg-open and other helpers
 * use for the session bus - authenticates by sending SCM_CREDENTIALS built from
 * getpid(); the kernel checks that field against the real process and refuses
 * the whole message with EPERM when it does not match, so the portal call fails
 * with "Error sending credentials". Put the real PID back into any credentials
 * on their way out. Chromium's own tray code reads getpid() directly and still
 * sees the fixed value, which is all the bus name needs. */
ssize_t sendmsg(int fd, const struct msghdr *msg, int flags)
{
    static ssize_t (*real_sendmsg)(int, const struct msghdr *, int);
    struct msghdr *m = (struct msghdr *)msg;
    struct cmsghdr *cmsg;

    if (real_sendmsg == NULL)
        real_sendmsg = dlsym(RTLD_NEXT, "sendmsg");

    if (m != NULL && m->msg_control != NULL && m->msg_controllen > 0) {
        for (cmsg = CMSG_FIRSTHDR(m); cmsg != NULL; cmsg = CMSG_NXTHDR(m, cmsg)) {
            struct ucred cred;

            if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_CREDENTIALS)
                continue;
            if (cmsg->cmsg_len < CMSG_LEN(sizeof(cred)))
                continue;

            memcpy(&cred, CMSG_DATA(cmsg), sizeof(cred));
            cred.pid = real_getpid_value();
            memcpy(CMSG_DATA(cmsg), &cred, sizeof(cred));
        }
    }

    return real_sendmsg(fd, msg, flags);
}
