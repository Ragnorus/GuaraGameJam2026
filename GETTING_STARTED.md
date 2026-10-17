# Vibe coding THE NIGHT UNC – quick start

No coding experience needed. You describe what you want and Copilot writes the code.

## 1. Install (one time, ~15 min)
1. **GitHub account** – sign up at https://github.com, then ask Ragnorus to add you to the repo.
2. **Git** – https://git-scm.com/downloads (accept the defaults).
3. **VS Code** – https://code.visualstudio.com
4. **Godot 4.5** (standard, not .NET) – https://godotengine.org/download. Unzip it anywhere; no installer needed.
5. In VS Code, sign in with GitHub (person icon, bottom left) and make sure **GitHub Copilot Chat** is enabled (Copilot icon at the top). The free plan works.

## 2. Get the code
1. In VS Code press `Ctrl+Shift+P` (Mac: `Cmd+Shift+P`), type **Git: Clone**, and paste
   `https://github.com/Ragnorus/GuaraGameJam2026`
2. Pick a folder and click **Open** when asked.

## 3. Run the game
Open Godot → **Import** → select `project.godot` in the folder you cloned → **Import & Edit** → press **F5**.
Or just play the live version: https://guaragamejam2026-production.up.railway.app/

## 4. Vibe code
1. Open Copilot Chat (`Ctrl+Alt+I`) and switch the mode to **Agent**.
2. Ask in plain language, for example:
   - "Make the player jump higher."
   - "Add a new mob to Bichema's World that throws mushrooms."
   - "Explain how the score system works."
3. Copilot already knows the game: it reads `.github/copilot-instructions.md` and the skills in `.github/skills/`.
4. Press **F5** in Godot to try the change. If you don't like it, tell Copilot "undo that".

## 5. Share your work
1. Pull first to get everyone else's changes: open **Source Control** (`Ctrl+Shift+G`) → `...` → **Pull**.
2. Type a short message about what you changed → **Commit** → **Sync Changes**.
3. Pushing to `main` updates the live web game in a few minutes. If you're unsure about a change, ask Copilot to "create a branch and open a pull request" instead.

## Tips
- Ask for one small change at a time and test it before asking for the next.
- Never edit or recolor the original art files; ask Copilot to resize or position them instead.
- If something breaks, paste the error into the chat and ask Copilot to fix it.
