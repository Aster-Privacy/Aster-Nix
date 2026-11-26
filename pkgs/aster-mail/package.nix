{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  cairo,
  dbus,
  gdk-pixbuf,
  glib,
  glib-networking,
  gst_all_1,
  gtk3,
  libayatana-appindicator,
  libsoup_3,
  webkitgtk_4_1,
  xdg-utils,
  bubblewrap,
}:

let
  sources = lib.importJSON ./sources.json;
  source =
    sources.assets.${stdenv.hostPlatform.system}
      or (throw "aster-mail: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "aster-mail";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/Aster-Privacy/Aster-Mail/releases/download/v${finalAttrs.version}/Aster.Mail_${finalAttrs.version}_${source.arch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    cairo
    dbus
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libsoup_3
    webkitgtk_4_1
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
  ];

  runtimeDependencies = [ libayatana-appindicator ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r usr/bin usr/share $out/

    rm "$out/share/applications/Aster Mail.desktop"
    install -Dm644 /dev/stdin $out/share/applications/aster-mail.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Aster Mail
    GenericName=Email Client
    Comment=Private, end-to-end encrypted email
    Exec=aster-mail-desktop %u
    Icon=aster-mail-desktop
    StartupWMClass=aster-mail-desktop
    Terminal=false
    Categories=Network;Email;
    MimeType=x-scheme-handler/aster;x-scheme-handler/mailto;
    EOF

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set ASTER_DISABLE_UPDATER 1
      --set ASTER_LAUNCH_COMMAND aster-mail-desktop
      --prefix PATH : ${
        lib.makeBinPath [
          xdg-utils
          bubblewrap
        ]
      }
    )
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Desktop client for Aster Mail, a private end-to-end encrypted email service";
    homepage = "https://astermail.org";
    changelog = "https://github.com/Aster-Privacy/Aster-Mail/releases/tag/v${finalAttrs.version}";
    downloadPage = "https://github.com/Aster-Privacy/Aster-Mail/releases";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "aster-mail-desktop";
    platforms = builtins.attrNames sources.assets;
    maintainers = [ ];
  };
})
