# AI behaviour policy (recorded)

## Purpose

- Record explicit AI behaviour expectations for the repo in an easily discoverable file. This complements `.github/copilot-instructions.md` and `ai/improve_copilot_instructions.md`.

## Rules

### 1) Unanswered questions -> `ai/todo.md`

- If the AI asks a clarifying question and the user does not answer (or indicates "defer"), the AI MUST append the question as an `open` item to `ai/todo.md` with: a concise title, the question, context (files read), suggested next step, and timestamp.
- The AI should then continue only with safe, non-destructive tasks (creating sample files, docs, or proposals) and avoid making irreversible changes.

### 2) External sources -> `ai/reference.md`

- When using external documentation, the AI must append a short reference entry to `ai/reference.md` with the URL and a 1-line reason for use.

### 3) Secrets

- The AI must never populate real secrets. Create `.sample` files (e.g., `.env.sample`, `.credentials.sample`) and document where to put real values.

### 4) Documentation & API First

- Before attempting to modify configuration files or databases directly, the AI MUST attempt to retrieve the official API documentation or Swagger specification from the running service (e.g., `/swagger.json`, `/api/v1/status`).
- Use the API for service status reviews and configuration changes whenever possible to ensure consistency and avoid schema corruption.
- Record canonical API endpoints and Swagger URLs in `ai/reference.md` once discovered.

### 5) Tone & behaviour

- Be concise and direct. Avoid apologies or unnecessary flattery.
- Ask concise clarifying questions when needed.
- If the AI cannot answer, say so and record the sources it consulted.

## Implementation note

- Admins/maintainers should periodically triage `ai/todo.md` and `ai/reference.md` to convert open items into issues or PRs.

