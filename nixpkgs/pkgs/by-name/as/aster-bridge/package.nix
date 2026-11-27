{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  buildNpmPackage,
  fetchNpmDeps,
  cargo-tauri,
  nodejs,
  npmHooks,
  jq,
  pkg-config,
  wrapGAppsHook3,
  dbus,
  glib-networking,
  libayatana-appindicator,
  openssl,
  sqlcipher,
  webkitgtk_4_1,
  xdg-utils,
  bubblewrap,
  aster-bridge-cli,
}:

let
  ui-src = fetchFromGitHub {
    name = "aster-ui";
    owner = "Aster-Privacy";
    repo = "aster-ui";
    rev = "bfd6e02a24a92b2b0428f9a58cd4d6b7abc0f310";
    hash = "sha256-flKNrejbBPjbVEh3JcYw8radwLylqUOIKkHWU4ulvVk=";
  };

  aster-ui = buildNpmPackage {
    pname = "aster-ui";
    version = "0-unstable-${builtins.substring 0 7 ui-src.rev}";
    src = ui-src;
    npmDepsHash = "sha256-Hm3ag1f5gcdvgt0raWymIv+Doqv2bynwZ/BU9NZsU/o=";
    npmFlags = [ "--ignore-scripts" ];

    preBuild = ''
      rm -rf dist
    '';

    installPhase = ''
      runHook preInstall
      cp -r . $out
      runHook postInstall
    '';

    dontFixup = true;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "aster-bridge";
  inherit (aster-bridge-cli) version src;

  postUnpack = ''
    cp -r ${aster-bridge-cli.mail-src} Aster-Mail
    cp -r ${aster-ui} aster-ui
    chmod -R u+w Aster-Mail
    chmod -R u+w aster-ui
  '';

  postPatch = ''
    jq '.bundle.createUpdaterArtifacts = false' src-tauri/tauri.conf.json > tauri.conf.json.new
    mv tauri.conf.json.new src-tauri/tauri.conf.json
  '';

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoDeps = aster-bridge-cli.cargoDeps;

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src;
    hash = "sha256-BQ+Q564gsevdmBfEA4FCumJdbrhlLgf+3l9hFiQBnyE=";
  };
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    cargo-tauri.hook
    rustPlatform.cargoSetupHook
    nodejs
    npmHooks.npmConfigHook
    jq
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    dbus
    glib-networking
    libayatana-appindicator
    openssl
    sqlcipher
    webkitgtk_4_1
  ];

  env.LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";

  postInstall = ''
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
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set ASTER_DISABLE_UPDATER 1
      --set ASTER_LAUNCH_COMMAND aster-bridge-desktop
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --prefix PATH : ${
        lib.makeBinPath [
          xdg-utils
          bubblewrap
        ]
      }
    )
  '';

  passthru = {
    inherit aster-ui ui-src;
  };

  meta = {
    description = "Local IMAP, SMTP, JMAP, POP3, and CardDAV bridge for Aster Mail";
    homepage = "https://astermail.org";
    changelog = "https://github.com/Aster-Privacy/Aster-Bridge/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Plus;
    mainProgram = "aster-bridge-desktop";
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ findleyl ];
  };
})
