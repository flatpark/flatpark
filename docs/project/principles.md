---
description: The few rules every other FlatPark rule follows from.
order: 2
---

# Principles

Every rule in these docs comes from one of these. When a case isn't covered,
decide it by them, and by the [goal](about.md#goal): an efficient remote that
is easy to take part in, where speed matters most.

1. **The developer's own build, nothing else.** Apps come from the developer's
   official release, which your Flatpak downloads from the developer's own
   servers at install time (extra-data). FlatPark doesn't build apps from source
   and doesn't host their files. An app that people want but that has no
   usable official Linux release may come from a public
   [build repository](../packagers/basics.md#build-repositories) instead, built the way upstream builds it and
   within its licence; that release is then used like any other download, and
   its bugs go to that repository, never to upstream.
2. **Open-source apps run unmodified.** Nothing is injected into their
   process and none of their files is changed. If one can't work in the sandbox
   without that, the fix belongs upstream and the app isn't listed until then.
3. **Closed-source changes are reviewed and disclosed.** A closed-source app
   may need a change to work in the sandbox; the change is reviewed, and the
   app's page says exactly what it is and why.
4. **Every package says what it does.** Each one declares its packaging level
   (Unmodified, Adapted, Modified, Reduced isolation), and CI checks the
   declaration against what the package actually does.
5. **Least privilege by default.** A package grants what the app's main job
   needs; anything more is the user's choice, documented as a command. A broad
   grant (home, host commands) is made by default only after review, when the
   app needs it or leaving it out would take more overrides than a user can be
   expected to manage.
6. **The developer has the final word on their app**: whether it's listed, how
   it's packaged, what is said about it. No say over other apps.
7. **Judge the package, not how it was written.** An app is listed or not on
   what it does and how it's packaged, not on whether it was written with AI.
8. **The current runtime, for every app.** When a new version of the
   freedesktop, GNOME or KDE runtime comes out, every app on it moves together
   and is tested, so no app keeps an old runtime on your disk.
9. **Test before shipping, fix fast after.** Our own changes are tested
   before they ship ([testing playbook](../reviewers/testing-playbook.md));
   upstream releases ship at once and are fixed quickly when they break.
10. **Decisions in public.** Rules, packages, reviews, incidents and removals
    are all in the open repository.
