#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

/*
 * Why this shim exists
 * --------------------
 * The tray_manager Flutter plugin builds its StatusNotifierItem bus name as
 * "org.kde.StatusNotifierItem-<getpid()>-1", owns it, and hands that same
 * string to the host's StatusNotifierWatcher. Every Flatpak app is PID 2 in its
 * own PID namespace, so without help every sandboxed tray app asks for
 * org.kde.StatusNotifierItem-2-1 and only the first one started gets it.
 *
 * Reporting a fixed, distinctive PID fixes the collision — the name becomes
 * unique and finish-args can grant exactly it (FLUXDOWN_FAKE_PID / getpid
 * below). The catch: GLib also puts getpid() into the SCM_CREDENTIALS control
 * message it sends during the D-Bus authentication handshake, and the kernel
 * rejects a ucred whose pid is not the sender's real one with EPERM — which
 * would take down the whole session-bus connection (portals, notifications, and
 * the tray's own name request).
 *
 * So getpid() is faked for everyone, and sendmsg() is interposed to rewrite the
 * pid in any SCM_CREDENTIALS message back to the real one on the way to the
 * kernel. That is the only datagram GLib decorates with credentials, so nothing
 * else is affected, and it does not depend on GLib's internal call graph.
 *
 * LD_PRELOAD is dropped from the environment in a constructor so child processes
 * (xdg-open and other portal helpers) never inherit the override.
 */

static pid_t real_getpid_value(void)
{
    return (pid_t)syscall(SYS_getpid);
}

pid_t getpid(void)
{
    const char *value = getenv("FLUXDOWN_FAKE_PID");
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

/*
 * Rewrite the pid in an SCM_CREDENTIALS ancillary message back to the real one.
 * msghdr is const, so work on a shallow copy that points at a private, patched
 * copy of the control buffer.
 */
ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags)
{
    static ssize_t (*real_sendmsg)(int, const struct msghdr *, int);

    if (real_sendmsg == NULL)
        real_sendmsg = dlsym(RTLD_NEXT, "sendmsg");

    if (real_sendmsg == NULL) {
        errno = ENOSYS;
        return -1;
    }

    if (msg == NULL || msg->msg_control == NULL || msg->msg_controllen == 0)
        return real_sendmsg(sockfd, msg, flags);

    unsigned char cbuf[256];
    if (msg->msg_controllen > sizeof(cbuf))
        return real_sendmsg(sockfd, msg, flags);

    memcpy(cbuf, msg->msg_control, msg->msg_controllen);

    struct msghdr copy = *msg;
    copy.msg_control = cbuf;

    int patched = 0;
    for (struct cmsghdr *cmsg = CMSG_FIRSTHDR(&copy);
         cmsg != NULL;
         cmsg = CMSG_NXTHDR(&copy, cmsg)) {
        if (cmsg->cmsg_level == SOL_SOCKET && cmsg->cmsg_type == SCM_CREDENTIALS &&
            cmsg->cmsg_len >= CMSG_LEN(sizeof(struct ucred))) {
            struct ucred uc;
            memcpy(&uc, CMSG_DATA(cmsg), sizeof(uc));
            uc.pid = real_getpid_value();
            memcpy(CMSG_DATA(cmsg), &uc, sizeof(uc));
            patched = 1;
        }
    }

    return real_sendmsg(sockfd, patched ? &copy : msg, flags);
}

__attribute__((constructor))
static void drop_ld_preload(void)
{
    unsetenv("LD_PRELOAD");
}
