# pi-packages

Modular, production-ready custom packages, extensions, and AI agent skills for the [Pi coding agent](https://github.com/badlogic/pi-mono) and [nixpi](https://github.com/mateusdcc/nixpi).

[![CI](https://github.com/mateusdcc/pi-packages/actions/workflows/ci.yml/badge.svg)](https://github.com/mateusdcc/pi-packages/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Why pi-packages

- **Zero Clutter & 100% Lazy Evaluation**: Only builds and loads the extensions and runtime dependencies you explicitly enable in your configuration.
- **No Git Submodules or Monorepo Bloat**: Upstream packages are fetched securely from GitHub tarballs via Nix with cryptographic hashes.
- **Production-Ready & Fully Typed**: Works directly in any project's `shell.nix`, `flake.nix` devShell, Home Manager, NixOS, or nix-darwin configuration.

---

## Catalog

### Extensions

| Extension | Module Option | Upstream Source | Description |
| :--- | :--- | :--- | :--- |
| **subagents** | `programs.pi.extensions.subagents.enable` | [`nicobailon/pi-subagents`](https://github.com/nicobailon/pi-subagents) | Single-agent delegation and scripted multi-agent workflows. Automatically packages `nodejs_22`, `git`, `jq`, `ripgrep`, `coreutils`. |
| **lazy-archify** | `programs.pi.extensions.lazy-archify.enable` | [`tt-a1i/archify`](https://github.com/tt-a1i/archify) | **On-Demand Diagramming Injection**: Monitors user inputs and only injects the Archify diagramming skill directive into context when `archify` or `/archify` is explicitly triggered. Wraps the upstream `archify` CLI. |
| **image-tools** | `programs.pi.extensions.image-tools.enable` | [`MasuRii/pi-image-tools`](https://github.com/MasuRii/pi-image-tools) | Clipboard image attach and recent image picker (`pngpaste`). |
| **app-screenshot** | `programs.pi.extensions.app-screenshot.enable` | [`mateusdcc/pi-app-screenshot`](https://github.com/mateusdcc/pi-app-screenshot) | Native macOS application window, full screen, and headless browser capture. |
| **mcp-auto-installer** | `programs.pi.extensions.mcp-auto-installer.enable` | Local / In-tree | Intercepts missing tool calls, searches npm, prompts user, dynamically connects MCP servers, and persists configs to `shell.nix`. |

### Skills

| Skill | Module Option | Description |
| :--- | :--- | :--- |
| **generative-ui** | `programs.pi.skills.generative-ui.enable` | Interactive Tailwind CSS HTML widgets and generative UI styling. |
| **agy-customizations** | `programs.pi.skills.agy-customizations.enable` | Antigravity Customization System guide (rules, skills, plugins, hooks, MCP). |
| **antigravity-guide** | `programs.pi.skills.antigravity-guide.enable` | Antigravity core guide and reference. |

---

## How `lazy-archify` Works

Standard agent skills pre-load large prompt runbooks into the agent's context window on every turn, consuming precious tokens even when no diagramming is requested.

`lazy-archify` solves this via on-demand prompt injection:
1. It listens to user message inputs.
2. If the user input mentions `archify` or triggers `/archify`, it dynamically injects the Archify system diagramming specification into that turn's prompt context.
3. If `archify` is not mentioned, zero skill tokens are added to the conversation.
4. It provides the upstream `archify` binary in the agent's PATH for automated diagram validation and delivery (`archify validate`, `archify deliver`).

---

## Quick Start

### 1. In any project `flake.nix` (devShell)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpi.url = "github:mateusdcc/nixpi";
    pi-packages = {
      url = "github:mateusdcc/pi-packages";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpi.follows = "nixpi";
    };
  };

  outputs = { self, nixpkgs, nixpi, pi-packages }:
    let
      system = "aarch64-darwin"; # or "x86_64-linux", "aarch64-linux", "x86_64-darwin"
      pkgs = nixpkgs.legacyPackages.${system};

      customPi = nixpi.lib.makePi {
        inherit pkgs;
        modules = [
          pi-packages.piModules.default
          {
            programs.pi = {
              extensions = {
                subagents.enable = true;
                lazy-archify.enable = true;
                image-tools.enable = true;
                app-screenshot.enable = true;
              };
              skills = {
                generative-ui.enable = true;
              };
            };
          }
        ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ customPi ];
      };
    };
}
```

### 2. In a classic `shell.nix`

```nix
{ pkgs ? import <nixpkgs> {} }:

let
  nixpi = builtins.getFlake "github:mateusdcc/nixpi";
  pi-packages = builtins.getFlake "github:mateusdcc/pi-packages";

  customPi = nixpi.lib.makePi {
    inherit pkgs;
    modules = [
      pi-packages.piModules.default
      {
        programs.pi = {
          extensions = {
            subagents.enable = true;
            lazy-archify.enable = true;
            image-tools.enable = true;
            app-screenshot.enable = true;
          };
        };
      }
    ];
  };
in
pkgs.mkShell {
  packages = [ customPi ];
}
```

### 3. In Home Manager, NixOS, or nix-darwin

Add `pi-packages` to your flake inputs and import `pi-packages.homeModules.default`:

```nix
{
  imports = [
    nixpi.homeModules.default
    pi-packages.homeModules.default
  ];

  programs.pi = {
    enable = true;

    extensions = {
      subagents.enable = true;
      lazy-archify.enable = true;
      image-tools.enable = true;
      app-screenshot.enable = true;
    };

    skills = {
      generative-ui.enable = true;
    };
  };
}
```

---

## Development & Verification

```console
nix flake check -L
```

---

## License

MIT © [Mateus](LICENSE)
