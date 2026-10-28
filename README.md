# Epic Games Launcher Flake

[![Epic Games Launcher](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FHy4ri%2Fepic-games-launcher-flake%2Fmain%2Fversion.json&query=%24.version&label=epic-games-launcher&color=0e0b21&link=https%3A%2F%2Flauncher.epicgames.com%2F)](https://launcher.epicgames.com/)
[![Build Status](https://img.shields.io/github/actions/workflow/status/Hy4ri/epic-games-launcher-flake/ci.yml?branch=main&label=build)](https://github.com/Hy4ri/epic-games-launcher-flake/actions/workflows/ci.yml)
[![Update Status](https://img.shields.io/github/actions/workflow/status/Hy4ri/epic-games-launcher-flake/update.yml?branch=main&label=auto-update)](https://github.com/Hy4ri/epic-games-launcher-flake/actions/workflows/update.yml)

Nix flake for the official native [Epic Games Launcher](https://launcher.epicgames.com/) (EGLv2) for Linux.

## Packages

| Attribute | Description |
|---|---|
| `default` / `epic-games-launcher` / `epic-games-launcher-fhs` | **Recommended.** Multi-arch `buildFHSEnv` wrapper providing 64-bit (`/lib64/ld-linux-x86-64.so.2`) and 32-bit (`/lib/ld-linux.so.2`) FHS libraries, Vulkan/OpenGL ICD discovery, GStreamer media codecs, and Wine/Proton dependencies required by Epic's built-in GE-Proton runtime. |
| `epic-games-launcher-unwrapped` | Standalone `autoPatchelfHook`-patched derivation of the official `.deb` binary (`EpicGamesLauncher`) and `libEOSSDK-Linux-Shipping.so`. |

## Installation

### Run directly

```bash
nix run github:Hy4ri/epic-games-launcher-flake
```

### NixOS Module

```nix
{
  inputs.epic-games-launcher.url = "github:Hy4ri/epic-games-launcher-flake";

  outputs = { self, nixpkgs, epic-games-launcher, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        epic-games-launcher.nixosModules.default
        {
          programs.epic-games-launcher.enable = true;
        }
      ];
    };
  };
}
```

### Overlay (NixOS / Home Manager)

1. Add the flake input:

```nix
{
  inputs.epic-games-launcher.url = "github:Hy4ri/epic-games-launcher-flake";
}
```

2. Add the overlay:

```nix
nixpkgs.overlays = [ inputs.epic-games-launcher.overlays.default ];
```

3. Install the package:

```nix
environment.systemPackages = with pkgs; [
  epic-games-launcher
];
```

## Runtime Details

- **UI & WebView:** Built on Tauri 2 + `wry` (`webkitgtk_4_1`, `gtk3`, `libsoup_3`, `glib-networking` for TLS inside WebKit views).
- **System Tray & Desktop Integration:** Includes `libayatana-appindicator` (`dlopen`ed at runtime), `libsecret` / D-Bus Secret Service keyring support, `xdg-utils`, and the `x-scheme-handler/com.epicgames.launcher` desktop entry.
- **Epic Online Services (`libEOSSDK-Linux-Shipping.so`):** Linked with ALSA, PulseAudio, PipeWire, Vulkan, OpenGL/GLVND (`__EGL_VENDOR_LIBRARY_DIRS` pointed to `/run/opengl-driver/share/glvnd/egl_vendor.d`), Wayland, X11, and `libudev0-shim`.
- **Windows Game Compatibility (GE-Proton):** Epic Games Launcher downloads GE-Proton into `~/.local/share/epic-games-launcher/compat/` and checks `/lib/ld-linux.so.2` (`wow64_required`). The default FHS wrapper provides both 64-bit and 32-bit FHS environments so GE-Proton and Windows games run out of the box on NixOS.
- **Self-Update:** `EGL_DISABLE_SELF_UPDATE=1` is set by default because `/nix/store` is immutable; updates are handled declaratively by the daily CI workflow or `./update-version.sh`.

## Project Structure

| File | Purpose |
|---|---|
| `flake.nix` | Flake entry point — exposes packages, overlay, devShell, and NixOS module |
| `package.nix` | Unwrapped derivation — unpacks `.deb`, patches ELF `RUNPATH`s, and wraps environment |
| `fhs.nix` | Multi-arch FHS environment (`buildFHSEnv`) for GE-Proton and Windows games |
| `scripts/check-update.sh` | Queries Epic's official installer redirect for new `EGLv2` releases |
| `scripts/lib/network.sh` | Hardened HTTP fetch helpers with retries and error capture |
| `update-version.sh` | Downloads `.deb`, computes SRI sha256, updates `package.nix` and `version.json` |
| `version.json` | Current version and upstream `.deb` CDN URL |
| `.github/workflows/ci.yml` | Build and flake check workflow on push, PR, and manual dispatch |
| `.github/workflows/update.yml` | Daily auto-update workflow with build verification and auto-issue reporting |

## Manual Updates

```bash
# Auto-detect latest version from Epic Games and update hashes:
./update-version.sh

# Or specify an explicit version string:
./update-version.sh "0.105.0+gc9a97d0"
```
