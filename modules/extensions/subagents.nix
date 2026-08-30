{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.extensions.subagents;
  subagentsPkg = pkgs.callPackage ../../packages/extensions/subagents { };
in
{
  options.programs.pi.extensions.subagents = {
    enable = lib.mkEnableOption "Pi subagents extension for single-agent delegation and scripted multi-agent workflows";

    package = lib.mkOption {
      type = lib.types.package;
      default = subagentsPkg;
      defaultText = lib.literalExpression "pkgs.piExtensions.subagents";
      description = "Package providing the pi-subagents extension.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi.runtimePackages = with pkgs; [
      nodejs_22
      coreutils
      git
      jq
      ripgrep
    ];
  };
}
