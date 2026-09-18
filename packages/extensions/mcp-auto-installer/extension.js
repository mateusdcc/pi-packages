import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { Type } from "typebox";

// Active MCP server clients: Map<serverKey, McpClient>
const activeClients = new Map();
// Set of registered tool names
const registeredToolNames = new Set();
// Set of tool names currently being prompted or handled to prevent loop
const pendingPrompts = new Set();

/**
 * Curated aliases for fast matching of common capability queries to high-quality MCP servers.
 */
const CURATED_MCP_MAPPINGS = {
  screenshot: ["chrome-devtools-mcp@latest", "@playwright/mcp@latest"],
  take_screenshot: ["chrome-devtools-mcp@latest", "@playwright/mcp@latest"],
  browser: ["chrome-devtools-mcp@latest", "@playwright/mcp@latest"],
  "chrome-devtools": ["chrome-devtools-mcp@latest"],
  devtools: ["chrome-devtools-mcp@latest"],
  playwright: ["@playwright/mcp@latest"],
  filesystem: ["@modelcontextprotocol/server-filesystem"],
  fetch: ["@modelcontextprotocol/server-fetch"],
  sqlite: ["@modelcontextprotocol/server-sqlite"],
  github: ["@modelcontextprotocol/server-github"],
  postgres: ["@modelcontextprotocol/server-postgres"],
  postgresql: ["@modelcontextprotocol/server-postgres"],
  "sequential-thinking": ["@modelcontextprotocol/server-sequential-thinking"],
  "brave-search": ["@modelcontextprotocol/server-brave-search"],
  puppeteer: ["@modelcontextprotocol/server-puppeteer"],
};

/**
 * Lightweight JSON-RPC Stdio MCP Client
 */
class McpClient {
  constructor(name, command, args, cwd) {
    this.name = name;
    this.command = command;
    this.args = args;
    this.cwd = cwd;
    this.process = null;
    this.nextId = 1;
    this.pendingRequests = new Map();
    this.stdoutBuffer = "";
    this.tools = [];
    this.isReady = false;
  }

  async start() {
    return new Promise((resolve, reject) => {
      try {
        this.process = spawn(this.command, this.args, {
          stdio: ["pipe", "pipe", "inherit"],
          cwd: this.cwd,
          env: {
            ...process.env,
            NODE_NO_WARNINGS: "1",
          },
        });

        this.process.on("error", (err) => {
          reject(new Error(`Failed to spawn MCP server "${this.name}": ${err.message}`));
        });

        this.process.on("exit", (code, signal) => {
          this.isReady = false;
          for (const [id, req] of this.pendingRequests.entries()) {
            req.reject(new Error(`MCP server "${this.name}" exited (code: ${code}, signal: ${signal})`));
          }
          this.pendingRequests.clear();
        });

        this.process.stdout.on("data", (chunk) => {
          this.handleStdoutChunk(chunk);
        });

        // Step 1: Send initialize request
        this.sendRequest("initialize", {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: {
            name: "pi-mcp-auto-installer",
            version: "1.0.0",
          },
        })
          .then(async (initResult) => {
            // Step 2: Send notifications/initialized
            this.sendNotification("notifications/initialized");

            // Step 3: Fetch tools/list
            const toolsResult = await this.sendRequest("tools/list", {});
            this.tools = toolsResult.tools || [];
            this.isReady = true;
            resolve(this.tools);
          })
          .catch((err) => {
            reject(err);
          });
      } catch (err) {
        reject(err);
      }
    });
  }

  handleStdoutChunk(chunk) {
    this.stdoutBuffer += chunk.toString("utf8");
    const lines = this.stdoutBuffer.split("\n");
    this.stdoutBuffer = lines.pop(); // keep partial line

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("Content-Length:")) continue;

