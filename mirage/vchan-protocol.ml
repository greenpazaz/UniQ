(* vchan-protocol.ml *)

type unlock_packet = {
  version : int;
  key : Cstruct.t;
}

let serialize p =
  let open Cstruct in
  let version_buf = create 4 in
  BE.set_uint32 version_buf 0 (Int32.of_int p.version);
  let key_len = len p.key in
  let len_buf = create 4 in
  BE.set_uint32 len_buf 0 (Int32.of_int key_len);
  Cstruct.concat [version_buf; len_buf; p.key]
