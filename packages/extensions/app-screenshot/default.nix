{
  pkgs,
  mkPiExtension ? (pkgs.callPackage ../../../lib/mk-extension.nix { }),
  fetchFromGitHub ? pkgs.fetchFromGitHub,
}:

mkPiExtension {
  pname = "app-screenshot";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "mateusdcc";
    repo = "pi-app-screenshot";
    rev = "v1.0.0";
    hash = "sha256-b5zsOaGKqcaj5kxBX4MCmP+fEb2NsKxqGHhj9EWYvoc=";
  };

  runtimePackages = with pkgs; [
    nodejs_22
    coreutils
    jq
    ripgrep
    curl
  ];

  meta = {
    description = "High-fidelity native macOS application, desktop, Sketchybar, and browser screenshot capture extension for Pi";
    homepage = "https://github.com/mateusdcc/pi-app-screenshot";
    license = pkgs.lib.licenses.mit;
  };
}
