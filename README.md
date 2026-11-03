# Epic Games Launcher Flake

[![Epic Games Launcher](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FHy4ri%2Fepic-games-launcher-flake%2Fmain%2Fversion.json&query=%24.version&label=epic-games-launcher&color=0e0b21&link=https%3A%2F%2Flauncher.epicgames.com%2F)](https://launcher.epicgames.com/)
[![Build Status](https://img.shields.io/github/actions/workflow/status/Hy4ri/epic-games-launcher-flake/ci.yml?branch=main&label=build)](https://github.com/Hy4ri/epic-games-launcher-flake/actions/workflows/ci.yml)
[![Update Status](https://img.shields.io/github/actions/workflow/status/Hy4ri/epic-games-launcher-flake/update.yml?branch=main&label=auto-update)](https://github.com/Hy4ri/epic-games-launcher-flake/actions/workflows/update.yml)

Run and install the official native [Epic Games Launcher](https://launcher.epicgames.com/) for Linux (EGLv2) on NixOS or any Linux system with Nix.

The launcher runs inside an FHS environment with the 64-bit and 32-bit libraries that its built-in GE-Proton needs, so Windows games run on NixOS without extra setup.

The flake is updated automatically every day.

## Packages

| Package | What it is | Command |
|---|---|---|
| `epic-games-launcher` (default) | **Use this one.** The launcher inside the FHS environment for GE-Proton and games. | `epic-games-launcher` |
| `epic-games-launcher-fhs` | Same as `epic-games-launcher` | `epic-games-launcher` |
| `epic-games-launcher-unwrapped` | Only the patched launcher, without the FHS environment. Games will usually not run with it. | `epic-games-launcher` |

Platforms: Linux `x86_64` only.

## Try it without installing

You need Nix with [flakes enabled](https://wiki.nixos.org/wiki/Flakes).

```bash
nix run github:Hy4ri/epic-games-launcher-flake
```

## Install

There are **three ways** to install. **Pick one.** You do not need more than one.

| Option | Use it when |
|---|---|
| **A. NixOS module** (recommended) | You use NixOS. One line installs the launcher and turns on 32-bit graphics drivers for games. |
| **B. Overlay** | You want to write `pkgs.epic-games-launcher`, like any other nixpkgs package. |
| **C. Direct package** | You do not want to use overlays or modules. |

### Step 1: Add the flake input (needed for all options)

In your system `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    epic-games-launcher.url = "github:Hy4ri/epic-games-launcher-flake";
  };

  outputs = { nixpkgs, ... }@inputs: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; }; # lets your modules use `inputs`
      modules = [ ./configuration.nix ];
    };
  };
}
```

> Already have a flake? Add only the `epic-games-launcher.url` line, and make sure `inputs` reaches your modules (`specialArgs` for NixOS, `extraSpecialArgs` for Home Manager).

### Step 2, Option A: NixOS module (recommended)

In `configuration.nix`:

```nix
{ inputs, ... }:
{
  imports = [ inputs.epic-games-launcher.nixosModules.default ];

  nixpkgs.config.allowUnfree = true; # required: the launcher is marked unfree
  programs.epic-games-launcher.enable = true;
}
```

The module installs the launcher and sets `hardware.graphics.enable` and `hardware.graphics.enable32Bit` to `true`. You can still change these values in your own config.

### Step 2, Option B: Overlay

In `configuration.nix`:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.epic-games-launcher.overlays.default ];
  nixpkgs.config.allowUnfree = true; # required: the launcher is marked unfree

  environment.systemPackages = [ pkgs.epic-games-launcher ];

  # Needed by games (the module option does this for you):
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
```

For Home Manager, keep the two `nixpkgs` lines and use `home.packages = [ pkgs.epic-games-launcher ];`. The two `hardware.graphics` lines must still be in your NixOS config.

### Step 2, Option C: Direct package

In `configuration.nix`:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.epic-games-launcher.packages.${pkgs.stdenv.hostPlatform.system}.epic-games-launcher
  ];

  # Needed by games (the module option does this for you):
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
```

You do not need `allowUnfree` for this option. For Home Manager, put the package line in `home.packages` and keep the `hardware.graphics` lines in your NixOS config.

### Step 3: Rebuild

```bash
sudo nixos-rebuild switch --flake .#myhost
```

## Good to know

- **Self-update is off.** The Nix store is read-only, so the launcher cannot update itself (`EGL_DISABLE_SELF_UPDATE=1`). New versions come from this flake. Run `nix flake update epic-games-launcher` and rebuild.
- **GE-Proton** is downloaded by the launcher into `~/.local/share/epic-games-launcher/compat/`. The FHS environment gives it the 64-bit and 32-bit libraries it needs.
- **Login links** (`com.epicgames.launcher://`) open the launcher through its desktop entry.

<details>
<summary>Runtime details (for the curious)</summary>

- **UI:** Tauri 2 + `wry` (`webkitgtk_4_1`, `gtk3`, `libsoup_3`, `glib-networking` for TLS inside WebKit views).
- **Tray and desktop:** `libayatana-appindicator` (loaded at runtime), `libsecret` / D-Bus Secret Service keyring, `xdg-utils`, and the `x-scheme-handler/com.epicgames.launcher` desktop entry.
- **Epic Online Services (`libEOSSDK-Linux-Shipping.so`):** linked with ALSA, PulseAudio, PipeWire, Vulkan, OpenGL/GLVND (`__EGL_VENDOR_LIBRARY_DIRS` set to `/run/opengl-driver/share/glvnd/egl_vendor.d`), Wayland, X11, and `libudev0-shim`.
- **GE-Proton:** the launcher checks for `/lib/ld-linux.so.2` (`wow64_required`). The FHS environment provides `/lib64/ld-linux-x86-64.so.2` and `/lib/ld-linux.so.2`, Vulkan/OpenGL ICD discovery, GStreamer codecs, and the Wine dependencies.

</details>

## Updates

A GitHub Action checks for new launcher releases every day, tests the build, and commits the new version. To get it, update your lock file:

```bash
nix flake update epic-games-launcher
```

### Manual update (maintainers)

```bash
./update-version.sh                       # find the latest version
./update-version.sh "0.105.0+gc9a97d0"    # a specific version
```

### Repository layout

| File | Purpose |
|---|---|
| `flake.nix` | Flake entry point: packages, overlay, dev shell, and NixOS module |
| `package.nix` | Unwrapped launcher: unpacks the `.deb` and patches the binaries |
| `fhs.nix` | 64-bit + 32-bit FHS environment for GE-Proton and games |
| `scripts/check-update.sh` | Finds new releases from Epic's official installer link |
| `scripts/lib/network.sh` | HTTP helpers with retries and error capture |
| `update-version.sh` | Downloads the `.deb`, computes the hash, updates `package.nix` and `version.json` |
| `version.json` | Current version and download URL |
| `.github/workflows/ci.yml` | Build and `nix flake check` on push, PR, and manual run |
| `.github/workflows/update.yml` | Daily auto-update; opens an issue if it fails |

## License

This flake packaging is provided under the [MIT license](LICENSE). The Epic Games Launcher is proprietary software by Epic Games; Nix marks it as unfree. This flake only downloads and packages the official release.

## Support

If this flake helps you, you can support my work on [GitHub Sponsors](https://github.com/sponsors/hy4ri) or [Ko-fi](https://ko-fi.com/m_5_7). A star on the repo also helps.
