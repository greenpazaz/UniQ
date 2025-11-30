(*
  COSE Signer abstraction — corrected to accept first-class modules and
  to use a constant-time MAC compare for HMAC prototype.

  NOTE: This file provides:
   - SIGNER module type
   - HmacSigner module (prototype) that implements SIGNER
   - sign_cose / verify_cose functions that take (module S : SIGNER)
     allowing clean substitution with an Ed25519 signer module later.
*)

open Cstruct

module type SIGNER = sig
  val sign : key:Cstruct.t -> payload:bytes -> bytes
  val verify : key:Cstruct.t -> payload:bytes -> mac:bytes -> bool
end

(* constant-time byte comparison for Bytes.t *)
let consttime_equal (a:bytes) (b:bytes) : bool =
  let la = Bytes.length a and lb = Bytes.length b in
  if la <> lb then false
  else
    let acc = ref 0 in
    for i = 0 to la - 1 do
      acc := !acc lor (Char.code (Bytes.get a i) lxor Char.code (Bytes.get b i))
    done;
    !acc = 0

module HmacSigner : SIGNER = struct
  open Mirage_crypto.Hash
  let sign ~key ~payload =
    let payload_cs = Cstruct.of_string payload in
    let mac_cs = Hmac.sha256 ~key payload_cs in
    Cstruct.to_bytes mac_cs

  let verify ~key ~payload ~mac =
    let expected = sign ~key ~payload in
    consttime_equal expected mac
end

(* Use CBOR envelope { "payload": bytes, "sig": bytes } for prototype *)
let sign_cose (type a) (module S : SIGNER) ~key ~payload : bytes =
  let open Cbor in
  let sigb = S.sign ~key ~payload in
  let env = `Map [
    (`Text "payload"), `Bytes (Bytes.of_string payload);
    (`Text "sig"), `Bytes sigb
  ] in
  encode env

let verify_cose (type a) (module S : SIGNER) ~key ~cbor_bytes : bool =
  let open Cbor in
  match decode cbor_bytes with
  | `Map kv ->
    let find k = try List.assoc (`Text k) kv with Not_found -> failwith ("missing " ^ k) in
    begin match find "payload", find "sig" with
    | `Bytes payload_b, `Bytes sig_b ->
      let payload = Bytes.to_string payload_b in
      S.verify ~key ~payload ~mac:sig_b
    | _ -> false
    end
  | _ -> false

(* Comments:
   - For prototype this CBOR envelope is sufficient.
   - For production, replace HmacSigner with an Ed25519 signer implementing SIGNER,
     and migrate to a canonical COSE_Sign1 (ToBeSigned) construction with protected headers
     (alg, kid) and the exact byte sequence specified by RFC 8152.
*)
