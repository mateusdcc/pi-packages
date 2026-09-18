{
  pkgs,
  mkPiExtension ? (pkgs.callPackage ../../../lib/mk-extension.nix { }),
  archifyPkg ? (pkgs.callPackage ../archify { }),
}:

let
  extensionSrc = pkgs.writeTextDir "extensions/index.js" ''
    import fs from "node:fs";
    import path from "node:path";

    // Lazy prompt injection marker and keyword detector
    const INJECTION_MARKER = "<!-- ARCHIFY_SKILL_INJECTED -->";
    const TRIGGER_PATTERN = /\barchify\b/i;

    const FALLBACK_SKILL_PROMPT = `
    # Archify Diagramming System Directives

    You are requested to generate or validate interactive system diagrams using Archify.

    ## Fast Authoring Path
    1. Choose diagram type: \`architecture\`, \`workflow\`, \`sequence\`, \`dataflow\`, or \`lifecycle\`.
    2. Inspect schema and example files from the Archify package or write a candidate JSON specification.
    3. Author a small, clean JSON specification with at most 12 primary nodes and a clear main path.
    4. Validate the candidate JSON:
       \`archify validate <type> <candidate.json> --quality showcase --json\`
       (Ensure all 9 artifact checks pass with 0 composition errors and 0 warnings).
    5. Deliver the self-contained HTML artifact:
       \`archify deliver <type> <candidate.json> <output.html> --quality showcase --json\`
    6. Optionally run visual check:
       \`archify visual-check <output.html> --json\`

    ## Authoring Invariants
    - Default preset is \`classic\` (dark/light theme preserved).
    - Omit \`meta.subtitle\` unless requested.
    - Responsive first-screen artifact: ensure full viewport containment without overflow.
    - Component types: \`frontend\`, \`backend\`, \`database\`, \`cloud\`, \`security\`, \`messagebus\`, \`external\`.
    - Keep relationship labels concise and semantic.
    `.trim();

    function getSkillPrompt(packageDir) {
      if (packageDir) {
        const skillPath = path.join(packageDir, "lib", "archify", "SKILL.md");
        try {
          if (fs.existsSync(skillPath)) {
            return fs.readFileSync(skillPath, "utf-8").trim();
          }
        } catch {}
      }
      return FALLBACK_SKILL_PROMPT;
    }

    function hasArchifyTrigger(text) {
      if (!text || typeof text !== "string") return false;
      if (text.includes(INJECTION_MARKER)) return false;
      return TRIGGER_PATTERN.test(text);
    }

    function transformPrompt(text, skillPrompt) {
      const header = `''${INJECTION_MARKER}\n[ARCHIFY SYSTEM DIRECTIVE: The user invoked Archify for system diagramming]\n`;
      const cleanPrompt = text.trim();
      return `''${cleanPrompt}\n\n''${header}\n''${skillPrompt}`;
    }

    export default function(pi) {
      if (!pi) return;

      const packageDir = process.env.ARCHIFY_PACKAGE_PATH || "${archifyPkg}";
      const skillPrompt = getSkillPrompt(packageDir);

      // On-demand prompt injection: only inject directives when 'archify' is mentioned
      if (pi.on) {
        pi.on("input", async (event) => {
          if (!hasArchifyTrigger(event?.text)) {
            return { action: "continue" };
          }

          const transformed = transformPrompt(event.text, skillPrompt);
          return {
            action: "transform",
            text: transformed,
            images: event.images,
          };
        });
      }

      if (pi.registerCommand) {
        pi.registerCommand("archify", {
          description: "Invoke Archify skill on-demand for system diagramming",
          handler: async (args, ctx) => {
            const query = (args || "").trim();
            if (!query) {
              ctx?.ui?.notify?.("Usage: /archify <description of system or diagram to create>");
              return;
            }
            if (pi.sendUserMessage) {
              pi.sendUserMessage(`ARCHIFY ''${query}`);
            }
          },
        });
      }
    }
  '';
in
mkPiExtension {
  pname = "lazy-archify";
  version = "2.16.0";
  src = extensionSrc;

  runtimePackages = [
    archifyPkg
    pkgs.nodejs_22
    pkgs.coreutils
    pkgs.jq
  ];

  passthru = {
    archifyPackage = archifyPkg;
  };

  meta = {
    description = "Lazy-loaded Archify diagramming extension: injects diagramming skill prompts on-demand when 'archify' or /archify is used";
    homepage = "https://github.com/tt-a1i/archify";
    license = pkgs.lib.licenses.mit;
  };
}
