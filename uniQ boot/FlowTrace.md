```text name=flow/flow_trace.md
# End-to-End Flow Trace (TOTP → cryptod → tokens → policy → enforcement)

Legend:
- U: Unlocker (operator-facing)
- C: cryptod (authority)
- E: entropyd (entropy provider)
- PD: policy_pd (inter-VM policy)
- NF: netfw_pd (network policy)
- vchan: CBOR/COSE over vchan channel

Sequence (high-level):

1) Boot & Boottime Measurements
   - entropyd starts, seeds its DRBG, publishes initial entropy to cryptod (vchan: entropy_pub).
   - cryptod loads sealed signing keys, seeds its DRBG with entropyd entropy.
   - cryptod publishes its public key metadata (signed) to a local read-only location.

2) Operator requests unlock:
   - (U) Prompt operator for TOTP -> operator enters TOTP code X.
   - (U) Builds totp_validate_req message:
       { version:1, schema:"totp_validate_req", request_id: UUID, operator_id, device_id, totp_code:X, client_nonce, timestamp, attestation? }
   - (U) Sends totp_validate_req -> (C) via vchan.

3) cryptod validates TOTP:
   - (C) Verifies request format, nonce, and optional unlocker attestation.
   - (C) Validates TOTP code using stored seed (and drift window).
   - (C) Enforces rate-limits / replay protection.
   - On success:
       - (C) Derives ephemeral unlock key (HKDF with fresh entropy + seeding).
       - (C) Issues capability token (COSE signed or COSE-MAC) scoped to "luks:unlock" and targeted to unlocker (aud=unlocker), short expiry.
       - (C) Emits audit_log entry (signed) with request_id, actor, action, result.

4) Unlocker receives response:
   - (U) Verifies cryptod signature on token, checks expiry & scope.
   - (U) Uses token (or ephemeral_key) to perform LUKS unlock or to retrieve ephemeral decryption secret from cryptod encrypting to unlocker pubkey.
   - (U) Zeroes ephemeral state post-unlock. Emits local audit if desired.

5) Policy daemon flows (PD, NF, IVM)
   - (PD) To perform sensitive policy change (e.g., add an inter-VM rule), PD -> (C) sends token_issue_req including its attestation & nonce.
   - (C) Validates the attestation and ACL, issues a scoped capability token (e.g., ["net:modify"]) signed by cryptod.
   - (PD) Presents the token to the intended enforcer (NF or IVM); enforcer verifies signature, scope, expiry, and then applies state changes.
   - All actions produce signed audit_log entries emitted by cryptod or locally signed attestations when needed.

6) Revocation & Rotation
   - cryptod maintains a revocation list (index by jti) for issued tokens.
   - cryptod rotates signing keys and publishes signed metadata; verifiers accept previous keys for a small overlap window.

ASCII diagram:

     entropyd --(entropy_pub)--> cryptod
                                   |
            operator -> unlocker --(totp_req)--> cryptod
                                   |
                                   +--(signed_token)--> unlocker --(use)-> LUKS unlock
                                   |
                    policy_pd/netfw_pd/ivm_pd --(token_issue_req)--> cryptod
                                   |
                                   +--(signed_token)--> policy_pd/netfw_pd/ivm_pd (enforce)
```

Now the expanded cryptod implementation (prototype)
- Uses HMAC-based COSE-MAC0-style tokens as a readable prototype. This is easy to verify, compact, auditable, and safe as a prototype. The structure is modular so you can replace HMAC with Ed25519/ES256 signing in the COSE module later.

