// Cowork opt-in (see COWORK.md). claude-desktop-wrapper preloads this library
// only when the user has added the Cowork overrides; without them it is never
// loaded and the app runs exactly as shipped.
//
// The app decides whether Cowork is available with fs.access() on fixed host
// paths (QEMU, UEFI firmware, virtiofsd), which inside the sandbox belong to
// the runtime. With --filesystem=host-os:ro the host's /usr is visible at
// /run/host/usr, so those checks are pointed there. The app then starts its
// own cowork-linux-helper, which needs QEMU and /dev/kvm on the host; that exec
// is sent to cowork-host-helper, which runs the same helper on the host through
// flatpak-spawn. The helper's control socket lives in the per-app runtime dir,
// the one part of $XDG_RUNTIME_DIR the sandbox and the host share, so connect()
// to it is pointed there. Nothing else is changed.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#ifndef HOST_HELPER
#define HOST_HELPER "/app/bin/cowork-host-helper"
#endif

// Prefixes of the paths the app checks before it offers Cowork.
static const char *const host_paths[] = {
  "/usr/bin/qemu-system-", "/usr/share/OVMF/", "/usr/share/AAVMF/",
  "/usr/libexec/virtiofsd", "/usr/bin/virtiofsd", NULL,
};

static const char *to_host(const char *p, char *buf, size_t n) {
  if (!p) return p;
  for (int i = 0; host_paths[i]; i++)
    if (strncmp(p, host_paths[i], strlen(host_paths[i])) == 0 &&
        (size_t)snprintf(buf, n, "/run/host%s", p) < n)
      return buf;
  return p;
}

int access(const char *p, int mode) {
  static int (*real)(const char *, int);
  if (!real) real = dlsym(RTLD_NEXT, "access");
  char b[4096];
  return real(to_host(p, b, sizeof b), mode);
}

int faccessat(int dirfd, const char *p, int mode, int flags) {
  static int (*real)(int, const char *, int, int);
  if (!real) real = dlsym(RTLD_NEXT, "faccessat");
  char b[4096];
  return real(dirfd, to_host(p, b, sizeof b), mode, flags);
}

int connect(int fd, const struct sockaddr *addr, socklen_t len) {
  static int (*real)(int, const struct sockaddr *, socklen_t);
  if (!real) real = dlsym(RTLD_NEXT, "connect");
  const char *rt = getenv("XDG_RUNTIME_DIR"), *id = getenv("FLATPAK_ID");
  if (addr && addr->sa_family == AF_UNIX && rt && id) {
    const struct sockaddr_un *u = (const struct sockaddr_un *)addr;
    char want[sizeof u->sun_path];
    snprintf(want, sizeof want, "%s/claude-cowork-vm.sock", rt);
    if (strcmp(u->sun_path, want) == 0) {
      struct sockaddr_un v = { .sun_family = AF_UNIX };
      if ((size_t)snprintf(v.sun_path, sizeof v.sun_path, "%s/app/%s/claude-cowork-vm.sock", rt, id) < sizeof v.sun_path)
        return real(fd, (const struct sockaddr *)&v, sizeof v);
    }
  }
  return real(fd, addr, len);
}

static const char *helper(const char *file) {
  static const char name[] = "/cowork-linux-helper";
  size_t n = file ? strlen(file) : 0, k = sizeof name - 1;
  return n >= k && strcmp(file + n - k, name) == 0 ? HOST_HELPER : file;
}

int execve(const char *file, char *const argv[], char *const envp[]) {
  static int (*real)(const char *, char *const[], char *const[]);
  if (!real) real = dlsym(RTLD_NEXT, "execve");
  return real(helper(file), argv, envp);
}

int execvp(const char *file, char *const argv[]) {
  static int (*real)(const char *, char *const[]);
  if (!real) real = dlsym(RTLD_NEXT, "execvp");
  return real(helper(file), argv);
}

int execvpe(const char *file, char *const argv[], char *const envp[]) {
  static int (*real)(const char *, char *const[], char *const[]);
  if (!real) real = dlsym(RTLD_NEXT, "execvpe");
  return real(helper(file), argv, envp);
}
