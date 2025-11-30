# MirageOS 4‑Unikernel Foundations — entropyd / cryptod / unlocker / policy_pd

What this bundle contains
- protocol/vchan_schema.yaml — message formats for vchan RPCs
- protocol/token_spec.md — capability token (COSE/CWT) specification + signing and validation rules
- auth/auth_model.md — ACLs, trust boundaries, rotation, and threat notes
- xen/*.cfg — Xen domain config snippets for each unikernel
- layout.txt — recommended repo layout for building and evolving the system
- ocaml/* — minimal Mirage/OCaml unikernel skeletons and dune stubs

Goals
- Define clear, minimal RPC schemas so policy unikernels can be built now (stateless, enforcing)
- Ensure cryptod remains the only oracle for secrets + policy decisions
- Define a compact signed capability token format for inter-VM authorization
- Specify port assignments and ACLs so deployments are reproducible

How to proceed
1. Review token_spec.md and auth_model.md to confirm signing formats and lifetimes.
2. Choose a signing primitive for cryptod (COSE with ECDSA P-256 recommended).
3. Expand the cryptod and entropyd OCaml skeletons to implement the crypto, storage, and vchan server logic.
4. Implement verifying clients (unlocker, policy_pd) to validate tokens and attestations.

If you want, I will:
- Expand any unikernel skeleton into a full Mirage unikernel (Xen/solo5 backends)
- Produce dune/mirage/config.ml for your chosen backend
- Provide unit tests and a small harness to simulate vchan messages

Tell me which unikernel to expand first or say "expand all" and I’ll generate full ready-to-build sources.
