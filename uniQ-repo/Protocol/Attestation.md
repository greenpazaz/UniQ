```markdown
# Attestation Spec

Purpose
- Define a minimal attestation format used across vchan messages to prove VM identity/measurement to cryptod and other verifiers.

Format (CBOR map)
- version (int)           : attestation schema version (start at 1)
- subject (text)         : VM identifier (canonical)
- subject_pubkey (bytes) : subject ephemeral or persistent public key (PEM/DER bytes)
- measurement (bytes?)   : optional measurement digest (e.g., measured boot PCR-like)
- vm_metadata (map?)     : optional metadata (kernel version, unikernel version)
- nonce (bytes)          : requester-provided nonce to bind attestation to a request
- issued_at (int)        : epoch seconds
- expires_at (int)       : epoch seconds
- signature (bytes)      : cryptod COSE_Sign1 over the CBOR attestation map

Attestation use cases
- Token issuance requests: cryptod may require an attestation before issuing certain scopes.
- Chained attestations: cryptod can sign attestations for a subject to be presented later (e.g., to remote HW devices).
- Verifiers MUST validate:
  - signature is from a trusted cryptod key
  - nonce matches the request nonce (anti-replay)
  - expiry and issued_at bounds
  - measurement if required by policy

Rotation and validation
- cryptod rotates attestation signing keys occasionally; attestations include a `kid` header to identify the signing key.
- Verifiers should accept recent previous signing keys for a bounded overlap window to accomodate rotation.
