# Changelog

## v0.5 — 22 November 2026
- Fixed the temporary valley ground window so it follows the player while preserving a stable isometric grid origin; this prevents walking beyond the initially drawn ground and seeing an empty field.
- Added source audit checks for inverse projection, redraw-on-grid-shift, and stable lattice anchoring.
- Verified the isometric projection/inverse transform numerically across 841 grid samples.
- Godot runtime and Android export remain untested because the build environment has no Godot or Android SDK.

## v0.4 — Save recovery hardening
- Added recovery fallback to the older verified backup when both the primary save and current backup are unavailable or invalid.
- Reject save envelopes whose data member is not a Dictionary.
- Extended the static audit to guard these recovery and payload-validation paths.

Validation boundary: static checks and archive integrity only. Godot import/runtime and Android device tests remain pending.
