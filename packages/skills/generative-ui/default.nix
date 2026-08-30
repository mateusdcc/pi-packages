{
  pkgs,
  mkPiSkill ? (pkgs.callPackage ../../../lib/mk-skill.nix { }),
}:

mkPiSkill {
  name = "generative-ui";
  description = "How to render rich interactive HTML widgets inline in the chat or as standalone artifacts.";
  content = ''
    # Generative UI

    You can render custom, rich, interactive user interfaces (inline widgets or larger artifacts) directly in the chat. This is a great way to communicate complex information to the user, generate rich visualizations, and even create small interactive experiences for the user.

    ## Workflow

    1. **Create the HTML Artifact**: Save a self-contained `.html` file (using Tailwind CSS and inline JavaScript).
    2. **Embed Inline (optional)**: Include the `<agent-embed>` tag in your chat response:
       ```html
       <agent-embed src="file:///<artifact_path>/widget.html"></agent-embed>
       ```

    ## Constraints & Theming

    * **Tailwind CSS**: Use the allowlisted Tailwind script:
      ```html
      <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
      ```
    * **Use Provided Theme Variables**: Surfaces (`--background`, `--content`, `--card`, `--sidebar`), borders (`--border`), text (`--foreground`, `--muted-foreground`), accents (`--primary`, `--secondary`, `--accent`).
    * **HTML Boilerplate**:
      ```html
      <!DOCTYPE html>
      <html>
      <head>
        <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
      </head>
      <body class="bg-transparent text-[var(--foreground)] antialiased p-5">
        <div class="bg-[var(--card)] text-[var(--foreground)] border border-[var(--border)] rounded-xl p-5 shadow-sm">
          <h2 class="text-[var(--foreground)] font-semibold text-lg">Title</h2>
          <p class="text-[var(--muted-foreground)] text-sm">Description</p>
        </div>
      </body>
      </html>
      ```
  '';
  meta = {
    description = "Skill for rendering rich interactive HTML widgets and Tailwind artifacts";
  };
}
