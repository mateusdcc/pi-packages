{
  pkgs,
  mkPiExtension ? (pkgs.callPackage ../../../lib/mk-extension.nix { }),
}:

let
  extensionSrc = pkgs.stdenv.mkDerivation {
    pname = "pi-extension-mcp-auto-installer-src";
    version = "1.0.0";
    src = ./.;

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/extensions
      cp extension.js $out/extensions/index.js
      runHook postInstall
    '';
  };
in
mkPiExtension {
  pname = "mcp-auto-installer";
  version = "1.0.0";
  src = extensionSrc;

  runtimePackages = with pkgs; [
    nodejs_22
    coreutils
    jq
    ripgrep
    curl
  ];

  meta = {
    description = "Pi dynamic MCP auto-installer extension: intercepts missing tool calls, searches npm, prompts user, registers tools dynamically, and updates shell.nix";
    homepage = "https://github.com/mateusdcc/pi-packages";
    license = pkgs.lib.licenses.mit;
  };
}
