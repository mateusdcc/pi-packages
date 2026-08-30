{
  pkgs,
  mkPiExtension ? (pkgs.callPackage ../../../lib/mk-extension.nix { }),
  fetchFromGitHub ? pkgs.fetchFromGitHub,
}:

mkPiExtension {
  pname = "app-screenshot";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "mateusdcc";
    repo = "pi-app-screenshot";
    rev = "v1.1.0";
    hash = "sha256-aMixo+kyMu3y1Tl5zb8WaF4IDQkUkrFwYtVnQ2U029U=";
  };

  runtimePackages = with pkgs; [
    nodejs_22
    coreutils
    jq
    ripgrep
    curl
  ];

  meta = {
    description = "Native macOS application window, full screen, and headless browser screenshot capture extension for Pi";
    homepage = "https://github.com/mateusdcc/pi-app-screenshot";
    license = pkgs.lib.licenses.mit;
  };
}
