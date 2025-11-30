(* COSE_Sign1 (Ed25519) helper.
   - Builds ToBeSigned per RFC8152:
       ToBeSigned = ["Signature1", protected, external_aad, payload]
     where protected is the CBOR-encoded protected header bytes (bstr),
     external_aad is empty bstr.
   - Protected header includes: { 1: alg, 4: kid } where alg = -8 (EdDSA)
   - Kid is a bytes value (opaque key id).
   - Uses mirage-crypto-pk Ed25519 sign/verify where available.
   - Exposes:
       generate_and_save_keypair ~priv_path ~pub_path
       load_keypair ~priv_path ~pub_path
       sign_cose_sign1 ~priv_key_bytes ~kid ~payload_bytes -> cbor_bytes
       verify_cose_sign1 ~pub_key_bytes ~expected_kid ~cbor_bytes -> bool
*)
open Cstruct

(* Use CBOR encoder/decoder (cborg) *)
module CB = Cbor

(* COSE labels: per RFC, alg label = 1, kid label = 4 *)
let alg_label = `Int 1
let kid_label = `Int 4

(* COSE alg value for EdDSA is -8 *)
let eddsa_alg_value = `Int (-8)

(* Build protected header map CBOR -> returns bytes (CBOR bytes) *)
let make_protected_header_bytes ~kid =
  let hdr_map = `Map [
    (alg_label, eddsa_alg_value);
    (kid_label, `Bytes (Cstruct.to_bytes kid))
  ] in
  CB.encode hdr_map

(* Build ToBeSigned array per COSE_Sign1 spec *)
let make_tobesigned ~protected_bytes ~external_aad_bytes ~payload_bytes =
  let protected_bstr = `Bytes protected_bytes in
  let external_bstr = `Bytes external_aad_bytes in
  let payload_bstr = `Bytes payload_bytes in
  CB.encode (`Array [ `Text "Signature1"; protected_bstr; external_bstr; payload_bstr ])

(* Ed25519 sign/verify helpers using mirage-crypto-ec if available.
   If your mirage-crypto package has different modules, adapt these calls.
*)
let ed25519_sign ~priv_key_bytes ~msg_bytes =
  (* priv_key_bytes: raw private key bytes (seed or expanded key depending on API).
     We assume a 32-byte secret key seed here (private key seed). *)
  let priv_cs = Cstruct.of_bytes priv_key_bytes in
  (* The API used below is Mirage_crypto_ec.Ed25519.sign ~key:priv ~msg *)
  (* If the installed API differs, adapt accordingly. *)
  let open Mirage_crypto_ec in
  let priv = Ed25519.priv_of_bytes priv_cs in
  let sig_cs = Ed25519.sign ~key:priv (Cstruct.of_bytes msg_bytes) in
  Cstruct.to_bytes sig_cs

let ed25519_verify ~pub_key_bytes ~msg_bytes ~sig_bytes =
  let pub_cs = Cstruct.of_bytes pub_key_bytes in
  let sig_cs = Cstruct.of_bytes sig_bytes in
  let open Mirage_crypto_ec in
  let pub = Ed25519.pub_of_bytes pub_cs in
  Ed25519.verify ~key:pub (Cstruct.of_bytes msg_bytes) sig_cs

(* Save/load keys as raw bytes *)
let save_file path bytes =
  let oc = open_out_bin path in
  output_string oc bytes;
  close_out oc

let read_file path =
  let ic = open_in_bin path in
  let len = in_channel_length ic in
  let s = really_input_string ic len in
  close_in ic; s

(* Generate Ed25519 keypair (32-byte seed -> 32-byte pubkey) *)
let generate_and_save_keypair ~priv_path ~pub_path =
  let seed = Mirage_crypto_rng.generate 32 |> Cstruct.to_bytes in
  (* derive public key using API *)
  let priv_cs = Cstruct.of_string seed in
  let open Mirage_crypto_ec in
  let priv = Ed25519.priv_of_bytes priv_cs in
  let pub_cs = Ed25519.pub_of_priv priv in
  let pub_b = Cstruct.to_bytes pub_cs in
  save_file priv_path seed;
  save_file pub_path pub_b;
  (seed, pub_b)

let load_keypair ~priv_path ~pub_path =
  let priv = read_file priv_path in
  let pub = read_file pub_path in
  (priv, pub)

(* Create COSE_Sign1 CBOR: { protected: bstr, payload: bstr, signature: bstr }
   For simplicity we return a CBOR map with fields "protected","payload","signature".
   Production: follow exact COSE_Sign1 CBOR structure (tagged) if needed for interop.
*)
let sign_cose_sign1 ~priv_key_bytes ~kid ~payload_bytes =
  let protected = make_protected_header_bytes ~kid in
  let external_aad = Bytes.create 0 in
  let tobe = make_tobesigned ~protected_bytes:protected ~external_aad_bytes:external_aad ~payload_bytes in
  (* Sign tobe *)
  let sig = ed25519_sign ~priv_key_bytes ~msg_bytes:tobe in
  (* Build CBOR envelope *)
  CB.encode (`Map [
    (`Text "protected"), `Bytes protected;
    (`Text "payload"), `Bytes payload_bytes;
    (`Text "signature"), `Bytes sig
  ])

let verify_cose_sign1 ~pub_key_bytes ~expected_kid ~cbor_bytes =
  match CB.decode cbor_bytes with
  | `Map kv ->
    let find key =
      try List.assoc (`Text key) kv with Not_found -> failwith ("missing " ^ key)
    in
    begin match find "protected", find "payload", find "signature" with
    | (`Bytes protected), (`Bytes payload), (`Bytes signature) ->
      (* Check kid in protected header *)
      (match CB.decode protected with
       | `Map ph ->
         begin
           match List.assoc_opt (`Int 4) ph with
           | Some (`Bytes bkid) ->
             if bkid <> expected_kid then false
             else
               let external_aad = Bytes.create 0 in
               let tobe = make_tobesigned ~protected_bytes:protected ~external_aad_bytes:external_aad ~payload_bytes:payload in
               ed25519_verify ~pub_key_bytes ~msg_bytes:tobe ~sig_bytes:signature
           | _ -> false
         end
       | _ -> false)
    | _ -> false
    end
  | _ -> false
