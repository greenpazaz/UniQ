(* HKDF-Extract / HKDF-Expand (HMAC-SHA256) — safe Cstruct-based implementation.
   Inputs and outputs are Cstruct.t.

   Note: depending on the mirage-crypto version the HMAC symbol path may vary
   (Mirage_crypto.Hash.Hmac.sha256 vs Mirage_crypto.Hash.hmac_sha256). If you
   get an unresolved identifier error, switch to the path provided by your
   installed mirage-crypto package. *)
open Cstruct

let hmac_sha256 ~key data =
  (* Fully-qualified path to HMAC where possible to avoid ambiguous resolution *)
  Mirage_crypto.Hash.Hmac.sha256 ~key data

let extract ~salt ~ikm =
  (* salt: Cstruct.t option, ikm: Cstruct.t *)
  let salt_cs = match salt with
    | None -> Cstruct.create 32  (* RFC 5869: zeros of HashLen if salt absent *)
    | Some s -> s
  in
  hmac_sha256 ~key:salt_cs ikm

let expand ~prk ~info ~len =
  (* prk, info: Cstruct.t; len: int *)
  let hash_len = 32 in
  let n = (len + hash_len - 1) / hash_len in
  if n > 255 then invalid_arg "HKDF expand: too large";
  let rec iter i prev acc =
    if i > n then acc
    else
      let counter = Cstruct.create 1 in
      Cstruct.set_uint8 counter 0 i;
      let t_input = Cstruct.concat [prev; info; counter] in
      let t = hmac_sha256 ~key:prk t_input in
      let acc' =
        if Cstruct.length acc = 0 then t else Cstruct.concat [acc; t]
      in
      iter (i + 1) t acc'
  in
  let ok = iter 1 (Cstruct.create 0) (Cstruct.create 0) in
  Cstruct.sub ok 0 len
