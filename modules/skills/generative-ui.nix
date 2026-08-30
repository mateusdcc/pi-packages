{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.skills.generative-ui;
  generativeUiPkg = pkgs.callPackage ../../packages/skills/generative-ui {
    mkPiSkill = pkgs.callPackage ../../lib/mk-skill.nix { };
  };
in
{
  options.programs.pi.skills.generative-ui = {
    enable = lib.mkEnableOption "Pi generative UI HTML rendering skill";

    package = lib.mkOption {
      type = lib.types.package;
      default = generativeUiPkg;
      defaultText = lib.literalExpression "pkgs.piSkills.generative-ui";
      description = "Package providing the generative-ui skill.";
    };
  };
}
