{
  description = "Modular, production-ready custom packages, extensions, and skills for Pi Coding Agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpi = {
      url = "github:mateusdcc/nixpi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpi,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mkExt = pkgs.callPackage ./lib/mk-extension.nix { };
          mkSkill = pkgs.callPackage ./lib/mk-skill.nix { };
        in
        rec {
          app-screenshot = pkgs.callPackage ./packages/extensions/app-screenshot { mkPiExtension = mkExt; };
          extension-app-screenshot = app-screenshot;

          archify = pkgs.callPackage ./packages/extensions/archify { };

          lazy-archify = pkgs.callPackage ./packages/extensions/lazy-archify {
            mkPiExtension = mkExt;
            archifyPkg = archify;
          };
          extension-lazy-archify = lazy-archify;
          archify-extension = lazy-archify;
          extension-archify = lazy-archify;

          image-tools = pkgs.callPackage ./packages/extensions/image-tools { mkPiExtension = mkExt; };
          extension-image-tools = image-tools;

          subagents = pkgs.callPackage ./packages/extensions/subagents { };
          extension-subagents = subagents;

          mcp-auto-installer = pkgs.callPackage ./packages/extensions/mcp-auto-installer {
            mkPiExtension = mkExt;
          };
          extension-mcp-auto-installer = mcp-auto-installer;

          skill-generative-ui = pkgs.callPackage ./packages/skills/generative-ui { mkPiSkill = mkSkill; };
          skill-agy-customizations = pkgs.callPackage ./packages/skills/agy-customizations {
            mkPiSkill = mkSkill;
          };
          skill-antigravity-guide = pkgs.callPackage ./packages/skills/antigravity-guide {
            mkPiSkill = mkSkill;
          };
        }
      );

      piModules = {
        default = import ./modules;
        extensions = {
          appScreenshot = import ./modules/extensions/app-screenshot.nix;
          lazyArchify = import ./modules/extensions/lazy-archify.nix;
          archify = import ./modules/extensions/lazy-archify.nix;
          imageTools = import ./modules/extensions/image-tools.nix;
          subagents = import ./modules/extensions/subagents.nix;
          mcpAutoInstaller = import ./modules/extensions/mcp-auto-installer.nix;
        };
        skills = {
          generativeUi = import ./modules/skills/generative-ui.nix;
          agyCustomizations = import ./modules/skills/agy-customizations.nix;
          antigravityGuide = import ./modules/skills/antigravity-guide.nix;
        };
      };

      homeModules.default = import ./modules;
      nixosModules.default = import ./modules;
      nixDarwinModules.default = import ./modules;

      overlays.default = final: prev: {
        piPackages = self.packages.${final.stdenv.hostPlatform.system};
      };

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          eval-tests = pkgs.callPackage ./tests/eval-test.nix {
            inherit nixpi self;
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
