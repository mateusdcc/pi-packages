{
  pkgs,
  mkPiSkill ? (pkgs.callPackage ../../../lib/mk-skill.nix { }),
}:

mkPiSkill {
  name = "agy-customizations";
  description = "Comprehensive guide and reference for the Antigravity Customization System (rules, skills, plugins, hooks, MCP).";
  content = ''
    # Antigravity Customization System Guide

    The Antigravity Customization System allows you to tailor the agent's behavior, teach it new workflows, enforce guidelines, and integrate it with external tools.

    ## Customization Types: Quick Reference
    - **Rules** (`GEMINI.md`, `AGENTS.md`): Enforce coding styles, API restrictions, and local guidelines.
    - **Skills** (`skills/<name>/SKILL.md`): Teach multi-step procedures, runbooks, and workflows on demand.
    - **Plugins** (`plugins/<name>/plugin.json`): Package related skills, rules, and MCP configs into a bundle.
    - **Hooks** (`hooks.json`): Run scripts/commands at specific agent lifecycle points.
    - **MCP Servers** (`mcp_config.json`): Connect to external services and custom tool providers.
  '';
  meta = {
    description = "Antigravity Customization System guide skill";
  };
}
