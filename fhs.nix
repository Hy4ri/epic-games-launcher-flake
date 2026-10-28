{
  lib,
  buildFHSEnv,
  writeShellScript,
  epic-games-launcher-unwrapped,
  extraPkgs ? _pkgs: [ ],
  extraLibraries ? _pkgs: [ ],
  additionalBwrapArgs ? [ ],
  extraProfile ? "",
}:

let
  xorgDeps =
    pkgs: with pkgs; [
      libice
      libpthread-stubs
      libsm
      libx11
      libxaw
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxdmcp
      libxext
      libxfixes
      libxi
      libxinerama
      libxmu
      libxrandr
      libxrender
      libxscrnsaver
      libxt
      libxtst
      libxv
      libxxf86vm
    ];

  gstreamerDeps =
    pkgs: with pkgs.gst_all_1; [
      gstreamer
      gst-plugins-base
      gst-plugins-good
      gst-plugins-bad
      gst-plugins-ugly
      gst-libav
    ];
in
buildFHSEnv {
  pname = "epic-games-launcher";
  inherit (epic-games-launcher-unwrapped) version;

  # Windows games launched through Epic's built-in GE-Proton runtime require
  # both 64-bit (/lib64/ld-linux-x86-64.so.2) and 32-bit (/lib/ld-linux.so.2)
  # FHS dynamic linkers and libraries.
  multiArch = true;
  includeClosures = true;
  privateTmp = false;
  unshareIpc = false;
  unsharePid = false;

  targetPkgs =
    pkgs:
    with pkgs;
    [
      epic-games-launcher-unwrapped

      # Core CLI utilities & desktop integration
      bash
      coreutils
      curl
      cacert
      desktop-file-utils
      file
      findutils
      gnugrep
      gnused
      gnutar
      gzip
      lsb-release
      pciutils
      procps
      psmisc
      python3
      shared-mime-info
      umu-launcher
      unzip
      usbutils
      util-linux
      which
      xdg-utils
      xrandr
      xz
      zenity
      zstd

      # Launcher UI & WebKitGTK 4.1 runtime dependencies
      adwaita-icon-theme
      at-spi2-core
      cairo
      gdk-pixbuf
      glib
      glib-networking
      gtk3
      hicolor-icon-theme
      libayatana-appindicator
      libnotify
      libsecret
      libsoup_3
      pango
      webkitgtk_4_1
      xkeyboard_config

      # X11 locale files required by GTK/Xlib inside FHS
      (pkgs.runCommand "xorg-locale" { } ''
        mkdir -p "$out"
        ln -s "${libx11}/share" "$out/share"
      '')
    ]
    ++ extraPkgs pkgs;

  multiPkgs =
    pkgs:
    with pkgs;
    [
      # Core C/C++, crypto, compression, and system libraries (64-bit + 32-bit for Proton/Wine)
      stdenv.cc.cc
      glibc
      attr
      bzip2
      cups
      dbus
      expat
      fontconfig
      freetype
      fribidi
      gamemode
      giflib
      gnutls
      harfbuzz
      keyutils
      lcms2
      libcap
      libdrm
      libgbm
      libgcrypt
      libglvnd
      libgpg-error
      libgphoto2
      libjpeg_turbo
      libkrb5
      libogg
      libopus
      libpcap
      libpng
      libpulseaudio
      libsamplerate
      libselinux
      libsndfile
      libtheora
      libtiff
      libudev0-shim
      libunwind
      libusb1
      libv4l
      libva
      libvorbis
      libxkbcommon
      libxml2
      libxslt
      mpg123
      ncurses
      ocl-icd
      openal
      openldap
      openssl
      p11-kit
      pipewire
      samba4
      sane-backends
      SDL2
      speex
      sqlite
      udev
      util-linux
      vulkan-loader
      wayland
      zlib
      zstd
      alsa-lib
      alsa-plugins
    ]
    ++ xorgDeps pkgs
    ++ gstreamerDeps pkgs
    ++ extraLibraries pkgs;

  extraBuildCommands = ''
    cp -f "$out/usr/"{bin,sbin}/ldconfig || true
  '';

  extraBwrapArgs = [
    "--bind-try /etc/zoneinfo /usr/share/zoneinfo"
    "--bind-try /tmp/dumps /tmp/dumps"
    "--ro-bind-try /etc/nixos /etc/nixos"
  ]
  ++ additionalBwrapArgs;

  profile = ''
    # Prevent host GIO modules from clashing with FHS WebKitGTK/GLib while keeping TLS support
    export GIO_EXTRA_MODULES="${epic-games-launcher-unwrapped.passthru.gioExtraModules or ""}"
    export EGL_DISABLE_SELF_UPDATE=1
    export SDL_JOYSTICK_DISABLE_UDEV=1
    export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri:/run/opengl-driver-32/lib/dri
    export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d:/run/opengl-driver-32/share/glvnd/egl_vendor.d
    export LIBVA_DRIVERS_PATH=/run/opengl-driver/lib/dri:/run/opengl-driver-32/lib/dri
    export VDPAU_DRIVER_PATH=/run/opengl-driver/lib/vdpau:/run/opengl-driver-32/lib/vdpau
    ${extraProfile}
  '';

  runScript = writeShellScript "epic-games-launcher-fhs" ''
    exec "${epic-games-launcher-unwrapped}/bin/epic-games-launcher" "$@"
  '';

  extraInstallCommands = ''
    ln -s "$out/bin/epic-games-launcher" "$out/bin/EpicGamesLauncher"
    mkdir -p "$out/share/applications"
    ln -s "${epic-games-launcher-unwrapped}/share/icons" "$out/share/icons"
    substitute "${epic-games-launcher-unwrapped}/share/applications/epic-games-launcher.desktop" \
      "$out/share/applications/epic-games-launcher.desktop" \
      --replace-fail "${epic-games-launcher-unwrapped}/bin/epic-games-launcher" "$out/bin/epic-games-launcher"
  '';

  meta = epic-games-launcher-unwrapped.meta // {
    description = "Official native Epic Games Launcher for Linux (wrapped in a multi-arch FHS environment for GE-Proton and Windows games)";
    mainProgram = "epic-games-launcher";
  };
}
