# carplay_hook.jar rebuild provenance (iOS 26 third-party navigation fix)

## What changed and why
The shipped jar was built WITHOUT the third-party navigation overlay, so on
iOS 26+ third-party CarPlay navigation apps lose cluster guidance when the app
is not foregrounded (visible_in_app treated as route liveness - upstream luka
issue #8). This rebuild applies the author's own anchor-checked overlay, which
adds:

1. RouteGuidanceBeingShownInApp is treated as visibility, not route liveness.
2. Bargraph fallback when a nav app omits CPManeuver.initialDistance.
3. An Amap-v38 guard preserving the 5-second soft-expiry semantics.

## Build
- Source: Lanye-z/mib2q-carplay-rgi-cn commit 4ad0c92 (java_patch)
- Overlay: tools/apply_third_party_nav_overlay.py from the same commit
- Compiler: Zulu zulu8.78.0.19-ca-jdk8.0.412 (javac 1.8.0_412), -source 1.2
  -target 1.2 (class file major version 46)
- Classpath: the previously shipped jar (for com.luka/de.audi patched types)
  plus API stubs for stock lsd.jar types (not available offline). Stub
  signatures mirror the real interfaces as encoded in this repo's
  GatedCombiService / ClusterService overrides; at runtime the real lsd.jar
  types bind.

## Verification
- 54/54 class names identical to the shipped jar; 76 entries byte-identical.
- Exactly 6 class files differ (RouteGuidance, AmapV38Compat + inners,
  AmapRouteGuidance, BAPBridge) - the overlay's targets.
- amap_force_inactive marker present in the new RouteGuidance and
  AmapV38Compat classes.
- The 9 recompiled-but-unchanged classes are byte-identical, confirming the
  compiler matches the author's toolchain.

## Checksums
- previous jar (fix/reliability): 94d0356d9a12730aca6dd430552c3aaf15ef9021ce3ddee87a760de966f5ad92
- rebuilt jar (this branch):      bee644a2cc3f9a9b99102630874966ec138cbe0333459d84e7029062fabbe6c4
