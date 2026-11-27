{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchNpmDeps,
  cargo-tauri,
  nodejs,
  npmHooks,
  jq,
  pkg-config,
  wrapGAppsHook3,
  glib-networking,
  gst_all_1,
  libayatana-appindicator,
  openssl,
  webkitgtk_4_1,
  xdg-utils,
  bubblewrap,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "aster-mail";
  version = "1.4.90";

  src = fetchFromGitHub {
    owner = "Aster-Privacy";
    repo = "Aster-Mail";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BF2hhoUGSErKW+EHEiHHDfgITBgwpfmNeoaHLGRbgTs=";
  };

  postPatch = ''
    jq '.bundle.createUpdaterArtifacts = false' src-tauri/tauri.conf.json > tauri.conf.json.new
    mv tauri.conf.json.new src-tauri/tauri.conf.json
  '';

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    sourceRoot = "${finalAttrs.src.name}/${finalAttrs.cargoRoot}";
    hash = "sha256-2ni4mCEMbS/DD01fJ1zqeDL+zOFQmB8gZ+PdApyFpkA=";
  };

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    inherit (finalAttrs) src;
    hash = "sha256-Yqbd1YgNgYc3HRoKehUCpZLLsUO9OWgBiiP+Px7yBn4=";
  };
  npmFlags = [ "--ignore-scripts" ];

  preBuild = ''
    patchShebangs node_modules/.bin/patch-package
    node_modules/.bin/patch-package
  '';

  env = {
    VITE_SPECIAL_OFFER_ENABLED = "true";
    NODE_OPTIONS = "--max-old-space-size=6144";
  };

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
    glib-networking
    libayatana-appindicator
    openssl
    webkitgtk_4_1
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
  ];

  postInstall = ''
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
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set ASTER_DISABLE_UPDATER 1
      --set ASTER_LAUNCH_COMMAND aster-mail-desktop
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]}
      --prefix PATH : ${
        lib.makeBinPath [
          xdg-utils
          bubblewrap
        ]
      }
    )
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Desktop client for Aster Mail, a private end-to-end encrypted email service";
    homepage = "https://astermail.org";
    changelog = "https://github.com/Aster-Privacy/Aster-Mail/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
    mainProgram = "aster-mail-desktop";
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ findleyl ];
  };
})
