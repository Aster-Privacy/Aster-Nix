{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  dbus,
  openssl,
  sqlcipher,
  versionCheckHook,
  nixosTests,
}:

let
  version = "1.0.19";

  bridge-src = fetchFromGitHub {
    owner = "Aster-Privacy";
    repo = "Aster-Bridge";
    tag = "v${version}";
    hash = "sha256-M61a3XcQEfgOht8LpqH6o4nLPwfZeFRz+5vZTSb57mo=";
  };

  mail-src = fetchFromGitHub {
    owner = "Aster-Privacy";
    repo = "Aster-Mail";
    rev = "ab63139964c9ef2600be8ee5f48905fab4341655";
    sparseCheckout = [ "aster-crypto" ];
    hash = "sha256-M8zwMTzTMxwSABsdO4R2Gs4vFXFH4x29N2au0SHLAI4=";
  };
in
rustPlatform.buildRustPackage {
  pname = "aster-bridge-cli";
  inherit version;

  src = bridge-src;
  sourceRoot = "source/src-tauri";

  postUnpack = ''
    cp -r ${mail-src} Aster-Mail
    chmod -R u+w Aster-Mail
  '';

  cargoHash = "sha256-re0CoZSeMymvDj7qwrPoQigBFareFulSENfpXQsgxks=";

  cargoBuildFlags = [
    "--package"
    "aster-bridge-cli"
  ];
  checkType = "debug";
  cargoTestFlags = [
    "--package"
    "aster-bridge-cli"
  ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
    openssl
    sqlcipher
  ];

  env.LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/aster-bridge";

  passthru = {
    inherit mail-src;
    updateScript = ./update.sh;
    tests.nixos = nixosTests.aster-bridge;
  };

  meta = {
    description = "Headless Aster Bridge: local IMAP, SMTP, JMAP, POP3, and CardDAV for Aster Mail";
    homepage = "https://astermail.org";
    changelog = "https://github.com/Aster-Privacy/Aster-Bridge/releases/tag/v${version}";
    license = lib.licenses.agpl3Plus;
    mainProgram = "aster-bridge";
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ findleyl ];
  };
}
