# Aether Valley 

A new Godot 4.x / GDScript project. No legacy project code, repository workflows, APKs, or mixed branding are used as the foundation.

## Current foundation
- Temporary elevated three-quarter/isometric ground and chibi-proportion player placeholders.
- Eight-direction keyboard movement with elevated three-quarter screen projection.
- Android touch D-pad and ACT button; desktop-wide windows hide the touch overlay.
- Data-driven catalogue of the 14 approved Dynamic Fantasy Seasons.
- Local versioned save scaffold: 30-second dirty autosave, pause/close save request, temporary-file verification, and backup recovery.

## Account and cloud-save decision
Approved player flow: Sign in -> Enter Character Name -> Play. Sign-in uses email OTP without a password. Local autosave is every 30 seconds; cloud autosave is every 60 minutes while online and authenticated. Existing Supabase project Aether Valley is the target backend. Cloud auth/sync is not implemented in this scaffold yet.

## Not included / not claimed
- Original visual reference image is not yet committed in this initial source upload.
- No final art, modular tileset, final collision/scale lock, or complete gameplay loop.
- No working Supabase account/cloud integration yet.
- No Android APK. Godot import/runtime, desktop smoke tests, Android export, and physical-device checks are still required.

## Controls
WASD / Arrow Keys to move. E is reserved for interaction in the next vertical-slice step.
