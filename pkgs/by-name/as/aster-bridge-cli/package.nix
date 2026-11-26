{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  sources = lib.importJSON ./sources.json;
  source =
    sources.assets.${stdenv.hostPlatform.system}
      or (throw "aster-bridge-cli: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "aster-bridge-cli";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/Aster-Privacy/Aster-Bridge/releases/download/v${finalAttrs.version}/aster-bridge-cli-${source.target}.tar.gz";
    inherit (source) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 aster-bridge $out/bin/aster-bridge
    install -Dm644 LICENSE $out/share/licenses/aster-bridge-cli/LICENSE

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/aster-bridge --version | grep -F ${finalAttrs.version}
    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Headless Aster Bridge: local IMAP, SMTP, JMAP, POP3, and CardDAV for Aster Mail";
    homepage = "https://astermail.org";
    changelog = "https://github.com/Aster-Privacy/Aster-Bridge/releases/tag/v${finalAttrs.version}";
    downloadPage = "https://github.com/Aster-Privacy/Aster-Bridge/releases";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "aster-bridge";
    platforms = builtins.attrNames sources.assets;
    maintainers = [ ];
  };
})
