---
description: The few rules every other FlatPark rule follows from.
order: 2
---

# Principles

These follow from [what we believe](about.md#what-we-believe), and every rule
in these docs follows from one of them. When a case isn't covered, decide it
by them.

## Listing: harm and honesty, not taste

1. **If it's sound, it's listed.** An app is listed when it is the vendor's
   official release, isn't malicious, is legal to distribute, works in the
   sandbox and its package is honest about what it does.
2. **Origin doesn't matter.** No one asks how many users an app has, how old
   it is, who wrote it or with what. No app is turned away or removed for its
   toolkit, its licence, how it was made, or a label someone gave it.
3. **Packaged for users.** An app can be listed without its vendor taking
   part: the community packages it because users need it, from the vendor's
   official download. An app that people want but that has no usable official
   Linux release may come from a public
   [build repository](../packagers/basics.md#build-repositories) instead, built
   the way upstream builds it and within its licence; its bugs go to that
   repository, never to upstream.

## Disclosure: facts, not verdicts

4. **Every page says it plainly.** Permissions, packaging level, open or closed
   source, whether it needs an account, shows ads or has paid features, how
   often it is released and how many install it: all shown as facts, with no
   score.
5. **Every package says what it does.** Each one declares its packaging level
   (Unmodified, Adapted, Modified, Reduced isolation), and CI checks the
   declaration against what the package actually does. A closed-source app may
   need a change to work in the sandbox; the change is reviewed, and the app's
   page says exactly what it is and why.

## Exposure: helping good apps be seen

6. **Recommendation by published rules.** Popular, picks, collections and
   guides are ranked on published signals anyone can check, and every
   editor's pick gives its reason. A small, good app has a visible way up.
7. **Fading, not removal.** An app that is no longer maintained leaves the
   recommendations but stays listed and installable. Apps are removed only
   when they break, their download is gone, a release is malicious, or the
   developer asks.

## Convenience: Flatpak for every app

8. **The vendor's own build, nothing else.** Apps come from the vendor's
   official release, which your Flatpak downloads from the vendor's own servers
   at install time (extra-data). FlatPark doesn't build apps from source and
   doesn't host their files. Open-source apps run unmodified: nothing is
   injected into their process and none of their files is changed. If one
   can't work in the sandbox without that, the fix belongs upstream and the
   app isn't listed until then.
9. **One place to install and update.** Apps that ship only a raw `.deb`,
   tarball or AppImage install and auto-update through one remote, usually
   within minutes of an upstream release.
10. **The latest runtime, for every app.** When a new version of the
    freedesktop, GNOME or KDE runtime comes out, every app on it moves together
    and is tested, so no app keeps an old runtime on your disk.
11. **Least privilege by default.** A package grants what the app's main job
    needs; anything more is the user's choice, documented as a command. A broad
    grant (home, host commands) is made by default only after review, when the
    app needs it or leaving it out would take more overrides than a user can be
    expected to manage.
12. **Test before shipping, fix fast after.** Our own changes are tested
    before they ship ([testing playbook](../reviewers/testing-playbook.md));
    upstream releases ship at once and are fixed quickly when they break. Every
    process is weighed by two questions: does it stop us shipping our own bugs,
    and does it keep that speed?

## Restraint: FlatPark holds itself to account

13. **The developer has the final word on their app**: whether it's listed, how
    it's packaged, what is said about it. No say over other apps.
14. **Decisions in public.** Rules, packages, reviews, rankings, incidents and
    removals are all in the open repository, and the rules change only through
    public PRs.
