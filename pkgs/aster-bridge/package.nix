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
      or (throw "aster-bridge: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "aster-bridge";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/Aster-Privacy/Aster-Bridge/releases/download/v${finalAttrs.version}/Aster.Bridge_${finalAttrs.version}_${source.arch}.deb";
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
  ];

  runtimeDependencies = [ libayatana-appindicator ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r usr/bin usr/share $out/

    rm "$out/share/applications/Aster Bridge.desktop"
    install -Dm644 /dev/stdin $out/share/applications/aster-bridge.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Aster Bridge
    GenericName=Mail Bridge
    Comment=Use Aster Mail in any IMAP, SMTP, JMAP, POP3, or CardDAV app
    Exec=aster-bridge-desktop %u
    Icon=aster-bridge-desktop
    StartupWMClass=aster-bridge-desktop
    Terminal=false
    Categories=Network;Email;
    MimeType=x-scheme-handler/aster-mail;
    EOF

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set ASTER_DISABLE_UPDATER 1
      --set ASTER_LAUNCH_COMMAND aster-bridge-desktop
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
    description = "Local IMAP, SMTP, JMAP, POP3, and CardDAV bridge for Aster Mail";
    homepage = "https://astermail.org";
    changelog = "https://github.com/Aster-Privacy/Aster-Bridge/releases/tag/v${finalAttrs.version}";
    downloadPage = "https://github.com/Aster-Privacy/Aster-Bridge/releases";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "aster-bridge-desktop";
    platforms = builtins.attrNames sources.assets;
    maintainers = [ ];
  };
})
