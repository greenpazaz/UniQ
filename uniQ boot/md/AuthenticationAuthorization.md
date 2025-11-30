# Authentication & Authorization Model (cryptod-centric)

High-level trust boundaries
- cryptod: single decision and secret authority. Must be small and auditable.
- entropyd: randomness root; no authority over secrets or policy.
- unlocker: operator-facing, ephemeral credentials, transient state only.
- policy_pd: stateless enforcement daemons, never store secrets, only accept cryptod-signed tokens.

ACL & capability rules
- cryptod maintains an ACL mapping: { vm_id -> allowed_scopes }
- All token requests must be accompanied by a nonce and (optionally) machine attestation
- cryptod signs tokens and audit logs
- policy PDs enforce tokens by:
  - verifying COSE signature + kid
  - verifying scope contains requested operation
  - verifying expiration (exp) and not-before (nbf)
  - verifying nonce/jti not previously used for the same vm_id + scope

Attestations
- cryptod can produce attestations for a subject VM with limited lifetime:
  - attest(vm_id, pubkey, action, expires)
- Attestations may be included in requests to prove previous boots or measurements.

Key management
- cryptod has a long-term signing key stored in sealed storage (protected by platform)
- entropyd seeds cryptod's DRBG when available; cryptod maintains a local DRBG plus optional sealed seed
- Key rotation:
  - Generate new signing key pair inside cryptod, publish public key via signed metadata
  - Existing tokens should be short-lived; ensure verifiers accept previous key for a bounded time window

Entropy flow and ACL
- entropyd publishes entropy chunks to an authenticated vchan endpoint
- entropyd only accepts connections from a pre-configured set of DOMIDs/domains
- entropyd does not accept arbitrary requests that could leak secrets

Rate limiting and anti-replay
- cryptod enforces per-device and per-operator rate limits (configurable)
- repeated TOTP failures increment counters stored in cryptod (ephemeral or persistent)
- cryptod emits signed audit_log entries for every authentication attempt

Auditability
- cryptod produces append-only, signed audit records
- audit store should be shippable to an external read-only aggregator (offline review)
- Audit entries include: request_id, actor, action, result, timestamp, metadata, signature

Operational notes
- Production deploys should:
  - Configure a secure channel to fetch cryptod public keys into unlocker and PDs
  - Use platform measures (Xen/PVH attestation or measured boot) to bind domain identities
  - Limit token lifetimes and require fresh attestation for high-sensitivity operations