      try {
        const msg = JSON.parse(trimmed);
        if (msg.id !== undefined && this.pendingRequests.has(msg.id)) {
          const { resolve, reject, timer } = this.pendingRequests.get(msg.id);
          clearTimeout(timer);
          this.pendingRequests.delete(msg.id);

          if (msg.error) {
            reject(new Error(msg.error.message || JSON.stringify(msg.error)));
          } else {
            resolve(msg.result);
          }
        }
      } catch {
        // Non-JSON logging lines from MCP server
      }
    }
  }

  sendRequest(method, params, timeoutMs = 30000, signal = null) {
    return new Promise((resolve, reject) => {
      if (!this.process || this.process.killed) {
        return reject(new Error(`MCP server "${this.name}" process is not running`));
      }

      const id = this.nextId++;
      const timer = setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error(`MCP request "${method}" (id: ${id}) timed out after ${timeoutMs}ms`));
        }
      }, timeoutMs);

      if (signal) {
        signal.addEventListener(
          "abort",
          () => {
            if (this.pendingRequests.has(id)) {
              clearTimeout(timer);
              this.pendingRequests.delete(id);
              reject(new Error("Operation aborted"));
            }
          },
          { once: true }
        );
      }

      this.pendingRequests.set(id, { resolve, reject, timer });

      const payload = JSON.stringify({
        jsonrpc: "2.0",
        id,
        method,
        params,
      });

      this.process.stdin.write(payload + "\n");
    });
  }

  sendNotification(method, params = {}) {
    if (!this.process || this.process.killed) return;
    const payload = JSON.stringify({
      jsonrpc: "2.0",
      method,
      params,
    });
    this.process.stdin.write(payload + "\n");
  }

  async callTool(toolName, args, signal) {
    return this.sendRequest("tools/call", { name: toolName, arguments: args || {} }, 60000, signal);
  }

  stop() {
    this.isReady = false;
    if (this.process && !this.process.killed) {
      try {
        this.process.kill();
      } catch {}
    }
  }
}

/**
 * Search NPM for candidate MCP packages
 */
async function searchNpm(query) {
  const normalized = query.toLowerCase().replace(/^@/, "").replace(/\/mcp$/, "").trim();
  const candidates = [];

  // Check curated mapping first
  if (CURATED_MCP_MAPPINGS[normalized]) {
    for (const pkg of CURATED_MCP_MAPPINGS[normalized]) {
      candidates.push({
        name: pkg,
        version: "latest",
        description: `Official / Curated MCP package for ${query}`,
        score: 1.0,
      });
    }
  }

  const queries = [
    `mcp ${query}`,
    `${query}-mcp`,
    `@modelcontextprotocol/server-${query}`,
    `mcp-server-${query}`,
    query,
  ];

  for (const q of queries) {
    try {
      const url = `https://registry.npmjs.org/-/v1/search?text=${encodeURIComponent(q)}&size=6`;
      const res = await fetch(url, { signal: AbortSignal.timeout(4000) });
      if (!res.ok) continue;
      const data = await res.json();

      if (data && Array.isArray(data.objects)) {
        for (const item of data.objects) {
          const pkg = item.package;
          if (!pkg || !pkg.name) continue;

          // Filter packages that look like MCP servers
          const nameLower = pkg.name.toLowerCase();
          const descLower = (pkg.description || "").toLowerCase();
          const isMcp =
            nameLower.includes("mcp") ||
            descLower.includes("model context protocol") ||
            descLower.includes("mcp server") ||
            (pkg.keywords && pkg.keywords.includes("mcp"));

          if (isMcp && !candidates.some((c) => c.name === pkg.name)) {
            candidates.push({
              name: pkg.name,
              version: pkg.version || "latest",
              description: pkg.description || "",
              score: item.score?.final || 0.5,
            });
          }
        }
      }
    } catch {
      // Ignore network / timeout issues during query attempts
    }

    if (candidates.length >= 5) break;
  }

  return candidates;
}

/**
 * Find project root (containing shell.nix, flake.nix, or .git)
 */
function findProjectRoot(startDir) {
  let curr = path.resolve(startDir);
  while (true) {
    if (
      fs.existsSync(path.join(curr, "shell.nix")) ||
      fs.existsSync(path.join(curr, "flake.nix")) ||
      fs.existsSync(path.join(curr, ".git"))
    ) {
      return curr;
    }
    const parent = path.dirname(curr);
    if (parent === curr) break;
    curr = parent;
  }
  return startDir;
}

/**
 * Add MCP server configuration to shell.nix if present
 */
