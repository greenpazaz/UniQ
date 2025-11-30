# Capability Token Specification (recommended)

Overview
- Tokens are Compact COSE-signed CWT-like objects (CBOR Web Token)
- Use COSE_Sign1 with ECDSA P-256 (ES256) or EdDSA if available.
- Tokens are issued by cryptod and consumed by policy VMs / unlocker.

Token claims (CBOR map):
- iss (text)       : issuer identifier (cryptod domain id / key id)
- sub (text)       : subject VM id or operator id
- aud (text|list)  : audience(s) — which VMs/services can accept it
- iat (int)        : issued-at (epoch seconds)
- exp (int)        : expiration (short-lived: e.g., 30s–5m)
- nbf (int)        : optional not-before
- jti (text)       : token id (UUID)
- scope (list)     : allowed scopes (e.g., ["luks:unlock", "net:update"])
- nonce (bytes)    : anti-replay nonce from requester
- att (map)        : optional attestation payload (signed by cryptod)
- sig (implicit)   : COSE signature covers the whole CBOR claims

Design notes
- Tokens MUST be short-lived. Prefer 30s–120s for unlock flows; policy tokens may be slightly longer (up to 5m).
- Tokens may embed a hashed capability value (e.g., HMAC or derived key id) instead of raw key material.
- cryptod MUST support token revocation via a revocation list (indexed by jti) and expose a revocation-check mechanism (pushed or queryable) if long-lived tokens are used.

Token exchange pattern (example)
1. Policy VM -> cryptod: token_issue_req (includes nonce + attestation)
2. cryptod validates attestation + ACL, returns token_issue_resp with COSE_Sign1 token
3. Policy VM uses token to perform an action or present to another VM (like unlocker)
4. The recipient validates COSE signature, expiry, scope and nonce.

Key rotation
- cryptod rotates signing keys periodically (e.g., daily/weekly) and publishes new public keys (via a signed metadata object) to all VMs.
- Tokens include a `kid` header indicating which signing key was used.
- Verification must reference the correct public key and accept a small clock skew.

Recommended primitives
- CBOR encoding (RFC 8949)
- COSE_Sign1 (RFC 9052)
- ECDSA P-256 (ES256) or Ed25519 (EdDSA) for compactness and performance

Security considerations
- Never include raw TOTP secrets in tokens.
- If tokens carry encrypted key material, encrypt for the recipient using the recipient's public key and include an integrity tag.
- Always verify nonce + jti anti-replay protections.
