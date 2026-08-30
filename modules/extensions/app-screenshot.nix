{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.extensions.app-screenshot;
  appScreenshotPkg = pkgs.callPackage ../../packages/extensions/app-screenshot {
    mkPiExtension = pkgs.callPackage ../../lib/mk-extension.nix { };
  };
in
{
  options.programs.pi.extensions.app-screenshot = {
    enable = lib.mkEnableOption "Pi custom app and desktop screenshot capture extension";

    package = lib.mkOption {
      type = lib.types.package;
      default = appScreenshotPkg;
      defaultText = lib.literalExpression "pkgs.piExtensions.app-screenshot";
      description = "Package providing the app-screenshot extension.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi.runtimePackages = with pkgs; [
      nodejs_22
      coreutils
      jq
      ripgrep
      curl
    ];
  };
}
