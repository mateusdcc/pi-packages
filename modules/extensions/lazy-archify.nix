{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.extensions.lazy-archify;
  aliasCfg = config.programs.pi.extensions.archify;
  enabled = cfg.enable || aliasCfg.enable;

  lazyArchifyPkg = pkgs.callPackage ../../packages/extensions/lazy-archify {
    mkPiExtension = pkgs.callPackage ../../lib/mk-extension.nix { };
  };
in
{
  options.programs.pi.extensions = {
    lazy-archify = {
      enable = lib.mkEnableOption "Lazy-loaded Archify diagramming extension (injects diagramming directives on-demand when 'archify' or /archify is used)";

      package = lib.mkOption {
        type = lib.types.package;
        default = lazyArchifyPkg;
        defaultText = lib.literalExpression "pkgs.piExtensions.lazy-archify";
        description = "Package providing the lazy-archify extension.";
      };
    };

    archify = {
      enable = lib.mkEnableOption "Alias for lazy-archify extension";
    };
  };

  config = lib.mkIf enabled {
    programs.pi = {
      runtimePackages = [
        lazyArchifyPkg.passthru.archifyPackage
        pkgs.nodejs_22
        pkgs.coreutils
        pkgs.jq
      ];

      environment.variables = {
        ARCHIFY_PACKAGE_PATH = "${lazyArchifyPkg.passthru.archifyPackage}";
      };
    };
  };
}
