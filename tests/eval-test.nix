{
  pkgs,
  nixpi,
  self,
}:

let
  lib = pkgs.lib;

  # Test 1: Minimal evaluation with pi-packages modules imported
  emptyEval = nixpi.lib.evalPi {
    inherit pkgs;
    modules = [
      self.piModules.default
      {
        programs.pi.enable = true;
      }
    ];
  };

  # When no extensions enabled, runtime packages should be empty (lazy)
  emptyRuntimePackages = emptyEval.config.programs.pi.finalRuntimePackages;

  # Test 2: Full evaluation with all pi-packages extensions and skills enabled
  fullEval = nixpi.lib.evalPi {
    inherit pkgs;
    modules = [
      self.piModules.default
      {
        programs.pi = {
          enable = true;
          extensions = {
            subagents.enable = true;
            lazy-archify.enable = true;
            image-tools.enable = true;
            app-screenshot.enable = true;
            mcp-auto-installer.enable = true;
          };
          skills = {
            generative-ui.enable = true;
            agy-customizations.enable = true;
            antigravity-guide.enable = true;
          };
        };
      }
    ];
  };

  fullCfg = fullEval.config.programs.pi;

  # Check that runtime packages are correctly populated
  hasGit = lib.any (p: p.pname or p.name == "git") fullCfg.finalRuntimePackages;
  hasNode = lib.any (p: p.pname or p.name == "nodejs") fullCfg.finalRuntimePackages;
  hasPngpaste =
    if pkgs.stdenv.isDarwin then
      lib.any (p: p.pname or p.name == "pngpaste") fullCfg.finalRuntimePackages
    else
      true;
  hasRipgrep = lib.any (p: p.pname or p.name == "ripgrep") fullCfg.finalRuntimePackages;
  hasCurl = lib.any (p: p.pname or p.name == "curl") fullCfg.finalRuntimePackages;

  # Check skills
  hasGenUi = fullCfg.skills ? generative-ui && fullCfg.skills.generative-ui.package != null;
  hasAgyCustom =
    fullCfg.skills ? agy-customizations && fullCfg.skills.agy-customizations.package != null;
  hasAgyGuide =
    fullCfg.skills ? antigravity-guide && fullCfg.skills.antigravity-guide.package != null;

  allPass =
    emptyRuntimePackages == [ ]
    && hasGit
    && hasNode
    && hasPngpaste
    && hasRipgrep
    && hasCurl
    && hasGenUi
    && hasAgyCustom
    && hasAgyGuide;
in
pkgs.runCommand "pi-packages-eval-test" { } ''
  ${lib.optionalString (!allPass) "echo 'pi-packages evaluation test failed' >&2; exit 1"}
  echo "All pi-packages assertions passed" > "$out"
''
