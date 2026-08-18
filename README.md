# WukongMP Game Reference Assemblies

Reference-only assemblies for the Black Myth: Wukong assemblies that the WukongMP SDK
and WukongMP mods compile against.

These contain **no game code**. Every method body has been stripped, leaving only the
API surface: type names, member names, signatures and attributes. The .NET runtime marks
them with `ReferenceAssemblyAttribute` and refuses to load them for execution:

```
Could not load file or assembly 'UnrealEngine.Runtime, Version=1.0.0.0, ...'.
Reference assemblies cannot be loaded for execution. (0x80131058)
```

At runtime the real assemblies are already loaded in the game process, so mods built
against these refs bind to the genuine implementations in-game. The refs only ever exist
at build time.

## Contents

`ref/` holds 36 reference assemblies, listed in `assemblies.txt`. That list is the set the
SDK and the mod repos actually reference from a `Game` folder, nothing more.

Members that cannot be referenced from another assembly are stripped, which keeps the
published surface to what a mod can actually compile against. Empty versus non-empty
struct semantics are preserved. `WukongMp.Api`, `WukongMp.Sdk` and the mod template all
compile against these unchanged.

Deliberately **not** included: the Mono runtime and BCL assemblies the game also ships
(`mscorlib`, `netstandard`, `System.dll`, `System.Core`, `System.Xml`, `System.Runtime`,
`Mono.Posix`, and similar). Those come from the target framework. Shipping our own copies
would only create assembly version conflicts.

## Provenance

| | |
|---|---|
| source | a local Black Myth: Wukong installation, assemblies not redistributed |
| supported game version | `1.0.21.23831` |
| input set SHA-256 (first 16) | `377109f25eb71a26` |
| generated with | `JetBrains.Refasmer` (`dotnet tool install -g JetBrains.Refasmer.CliTool`) |
| visibility | `--omit-non-api-members`, drops private members and types that do not participate in the public API |

Assembly versions are preserved exactly, so a mod compiled against these binds to the
game's own assemblies without a version mismatch.

The NuGet package is versioned by the **game** build it supports, `1.0.21.23831`, not by
the SDK version. The two move independently: a game patch needs new refs, an SDK release
does not.

The assemblies themselves carry no usable build stamp (`b1.Managed` and `UnrealEngine`
both report `0.0.0.0`), so the game version cannot be read back out of them. The
input-set hash above is the content check: recompute it after a game patch to tell
whether the assemblies actually changed.

## Regenerating

Requires a local game installation. See `generate.ps1`:

```powershell
./generate.ps1 -GameDllPath "C:\path\to\extracted\game\assemblies"
```

The script reads `assemblies.txt`, runs Refasmer over exactly those files, writes to
`ref/`, and prints the input-set hash so you can record it here.

## Using these

Point `$(GameDllPath)` at `ref/`, or consume the NuGet package built from this repo.

Because the bodies are gone, two things do not work against these refs:

- stepping into game code in an IDE, or reading a decompiled body from Go to Definition
- executing game code outside the game, so no offline unit tests that touch game types

For either of those, point `$(GameDllPath)` at a full set extracted from your own
installation instead. Nothing else changes: the compile succeeds identically either way.