function updateShellNix(cwd, serverKey, packageName, args) {
  const projectRoot = findProjectRoot(cwd);
  const shellNixPath = path.join(projectRoot, "shell.nix");

  if (!fs.existsSync(shellNixPath)) {
    return false;
  }

  try {
    const originalContent = fs.readFileSync(shellNixPath, "utf-8");

    // Check if serverKey is already declared
    if (
      originalContent.includes(`"${serverKey}"`) ||
      originalContent.includes(`${serverKey} =`) ||
      originalContent.includes(packageName)
    ) {
      return false; // Already declared
    }

    const formattedArgs = (args || ["-y", packageName])
      .map((a) => `                  "${a}"`)
      .join("\n");

    const serverBlock = `              "${serverKey}" = {
                command = "npx";
                args = [
${formattedArgs}
                ];
              };`;

    let updatedContent = originalContent;

    if (originalContent.includes("mcpServers = {")) {
      updatedContent = originalContent.replace("mcpServers = {", `mcpServers = {\n${serverBlock}`);
    } else if (originalContent.includes("settings = {")) {
      updatedContent = originalContent.replace(
        "settings = {",
        `settings = {\n            mcpServers = {\n${serverBlock}\n            };`
      );
    } else if (originalContent.includes("programs.pi = {")) {
      updatedContent = originalContent.replace(
        "programs.pi = {",
        `programs.pi = {\n          settings = {\n            mcpServers = {\n${serverBlock}\n            };\n          };`
      );
    } else {
      return false;
    }

    if (updatedContent !== originalContent) {
      fs.writeFileSync(shellNixPath, updatedContent, "utf-8");
      return true;
    }
  } catch (err) {
    console.error(`[mcp-auto-installer] Error updating shell.nix: ${err.message}`);
  }

  return false;
}

/**
 * Update .mcp.json or .pi/settings.json if present
 */
function updateLocalConfigFiles(cwd, serverKey, packageName, args) {
  const projectRoot = findProjectRoot(cwd);
  const mcpJsonPath = path.join(projectRoot, ".mcp.json");
  const piSettingsPath = path.join(projectRoot, ".pi", "settings.json");

  const effectiveArgs = args || ["-y", packageName];

  if (fs.existsSync(mcpJsonPath)) {
    try {
      const data = JSON.parse(fs.readFileSync(mcpJsonPath, "utf-8"));
      data.mcpServers = data.mcpServers || {};
      data.mcpServers[serverKey] = {
        command: "npx",
        args: effectiveArgs,
      };
      fs.writeFileSync(mcpJsonPath, JSON.stringify(data, null, 2) + "\n", "utf-8");
    } catch {}
  }

  if (fs.existsSync(piSettingsPath)) {
    try {
      const data = JSON.parse(fs.readFileSync(piSettingsPath, "utf-8"));
      data.mcpServers = data.mcpServers || {};
      data.mcpServers[serverKey] = {
        command: "npx",
        args: effectiveArgs,
      };
      fs.writeFileSync(piSettingsPath, JSON.stringify(data, null, 2) + "\n", "utf-8");
    } catch {}
  }
}

/**
 * Connect an MCP server and register its discovered tools in Pi
 */
async function connectAndRegisterMcpServer(pi, serverKey, packageName, args, cwd, ctx) {
  const effectiveArgs = args && args.length > 0 ? args : ["-y", packageName];
  const client = new McpClient(serverKey, "npx", effectiveArgs, cwd);

  ctx?.ui?.setStatus?.("mcp-install", `Connecting MCP server ${packageName}...`);
  const tools = await client.start();
  ctx?.ui?.setStatus?.("mcp-install", undefined);

  activeClients.set(serverKey, client);

  const newToolNames = [];

  for (const tool of tools) {
    const toolName = tool.name;
    registeredToolNames.add(toolName);
    newToolNames.push(toolName);

    pi.registerTool({
      name: toolName,
      label: toolName,
      description: tool.description || `MCP tool from ${packageName}`,
      parameters: tool.inputSchema || Type.Object({}),
      async execute(toolCallId, params, signal, onUpdate, execCtx) {
        onUpdate?.({ content: [{ type: "text", text: `Executing MCP tool ${toolName}...` }] });
        try {
          const res = await client.callTool(toolName, params, signal);
          let content = [];
          if (res && res.content && Array.isArray(res.content)) {
            content = res.content.map((c) => {
              if (c.type === "text") return { type: "text", text: c.text || "" };
              if (c.type === "image") return { type: "image", data: c.data, mimeType: c.mimeType };
              if (c.type === "resource") return { type: "text", text: JSON.stringify(c.resource) };
              return { type: "text", text: typeof c === "string" ? c : JSON.stringify(c) };
            });
          } else {
            content = [{ type: "text", text: typeof res === "string" ? res : JSON.stringify(res) }];
          }

          return {
            content,
            details: res,
            isError: Boolean(res && res.isError),
          };
        } catch (err) {
          return {
            content: [{ type: "text", text: `Error executing MCP tool "${toolName}": ${err.message}` }],
            details: { error: err.message },
            isError: true,
          };
        }
      },
    });
  }

  // Update shell.nix if in a nix-direnv project
  const shellNixUpdated = updateShellNix(cwd, serverKey, packageName, effectiveArgs);
  updateLocalConfigFiles(cwd, serverKey, packageName, effectiveArgs);

  if (shellNixUpdated) {
    ctx?.ui?.notify?.(`Added "${serverKey}" to shell.nix`, "info");
  }

  ctx?.ui?.notify?.(`Connected MCP server "${serverKey}" (${tools.length} tools registered)`, "info");

  return {
    serverKey,
    packageName,
    tools: newToolNames,
    shellNixUpdated,
  };
}

