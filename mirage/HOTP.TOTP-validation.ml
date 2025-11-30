(* otp.ml *)

let load_secret path =
  let ic = open_in path in
  let len = in_channel_length ic in
  let data = really_input_string ic len in
  close_in ic;
  Base64.decode_exn data |> Cstruct.of_string

let totp ~secret =
  let open Mirage_crypto.Hash.SHA1 in
  let time = Unix.gettimeofday () |> int_of_float |> fun t -> t / 30 in
  let msg = Cstruct.create 8 in
  Cstruct.BE.set_uint64 msg 0 (Int64.of_int time);
  let hmac = Mirage_crypto.MAC.hmac (module SHA1) ~key:secret msg in
  let offset = Cstruct.get_uint8 hmac (Cstruct.len hmac - 1) land 0x0F in
  let p = Cstruct.get_uint32 hmac offset land 0x7FFFFFFFl in
  p mod 1_000_000

let validate ~secret user_code =
  let expected = totp ~secret in
  expected = user_code
