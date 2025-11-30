(* Updated cryptod main: uses first-class module signer when creating tokens
   and other fixes recommended in the review. *)

open Lwt.Infix
open Cstruct

let rng_string n = Cstruct.to_string (Mirage_crypto_rng.generate n)

let uuid_v4 () =
  let gen = (fun len -> rng_string len) in
  Uuidm.v4_gen gen ()

let read_key path =
  Lwt_io.with_file ~mode:Lwt_io.Input path Lwt_io.read >|= fun s ->
  Cstruct.of_string s

let make_claims_cbor ~iss ~sub ~aud ~scope ~iat ~exp ~jti ~nonce =
  let open Cbor in
  let map = `Map [
    (`Text "iss"), `Text iss;
    (`Text "sub"), `Text sub;
    (`Text "aud"), `Text aud;
    (`Text "scope"), `List (List.map (fun s -> `Text s) scope);
    (`Text "iat"), `Int (Int64.to_int iat);
    (`Text "exp"), `Int (Int64.to_int exp);
    (`Text "jti"), `Text jti;
    (`Text "nonce"), `Bytes (Bytes.of_string nonce)
  ] in
  encode map

let issue_token_proto ~sign_key ~iss ~sub ~aud ~scope ~lifetime_seconds =
  let now = Int64.of_float (Unix.gettimeofday ()) in
  let iat = now in
  let exp = Int64.add now (Int64.of_int lifetime_seconds) in
  let jti = uuid_v4 () |> Uuidm.to_string in
  let nonce = rng_string 16 in
  let claims = make_claims_cbor ~iss ~sub ~aud ~scope ~iat ~exp ~jti ~nonce in
  (* Use HMAC prototype signer module for now *)
  let token_cbor = Cose_sign.sign_cose (module Cose_sign.HmacSigner : Cose_sign.SIGNER) ~key:sign_key ~payload:(Bytes.to_string claims) in
  (token_cbor, jti, exp)

let main () =
  Lwt_io.printf "cryptod (updated) starting\n%!" >>= fun () ->
  (* Load prototype HMAC key from file sealed_key.bin (for prototype only).
     In production, load an Ed25519 private key from sealed storage and use COSE_Sign1. *)
  read_key "sealed_key.bin" >>= fun sign_key ->
  let (token, jti, exp) = issue_token_proto ~sign_key ~iss:"cryptod" ~sub:"unlocker" ~aud:"unlocker" ~scope:["luks:unlock"] ~lifetime_seconds:60 in
  Lwt_io.printf "Issued token (jti=%s) len=%d\n%!" jti (Bytes.length token) >>= fun () ->
  (* Placeholder vchan server loop would be started here *)
  let forever, _ = Lwt.wait () in
  forever

let () = Lwt_main.run (main ())
