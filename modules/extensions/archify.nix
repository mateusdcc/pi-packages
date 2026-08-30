{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.extensions.archify;
  archifyExtensionPkg = pkgs.callPackage ../../packages/extensions/archify {
    mkPiExtension = pkgs.callPackage ../../lib/mk-extension.nix { };
  };
in
{
  options.programs.pi.extensions.archify = {
    enable = lib.mkEnableOption "Archify lazy-loaded diagramming skill and CLI";

    package = lib.mkOption {
      type = lib.types.package;
      default = archifyExtensionPkg;
      defaultText = lib.literalExpression "pkgs.piExtensions.archify";
      description = "Package providing the Archify lazy-loaded extension.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi = {
      runtimePackages = [
        archifyExtensionPkg.passthru.archifyPackage
        pkgs.nodejs_22
        pkgs.coreutils
        pkgs.jq
      ];

      environment.variables = {
        ARCHIFY_PACKAGE_PATH = "${archifyExtensionPkg.passthru.archifyPackage}";
      };
    };
  };
}
