```ocaml name=ocaml/cryptod/src/cose_hmac.ml
(** Minimal COSE-MAC0-like helper using HMAC-SHA256 as prototype
    Produces a CBOR map:
    { payload: <CBOR bytes>, mac: <HMAC-SHA256 over protected | payload> }
    This is NOT a full COSE implementation, but a safe prototype.
*)

open Mirage_crypto.Hash
open Cstruct
open Cbor

let hmac_sha256 ~key data =
  Hmac.sha256 ~key data

let make_token ~key ~claims_cbor =
  (* claims_cbor: bytes (CBOR-encoded payload) *)
  let protected = Cbor.encode (`Map []) in
  let to_mac = Bytes.concat Bytes.empty [protected; claims_cbor] in
  let mac = hmac_sha256 ~key (Cstruct.of_bytes to_mac) in
  (* return a simple CBOR envelope: { "payload": <claims>, "mac": hmac } *)
  let env = `Map [
    (`Text "payload"), `Bytes (Bytes.of_string claims_cbor);
    (`Text "mac"), `Bytes (Cstruct.to_bytes mac)
  ] in
  Cbor.encode env
```