/**
 * Main Extension Export
 */
export default function (pi) {
  if (!pi) return;

  // Cleanup child MCP server processes on session shutdown
  pi.on?.("session_shutdown", () => {
    for (const [key, client] of activeClients.entries()) {
      try {
        client.stop();
      } catch {}
    }
    activeClients.clear();
  });

  // Intercept missing tool results and auto-install matching MCP server
  pi.on?.("tool_result", async (event, ctx) => {
    if (!event || !event.isError) return;

    const toolName = event.toolName;
    if (!toolName) return;

    // Check if error indicates missing tool
    const contentText = Array.isArray(event.content)
      ? event.content.map((c) => (typeof c === "string" ? c : c.text || "")).join(" ")
      : String(event.content || "");

    const isNotFoundError =
      contentText.includes(`Tool ${toolName} not found`) ||
      contentText.includes(`Tool "${toolName}" not found`) ||
      contentText.toLowerCase().includes("not found");

    if (!isNotFoundError) return;

    // Prevent recursive prompting for the same tool in the same turn
    if (pendingPrompts.has(toolName)) return;
    pendingPrompts.add(toolName);

    try {
      ctx?.ui?.setStatus?.("mcp-search", `Searching NPM for MCP tool "${toolName}"...`);
      const candidates = await searchNpm(toolName);
      ctx?.ui?.setStatus?.("mcp-search", undefined);

      if (!candidates || candidates.length === 0) {
        return;
      }

      let selectedPackage = null;

      if (ctx?.hasUI) {
        if (candidates.length === 1) {
          const top = candidates[0];
          const ok = await ctx.ui.confirm(
            "Install MCP Server?",
            `Tool "${toolName}" is not installed.\nFound MCP package: ${top.name} (${top.description || "No description"})\n\nInstall and connect via npx?`
          );
          if (ok) {
            selectedPackage = top.name;
          }
        } else {
          const choices = candidates.slice(0, 5).map((c) => `${c.name} - ${c.description || ""}`);
          const picked = await ctx.ui.select(
            `Tool "${toolName}" not found. Select an MCP package to auto-install:`,
            [...choices, "Cancel / Do not install"]
          );

          if (picked && !picked.startsWith("Cancel")) {
            selectedPackage = picked.split(" - ")[0].trim();
          }
        }
      } else {
        // In headless mode without UI, default to top candidate if high confidence
        if (candidates.length > 0 && candidates[0].score >= 0.8) {
          selectedPackage = candidates[0].name;
        }
      }

      if (!selectedPackage) {
        return;
      }

      const serverKey = selectedPackage.replace(/^@/, "").replace(/[^a-zA-Z0-9_-]/g, "-").replace(/-mcp$/, "");
      const result = await connectAndRegisterMcpServer(
        pi,
        serverKey,
        selectedPackage,
        ["-y", selectedPackage],
        ctx.cwd,
        ctx
      );

      return {
        content: [
          {
            type: "text",
            text: `[MCP Auto-Installer] Successfully installed and connected "${selectedPackage}".\nConnected tools (${result.tools.length}): ${result.tools.join(", ")}.\n${result.shellNixUpdated ? "Persisted configuration to shell.nix." : ""}\nYou can now execute "${toolName}" or any of the connected tools.`,
          },
        ],
        details: {
          installedPackage: selectedPackage,
          serverKey,
          tools: result.tools,
          shellNixUpdated: result.shellNixUpdated,
        },
        isError: false,
      };
    } catch (err) {
      ctx?.ui?.notify?.(`MCP auto-install failed: ${err.message}`, "error");
    } finally {
      pendingPrompts.delete(toolName);
    }
  });

  // Register explicit `install_mcp` tool
  pi.registerTool?.({
    name: "install_mcp",
    label: "Install MCP Server",
    description:
      "Search, install, and dynamically connect an MCP server package (via npx/npm), register its tools into the running Pi agent, and optionally persist it to shell.nix.",
    promptSnippet: "Install and connect an MCP server package dynamically via npx",
    promptGuidelines: [
      "Use install_mcp when you need capabilities from an MCP server (e.g. chrome-devtools-mcp, playwright, sqlite, filesystem).",
    ],
    parameters: Type.Object({
      query: Type.String({
        description: "Search keyword, capability, or package name (e.g. 'chrome-devtools-mcp', 'screenshot', 'sqlite')",
      }),
      packageName: Type.Optional(
        Type.String({
          description: "Exact npm package name to install directly (e.g. 'chrome-devtools-mcp@latest', '@playwright/mcp@latest')",
        })
      ),
      serverName: Type.Optional(
        Type.String({
          description: "Custom name or key for the MCP server",
        })
      ),
      args: Type.Optional(
        Type.Array(Type.String(), {
          description: "Optional CLI arguments to pass to the MCP server (e.g. ['--headless'])",
        })
      ),
    }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      let targetPackage = params.packageName;

      if (!targetPackage) {
        onUpdate?.({ content: [{ type: "text", text: `Searching npm for "${params.query}"...` }] });
        const candidates = await searchNpm(params.query);

        if (!candidates || candidates.length === 0) {
          return {
            content: [{ type: "text", text: `No MCP packages found for query "${params.query}".` }],
            details: { query: params.query },
            isError: true,
          };
        }

        if (ctx?.hasUI) {
          const choices = candidates.slice(0, 5).map((c) => `${c.name} - ${c.description || ""}`);
          const picked = await ctx.ui.select(
            `Select MCP package to install for "${params.query}":`,
            [...choices, "Cancel"]
          );

          if (!picked || picked === "Cancel") {
            return {
              content: [{ type: "text", text: "Installation cancelled by user." }],
              details: { cancelled: true },
              isError: false,
            };
          }
          targetPackage = picked.split(" - ")[0].trim();
        } else {
          targetPackage = candidates[0].name;
        }
      }

      const serverKey =
        params.serverName ||
        targetPackage.replace(/^@/, "").replace(/[^a-zA-Z0-9_-]/g, "-").replace(/-mcp$/, "");

      onUpdate?.({ content: [{ type: "text", text: `Connecting MCP server "${targetPackage}"...` }] });

      const extraArgs = params.args && params.args.length > 0 ? params.args : ["-y", targetPackage];
      const result = await connectAndRegisterMcpServer(
        pi,
        serverKey,
        targetPackage,
        extraArgs,
        ctx.cwd,
        ctx
      );

      return {
        content: [
          {
            type: "text",
            text: `Successfully connected MCP server "${serverKey}" (${targetPackage}).\nRegistered ${result.tools.length} tool(s): ${result.tools.join(", ")}.\n${result.shellNixUpdated ? "Persisted configuration to shell.nix." : ""}`,
          },
        ],
        details: result,
        isError: false,
      };
    },
  });

  // Register /mcp-install command
  pi.registerCommand?.("mcp-install", {
    description: "Search and install an MCP server package dynamically",
    handler: async (args, ctx) => {
      const query = (args || "").trim();
      if (!query) {
        ctx.ui.notify("Usage: /mcp-install <package-or-keyword> (e.g. /mcp-install chrome-devtools-mcp)", "warning");
        return;
      }

      ctx.ui.setStatus("mcp-search", `Searching for "${query}"...`);
      const candidates = await searchNpm(query);
      ctx.ui.setStatus("mcp-search", undefined);

      if (!candidates || candidates.length === 0) {
        ctx.ui.notify(`No MCP packages found for "${query}"`, "error");
        return;
      }

      const choices = candidates.slice(0, 5).map((c) => `${c.name} - ${c.description || ""}`);
      const picked = await ctx.ui.select(`Select MCP package to install:`, [...choices, "Cancel"]);

      if (!picked || picked === "Cancel") return;
      const pkg = picked.split(" - ")[0].trim();

      const serverKey = pkg.replace(/^@/, "").replace(/[^a-zA-Z0-9_-]/g, "-").replace(/-mcp$/, "");
      await connectAndRegisterMcpServer(pi, serverKey, pkg, ["-y", pkg], ctx.cwd, ctx);
    },
  });

  // Register /mcp-list command
  pi.registerCommand?.("mcp-list", {
    description: "List currently connected dynamic MCP servers and their tools",
    handler: async (_args, ctx) => {
      if (activeClients.size === 0) {
        ctx.ui.notify("No dynamic MCP servers currently connected.", "info");
        return;
      }

      const lines = ["Active MCP Servers:"];
      for (const [key, client] of activeClients.entries()) {
        lines.push(`• ${key} (${client.args.join(" ")}) -> ${client.tools.length} tool(s): ${client.tools.map((t) => t.name).join(", ")}`);
      }

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });
}
