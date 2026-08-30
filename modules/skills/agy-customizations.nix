{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.skills.agy-customizations;
  agyCustomizationsPkg = pkgs.callPackage ../../packages/skills/agy-customizations {
    mkPiSkill = pkgs.callPackage ../../lib/mk-skill.nix { };
  };
in
{
  options.programs.pi.skills.agy-customizations = {
    enable = lib.mkEnableOption "Antigravity Customization System guide skill";

    package = lib.mkOption {
      type = lib.types.package;
      default = agyCustomizationsPkg;
      defaultText = lib.literalExpression "pkgs.piSkills.agy-customizations";
      description = "Package providing the agy-customizations skill.";
    };
  };
}
