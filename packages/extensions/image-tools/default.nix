{
  pkgs,
  mkPiExtension ? (pkgs.callPackage ../../../lib/mk-extension.nix { }),
  fetchFromGitHub ? pkgs.fetchFromGitHub,
}:

mkPiExtension {
  pname = "image-tools";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "MasuRii";
    repo = "pi-image-tools";
    rev = "b8977bbb4f416fd63db7c7c602db6dfe7b17f62c";
    hash = "sha256-IrcY+FQgbfUkUTVNhne3gWGcw6CmQq1i/rQfO/u4qew=";
  };

  runtimePackages =
    with pkgs;
    [
      nodejs_22
      coreutils
    ]
    ++ pkgs.lib.optional pkgs.stdenv.isDarwin pkgs.pngpaste;

  meta = {
    description = "Pi image tools extension for clipboard image attach and recent image picker";
    homepage = "https://github.com/MasuRii/pi-image-tools";
    license = pkgs.lib.licenses.mit;
  };
}
