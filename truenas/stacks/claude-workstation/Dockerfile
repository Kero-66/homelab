# =============================================================================
# Claude Workstation image
# =============================================================================
# A persistent Linux "workstation" for Claude Code Remote Control
# (code.claude.com/docs/en/remote-control). Base recipe adapted from
# Anthropic's own self-hosted-environments-deploy docs (the "Build the runner
# image" section) - that page is for a different, Team/Enterprise-only
# feature we are NOT using, but its Dockerfile pattern for installing the
# `claude` binary is the officially documented one, so it's reused verbatim
# here rather than reinvented.
#
# No git credentials or Infisical auth are baked in here - see entrypoint.sh
# and compose.yaml for how those are loaded at runtime instead.
# =============================================================================

FROM debian:bookworm-slim

ARG CLAUDE_CODE_VERSION=2.1.224

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates openssh-client gnupg \
    && rm -rf /var/lib/apt/lists/*

# Claude Code standalone binary - official release location per Anthropic's
# self-hosted-environments-deploy docs.
RUN curl -fsSL "https://downloads.claude.ai/claude-code-releases/${CLAUDE_CODE_VERSION}/linux-x64/claude" \
      -o /usr/local/bin/claude && chmod +x /usr/local/bin/claude

# Infisical CLI - official install method (infisical.com/docs/cli/overview).
RUN curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | bash \
    && apt-get update && apt-get install -y --no-install-recommends infisical \
    && rm -rf /var/lib/apt/lists/*

RUN git config --system user.name "Claude" \
 && git config --system user.email "noreply@anthropic.com" \
 && git config --system --add safe.directory '*'

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
