# Decisions and changes

- Use existing Windows R 4.6.1 and project-local commands; do not change global R/PATH settings.
- Override invalid C.UTF-8 locale with C for the R child process only, record both the warning and remedy.
- Use paper_contract, nhanes_data, simulation as separate working agents; root owns environment, analysis code, integration and existing-document updates.
- Freeze arithmetic-mean/Welch educational comparison before inspecting new participant outcomes; report other required methods without selecting the smallest p-value.
- If complete FI coding cannot be established, preserve uncertainty and label any reconstructed FI as a candidate. Do not substitute a short FI or simulate actual NHANES outcomes.
- No automatic full-document build: existing generator overwrites Obsidian notes. Append controlled result blocks to both existing source and corresponding notes instead.

## 2026-09-28: active protocol v2
- Canonical execution prompt: frailty-agent-workflow/docs/05-prompts.md.
- Canonical learning edits: existing Obsidian learning folder. frailty-learning/source is an optional reviewed mirror.
- Existing v1 workflow/tasks/validation remain historical; no claim that they enforce v2.
- Contract examples and structural negative tests are illustrative, not live agent execution or statistical validation.
- No migration of historical run statuses or claims of author-identical FI.

