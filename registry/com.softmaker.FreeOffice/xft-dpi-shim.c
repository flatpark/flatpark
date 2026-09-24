/*
 * FreeOffice sizes its user interface - icons, ribbon, dialogs, fonts - from
 * the X screen's physical size, XDisplayWidthMM / XDisplayHeightMM. Under
 * XWayland that size is synthesised for a fixed 96 dpi, so on a HiDPI Wayland
 * session whose compositor leaves X clients unscaled (Hyprland's
 * force_zero_scaling, KDE's "apply scaling themselves") the suite comes up at
 * half size.
 *
 * Those sessions publish the intended X11 DPI as the Xft.dpi resource, which is
 * what X toolkits read. This shim answers the two queries from Xft.dpi instead,
 * so FreeOffice's own scaling picks the right size. Where Xft.dpi is absent, or
 * is 96 (for example when the compositor upscales X clients itself), nothing
 * changes and the real answer is returned.
 *
 * FREEOFFICE_DPI=<dpi> in the environment overrides both, e.g.
 *   flatpak override --user --env=FREEOFFICE_DPI=144 com.softmaker.FreeOffice
 */
#define _GNU_SOURCE
#include <X11/Xlib.h>
#include <dlfcn.h>
#include <stdlib.h>

static double target_dpi(Display *d)
{
    const char *v = getenv("FREEOFFICE_DPI");
    if (!v || !*v)
        v = XGetDefault(d, "Xft", "dpi");
    if (!v)
        return 0;
    double dpi = strtod(v, NULL);
    return (dpi >= 48 && dpi <= 960) ? dpi : 0;
}

int XDisplayWidthMM(Display *d, int screen)
{
    double dpi = target_dpi(d);
    if (dpi > 0)
        return (int)(DisplayWidth(d, screen) * 25.4 / dpi + 0.5);
    int (*real)(Display *, int) = (int (*)(Display *, int))dlsym(RTLD_NEXT, "XDisplayWidthMM");
    return real ? real(d, screen) : 0;
}

int XDisplayHeightMM(Display *d, int screen)
{
    double dpi = target_dpi(d);
    if (dpi > 0)
        return (int)(DisplayHeight(d, screen) * 25.4 / dpi + 0.5);
    int (*real)(Display *, int) = (int (*)(Display *, int))dlsym(RTLD_NEXT, "XDisplayHeightMM");
    return real ? real(d, screen) : 0;
}
