{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.programs.pi.skills.antigravity-guide;
  antigravityGuidePkg = pkgs.callPackage ../../packages/skills/antigravity-guide {
    mkPiSkill = pkgs.callPackage ../../lib/mk-skill.nix { };
  };
in
{
  options.programs.pi.skills.antigravity-guide = {
    enable = lib.mkEnableOption "Antigravity core guide and reference skill";

    package = lib.mkOption {
      type = lib.types.package;
      default = antigravityGuidePkg;
      defaultText = lib.literalExpression "pkgs.piSkills.antigravity-guide";
      description = "Package providing the antigravity-guide skill.";
    };
  };
}
