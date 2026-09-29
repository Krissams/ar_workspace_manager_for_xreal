# Fix: Air 2 Pro disappears when starting AR

## Problem and evidence

On an M1 Max Mac with Air 2 Pro configured as a 1920×1080 60 Hz extended display,
Start AR created a virtual monitor, the displays flickered, and AR stopped with
“Glasses disconnected — AR stopped.” USB head tracking continued working.

The September 29, 2026 reproduction showed:

- WindowServer restored a saved display set immediately after virtual-display
  creation and changed the glasses from mode 41 to mode 39.
- The saved set without the virtual monitor used 60 Hz. The set with the legacy
  virtual monitor used 120 Hz and contained `IndependentOutput: true` for the
  glasses. The glasses disappeared from the online display list.
- The application stopped AR after its 1.5-second disconnect debounce. Destroying
  the virtual monitor restored the glasses.
- A hardware regression test reproduced the failure with the legacy virtual
  identity. Mode restoration and an experimental enable transaction returned
  success but did not bring the glasses online. The enable API experiment is not
  included in this change.

This isolates the failing saved display set. It does not establish how that set
was originally created, a cable fault, or refresh rate alone as the cause.

## Implementation

The virtual-monitor serial pool moves once from `0x56520000` to `0x56520100`, avoiding
reuse of the affected legacy display set. Slot identities remain stable across
launches; this does not generate a new identity on every start.

Startup also preserves the selected output mode and UUID before creating virtual
monitors. It resolves that UUID against all connected displays using runtime-resolved
`CGSGetDisplayList`, because disabled outputs can be absent from
`CGGetOnlineDisplayList`. If the private entry point is unavailable, enumeration
falls back to the public online list.

When needed, startup restores the selected mode and extended-display state for the
session, with at most two attempts and an eight-second readiness deadline. It checks
readiness again after arrangement and opens the renderer only on a fresh active
`NSScreen`; it no longer falls back to the stale screen object. During this bounded
phase, the normal disconnect watchdog is suppressed. A startup token invalidates
pending work after Stop or a new session. Timeout tears down without replacing the
saved window layout with windows displaced during startup.

The change does not directly edit or delete macOS display preference files.

## Compatibility and limitations

- The identity migration may reset macOS's remembered positions and other settings
  for virtual monitors on first use. The application's workspace configuration is
  retained and its arrangement is reapplied.
- All virtual monitors use the new bounded pool. Previously saved OS configurations
  are left intact. Switching back to an older build selects the legacy identities
  and may reproduce the original problem.
- Private display enumeration remains dependent on macOS implementation details;
  the public fallback and bounded timeout prevent indefinite recovery.
- A different display set that becomes invalid later can still exceed the recovery
  deadline. The application reports that failure rather than rendering to an old
  display object.

## Validation

Verified on September 29, 2026:

- Five automated tests passed for mode restoration, delayed reconnect, loss after
  arrangement, bounded retries, and unplug timeout. These are simulated sequences.
- Two physical-device runs passed with the revised identity pool. Each created the
  same 2560×1440 HiDPI virtual monitor and confirmed the actual Air 2 Pro remained
  active at the pre-start 60 Hz while the virtual monitor was still present. The
  test destroyed its virtual monitor afterward.
- The final suite passed all six tests with the hardware test explicitly enabled.
- The debug app built and passed code-signature verification. The local test bundle
  was labeled `0.9.1-startup-fix2`; the installed release was not replaced.

The final rendered AR view has not been verified. Desktop UI automation was
unavailable. Remaining manual acceptance checks: Start AR and inspect the view in
the glasses; stop/restart; unplug during active AR; and Stop during the startup wait
with no delayed output window appearing afterward.

Run ordinary tests (hardware test is skipped):

```sh
swift test --build-system native
```

Run the physical regression explicitly, with Air 2 Pro connected and AR stopped.
This temporarily creates a virtual display and may flicker/rearrange the desktop:

```sh
XREAL_HARDWARE_RECOVERY_TEST=1 swift test --build-system native --filter OutputDisplayHardwareTests
```

The local Swift 6.4 toolchain defaults to `swiftbuild`; this repository's relative
VLC include paths required `--build-system native`. The VLCKit fetch script removes
dSYMs but leaves `DebugSymbolsPath` metadata. Local build preparation removed that
key from the ignored vendor xcframework `Info.plist`; retaining the original dSYMs
is another option. Neither workaround changes the shipped application source.

## References

- [Private display enumeration declaration](https://github.com/janten/disable-monitor/blob/master/DisplayData.h)
- [IndependentOutput investigation in Force HiDPI](https://github.com/sammcj/force-hidpi/blob/main/CLAUDE.md)

The local hardware reproduction above is the evidence for this fix; the external
investigation provides supporting context.
