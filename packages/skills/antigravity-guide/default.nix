{
  pkgs,
  mkPiSkill ? (pkgs.callPackage ../../../lib/mk-skill.nix { }),
}:

mkPiSkill {
  name = "antigravity-guide";
  description = "Provides a comprehensive guide, quick reference, and sitemap for Google Antigravity (AGY), CLI, IDE, and customizations.";
  content = ''
    # Google Antigravity (AGY) Quick Reference & Guide

    ## Core Concepts
    - Declarative workstation integration.
    - Clean code, SRP, KISS, and Conventional Commits.
    - Progressive disclosure for skills and tools.
  '';
  meta = {
    description = "Antigravity core guide and reference skill";
  };
}
