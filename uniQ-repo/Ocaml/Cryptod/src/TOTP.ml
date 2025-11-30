((* RFC-6238 compatible TOTP with safe integer handling and deterministic testing support.
   Functions accept explicit counters (time-step) so unit tests can pass known vectors.
*)

open Cstruct

let counter_to_bytes counter =
  let cs = Cstruct.create 8 in
  for i = 0 to 7 do
    let shift = Int64.(shift_right_logical counter (Int64.of_int ((7 - i) * 8))) in
    Cstruct.set_uint8 cs i (Int64.to_int (Int64.logand shift 0xffL))
  done;
  cs

let hotp ~key ~counter ~digits ~algo =
  let counter_cs = counter_to_bytes counter in
  let h =
    match algo with
    | `SHA1 -> Mirage_crypto.Hash.Hmac.sha1 ~key counter_cs
    | `SHA256 -> Mirage_crypto.Hash.Hmac.sha256 ~key counter_cs
    | `SHA512 -> Mirage_crypto.Hash.Hmac.sha512 ~key counter_cs
  in
  let len = Cstruct.length h in
  let offset = (Cstruct.get_uint8 h (len - 1)) land 0x0f in
  let b0 = Int32.of_int (Cstruct.get_uint8 h offset) in
  let b1 = Int32.of_int (Cstruct.get_uint8 h (offset + 1)) in
  let b2 = Int32.of_int (Cstruct.get_uint8 h (offset + 2)) in
  let b3 = Int32.of_int (Cstruct.get_uint8 h (offset + 3)) in
  let combined =
    Int32.logor
      (Int32.shift_left (Int32.logand b0 0x7Fl) 24)
      (Int32.logor
         (Int32.shift_left (Int32.logand b1 0xFFl) 16)
         (Int32.logor
            (Int32.shift_left (Int32.logand b2 0xFFl) 8)
            (Int32.logand b3 0xFFl)))
  in
  let moddiv = Int32.of_int (int_of_float (10. ** float_of_int digits)) in
  Int32.to_int (Int32.rem combined moddiv)

let totp ~key ?(digits=6) ?(algo=`SHA1) ?(step=30L) ?(time_fn=Unix.gettimeofday) () =
  let now = Int64.of_float (time_fn ()) in
  let counter = Int64.div now step in
  hotp ~key ~counter ~digits ~algo
