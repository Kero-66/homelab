AI ideas — integrated secret management options

Purpose
- Capture candidate secret-management approaches for future evaluation and potential integration with the homelab media automation.

Options

1) HashiCorp Vault
- Type: dedicated secrets manager (server or OSS cluster)
- Pros: strong access controls, dynamic secrets, robust audit logging, good CLI/API
- Cons: operational overhead to run Vault, requires bootstrapping and storage backend
- Notes: good fit if you want centralised RBAC and dynamic DB creds.

2) Mozilla SOPS + KMS (GCP/KMS, AWS KMS, Azure Key Vault)
- Type: encrypted secrets in git, keys managed by cloud KMS
- Pros: secrets stored alongside repo encrypted, minimal infra to run, integrates well with CI
- Cons: key management and access policies required, rotation workflow needed
- Notes: pairs well with existing git-based workflows and CI secrets.

3) Cloud provider secrets managers (AWS Secrets Manager / GCP Secret Manager / Azure Key Vault)
- Type: managed cloud secret stores
- Pros: fully managed, integrates with cloud IAM and CI/CD, automatic rotation (optional)
- Cons: cloud lock-in, may be overkill for self-hosted homelab unless running cloud CI

4) GitHub Actions secrets + environment-specific secret stores
- Type: CI-level secrets for deployment pipelines
- Pros: easy to use for GitHub-hosted CI, good for runtime injection during deploy
- Cons: not a runtime secret store for self-hosted services; must combine with local storage for running services

5) Sealed Secrets / External Secrets (Kubernetes-focused)
- Type: Kubernetes native secret controllers
- Pros: great for k8s clusters; encrypted secret manifests stored in git
- Cons: requires Kubernetes — not ideal if using plain Docker/Podman stacks

6) Local `.config/.credentials` with strict gitignore + sample files
- Type: local file-based credentials kept out of git
- Pros: simplest to implement; minimal infra overhead
- Cons: manual handling, less centralisation, backups/rotation require operational discipline

Recommended next step for evaluation
- Short-list Vault and SOPS+KMS for evaluation. Create a simple PoC for each: (a) SOPS with a KMS-backed key to encrypt sample `.env` files, (b) Vault dev-server to store and retrieve a Jellyfin API key via CLI.
- For immediate safety, add tracked sample files (`.env.sample`, `.credentials.sample`) and a `secret_cleanup.md` checklist while the secret-manager decision is pending.

References
- HashiCorp Vault: https://www.vaultproject.io/
- Mozilla SOPS: https://github.com/mozilla/sops
- GitHub Actions secrets: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- AWS Secrets Manager / GCP Secret Manager docs

