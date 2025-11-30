```markdown
# System Architecture — entropyd / cryptod / unlocker / policy_pd / netfw_pd / ivm_pd

Overview
- Six unikernels:
  - entropyd: entropy authority (no secrets)
  - cryptod: cryptographic & policy authority (secrets + decisions)
  - unlocker: operator-facing unlock flow (ephemeral state only)
  - policy_pd: general inter-VM policy enforcement (stateless enforcement)
  - netfw_pd: network firewall policy daemon (data-plane fast, control-plane dumb)
  - ivm_pd: inter-VM policy daemon (enforces cross-VM policies based on cryptod tokens)

Design principles
- cryptod is the single source of authority: issues COSE-signed capability tokens and attestations.
- entropyd only publishes entropy; it does not consume secrets or make decisions.
- Policy daemons are stateless enforcers: they validate cryptod-signed tokens and apply enforcement without holding secret material.
- All RPCs are CBOR/COSE over vchan; messages include version and schema identifiers to permit graceful evolution.

Versioning & schema evolution
- Every message envelope must include:
  - version: integer (schema version)
  - schema: string (e.g., "totp_validate_req", "token_issue_resp")
- Backward compatibility is enforced by cryptod; new fields must be optional and guarded by schema versions.

Operational notes
- Tokens are short-lived (recommended 30s–300s depending on scope).
- cryptod publishes its public keys via signed metadata; clients must fetch and verify the metadata.
- A domain_map (auth/domain_map.json) enumerates assigned DomIDs and expected VM names for local ACLs.

Next steps
- Pick a backend (xen or solo5) and which unikernel to expand first.
- I can implement:
  - cryptod: TOTP validation, COSE token issuance, audit log persistence
  - entropyd: entropy sources, authenticated vchan publication
  - unlocker: interactive TOTP collection and LUKS ephemeral unlock flow
  - policy PDs: COSE token verification, token cache, and enforcement stubs
```
