{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  # Direct DT_NEEDED & dlopen dependencies of EpicGamesLauncher + libEOSSDK-Linux-Shipping.so
  alsa-lib,
  at-spi2-core,
  cairo,
  cacert,
  curl,
  dbus,
  desktop-file-utils,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glib-networking,
  gst_all_1,
  gtk3,
  hicolor-icon-theme,
  adwaita-icon-theme,
  libayatana-appindicator,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libsoup_3,
  libudev0-shim,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxinerama,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxtst,
  libxxf86vm,
  openssl,
  pango,
  pciutils,
  pipewire,
  python3,
  shared-mime-info,
  sqlite,
  systemd,
  udev,
  vulkan-loader,
  wayland,
  webkitgtk_4_1,
  xdg-utils,
  xkeyboard_config,
  zlib,
  zstd,
}:

let
  versionInfo = builtins.fromJSON (builtins.readFile ./version.json);
  inherit (versionInfo) version;
  encodedVersion = lib.replaceStrings [ "+" ] [ "%2B" ] version;

  # Libraries linked via DT_NEEDED or loaded dynamically via dlopen() by:
  # 1. usr/bin/EpicGamesLauncher (Tauri 2 + wry + WebKitGTK 4.1 + Ayatana tray + libsecret)
  # 2. usr/lib/epic-games-launcher/libEOSSDK-Linux-Shipping.so (EOS SDK + SDL/audio/display/Vulkan/GL)
  runtimeLibs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-core
    cairo
    curl
    dbus
    fontconfig
    freetype
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libayatana-appindicator
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libsoup_3
    libudev0-shim
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxinerama
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    libxxf86vm
    openssl
    pango
    pipewire
    sqlite
    systemd
    udev
    vulkan-loader
    wayland
    webkitgtk_4_1
    zlib
    zstd
  ]
  ++ (with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ]);

  runtimeBins = [
    desktop-file-utils
    pciutils
    python3
    shared-mime-info
    xdg-utils
  ];
in
stdenv.mkDerivation {
  pname = "epic-games-launcher-unwrapped";
  inherit version;

  src = fetchurl {
    url = "https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/${encodedVersion}/Linux/EpicGamesLauncher-x86_64.deb";
    hash = "sha256-KdwnDBSLIULtG1m6cYGfP/E0cnfYvLxNCkpTtjKDxWs=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs ++ [
    adwaita-icon-theme
    hicolor-icon-theme
  ];

  # Force autoPatchelfHook to add dlopen()'d libraries (libayatana-appindicator3,
  # libEOSSDK's audio/GL/Vulkan/Wayland/X11/udev libs) into the ELF RUNPATH.
  runtimeDependencies = map lib.getLib runtimeLibs;

  # EpicGamesLauncher embeds DWARF/symbol tables and custom sections; stripping can
  # corrupt Tauri/Rust panic backtraces or embedded resources.
  dontStrip = true;

  # Disable automatic GApps wrapping of all files in $out/bin; instead we pass
  # gappsWrapperArgs + custom environment variables to makeWrapper in preFixup
  # (after wrapGAppsHook3 has populated gappsWrapperArgs).
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib" "$out/share"
    cp -r usr/lib/epic-games-launcher "$out/lib/"
    cp -r usr/share/* "$out/share/"

    install -Dm755 usr/bin/EpicGamesLauncher "$out/lib/epic-games-launcher/EpicGamesLauncher"
    chmod +x "$out/lib/epic-games-launcher/libEOSSDK-Linux-Shipping.so"

    if [ -f "$out/share/applications/epic-games-launcher.desktop" ]; then
      substituteInPlace "$out/share/applications/epic-games-launcher.desktop" \
        --replace-fail "Exec=EpicGamesLauncher" "Exec=$out/bin/epic-games-launcher"
    fi

    runHook postInstall
  '';

  preFixup = ''
    # EpicGamesLauncher resolves resources/ThirdPartyNotices.txt via Tauri's resource_dir
    # ($out/lib/epic-games-launcher/resources/ThirdPartyNotices.txt), which is preserved
    # because the real binary sits inside $out/lib/epic-games-launcher/.
    makeWrapper "$out/lib/epic-games-launcher/EpicGamesLauncher" "$out/bin/epic-games-launcher" \
      "''${gappsWrapperArgs[@]}" \
      --set-default EGL_DISABLE_SELF_UPDATE 1 \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
      --set-default SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set-default XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb" \
      --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules" \
      --prefix LD_LIBRARY_PATH : "$out/lib/epic-games-launcher:${lib.makeLibraryPath runtimeLibs}" \
      --suffix LD_LIBRARY_PATH : "/run/opengl-driver/lib:/run/opengl-driver-32/lib" \
      --suffix __EGL_VENDOR_LIBRARY_DIRS : "/run/opengl-driver/share/glvnd/egl_vendor.d:/run/opengl-driver-32/share/glvnd/egl_vendor.d" \
      --prefix PATH : "${lib.makeBinPath runtimeBins}"

    ln -s "$out/bin/epic-games-launcher" "$out/bin/EpicGamesLauncher"
  '';

  passthru = {
    gioExtraModules = "${glib-networking}/lib/gio/modules";
  };

  meta = {
    description = "Official native Epic Games Launcher for Linux";
    homepage = "https://launcher.epicgames.com/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "epic-games-launcher";
    platforms = [ "x86_64-linux" ];
  };
}
