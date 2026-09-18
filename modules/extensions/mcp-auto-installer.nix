{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.extensions.mcp-auto-installer;
  mcpAutoInstallerPkg = pkgs.callPackage ../../packages/extensions/mcp-auto-installer {
    mkPiExtension = pkgs.callPackage ../../lib/mk-extension.nix { };
  };
in
{
  options.programs.pi.extensions.mcp-auto-installer = {
    enable = lib.mkEnableOption "Pi dynamic MCP auto-installer extension";

    package = lib.mkOption {
      type = lib.types.package;
      default = mcpAutoInstallerPkg;
      defaultText = lib.literalExpression "pkgs.piExtensions.mcp-auto-installer";
      description = "Package providing the mcp-auto-installer extension.";
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
