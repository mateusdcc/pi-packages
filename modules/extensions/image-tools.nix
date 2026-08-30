{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.extensions.image-tools;
  imageToolsPkg = pkgs.callPackage ../../packages/extensions/image-tools {
    mkPiExtension = pkgs.callPackage ../../lib/mk-extension.nix { };
  };
in
{
  options.programs.pi.extensions.image-tools = {
    enable = lib.mkEnableOption "Pi image tools extension for clipboard image attach and recent image picker";

    package = lib.mkOption {
      type = lib.types.package;
      default = imageToolsPkg;
      defaultText = lib.literalExpression "pkgs.piExtensions.image-tools";
      description = "Package providing the pi-image-tools extension.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi.runtimePackages = with pkgs; [
      pngpaste
    ];
  };
}
