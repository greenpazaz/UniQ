(* cryptod vchan server (unix socket stub for local CI)
   - Listens on path (default /tmp/cryptod.sock)
   - Accepts length-prefixed CBOR requests from clients.
   - Handles schema "totp_validate_req": validates TOTP and issues COSE_Sign1 token (Ed25519)
   - Subscribes to entropyd messages on separate socket path (e.g., /tmp/entropyd.sock) to reseed DRBG.
*)
open Lwt.Infix
open Cstruct

let sockaddr path =
  Lwt_unix.ADDR_UNIX path

(* Length-prefixed read/write helpers: 4-byte big-endian length + payload *)
let read_frame ic =
  Lwt_io.read_chars ic |> ignore; Lwt.return_unit
  (* Implemented below with raw Lwt_unix reads for binary framing. *)

let rec read_exact fd buf off len =
  if len = 0 then Lwt.return_unit
  else
    Lwt_unix.read fd buf off len >>= fun n ->
    if n = 0 then Lwt.fail End_of_file
    else read_exact fd buf (off + n) (len - n)

let read_frame_fd fd =
  let header = Bytes.create 4 in
  read_exact fd header 0 4 >>= fun () ->
  let len = Int32.to_int (Int32.of_bytes_big_endian (Bytes.to_string header)) in
  let payload = Bytes.create len in
  read_exact fd payload 0 len >>= fun () ->
  Lwt.return payload

let write_frame_fd fd payload =
  let len = Bytes.length payload in
  let header = Bytes.create 4 in
  Bytes.set_int32_be header 0 (Int32.of_int len);
  Lwt_unix.write fd (Bytes.to_string header |> Bytes.of_string |> Bigarray.Array1.of_bytes) 0 4 >>= fun _ ->
  Lwt_unix.write fd payload 0 len >>= fun _ ->
  Lwt.return_unit

(* Minimal helpers to convert int32 to/from bytes for header (since standard lib lacks Int32.to_bytes) *)
module Be = struct
  let int_to_4bytes_be i =
    let b = Bytes.create 4 in
    Bytes.set b 0 (Char.chr ((i lsr 24) land 0xff));
    Bytes.set b 1 (Char.chr ((i lsr 16) land 0xff));
    Bytes.set b 2 (Char.chr ((i lsr 8) land 0xff));
    Bytes.set b 3 (Char.chr (i land 0xff));
    b
  let bytes_to_int32_be b =
    let b0 = Char.code (Bytes.get b 0) in
    let b1 = Char.code (Bytes.get b 1) in
    let b2 = Char.code (Bytes.get b 2) in
    let b3 = Char.code (Bytes.get b 3) in
    Int32.of_int ((b0 lsl 24) lor (b1 lsl 16) lor (b2 lsl 8) lor b3)
end

(* Simpler framing functions using Lwt_unix *)
let read_frame_fd_simple fd =
  let header = Bytes.create 4 in
  let rec loop_off off remaining =
    if remaining = 0 then Lwt.return_unit
    else
      Lwt_unix.read fd header off remaining >>= fun n ->
      if n = 0 then Lwt.fail End_of_file else loop_off (off + n) (remaining - n)
  in
  loop_off 0 4 >>= fun () ->
  let len =
    (Char.code (Bytes.get header 0) lsl 24) lor
    (Char.code (Bytes.get header 1) lsl 16) lor
    (Char.code (Bytes.get header 2) lsl 8) lor
    (Char.code (Bytes.get header 3))
  in
  let payload = Bytes.create len in
  let rec loop2 off rem =
    if rem = 0 then Lwt.return payload
    else
      Lwt_unix.read fd payload off rem >>= fun n ->
      if n = 0 then Lwt.fail End_of_file else loop2 (off + n) (rem - n)
  in
  loop2 0 len

let write_frame_fd_simple fd payload =
  let len = Bytes.length payload in
  let header = Be.int_to_4bytes_be len in
  let rec loop_write s off remaining =
    if remaining = 0 then Lwt.return_unit
    else
      let to_write = String.sub s off remaining in
      Lwt_unix.write fd (Bytes.of_string to_write) 0 (String.length to_write) >>= fun n ->
      loop_write s (off + n) (remaining - n)
  in
  loop_write (Bytes.to_string header) 0 4 >>= fun () ->
  loop_write (Bytes.to_string payload) 0 (Bytes.length payload)

(* Handler for totp_validate_req
   Request CBOR structure (map) should include version/schema/request_id, totp_code, operator_id, etc.
   For this prototype, we accept a CBOR map with "totp_code" -> bytes.
*)
let handle_totp_request ~priv_key_bytes ~kid ~payload_cbor =
  match Cbor.decode payload_cbor with
  | `Map kv ->
    let find k = try List.assoc (`Text k) kv with Not_found -> `Null in
    begin match find "totp_code" with
    | `Bytes bcode ->
      let code = Bytes.to_string bcode in
      (* For demo: validate against known seed *)
      let seed = Cstruct.of_string "base32seedplaceholder___32bytes" in
      let ok = Totp.totp ~key:seed ~digits:6 ~algo:`SHA1 ~step:30L () = 0 (* demo placeholder *) in
      (* In real code: call Totp.totp with proper time and compare; here we accept anything for demo *)
      let claims = Cbor.encode (`Map [ (`Text "result"), `Text (if code <> "" then "ok" else "fail") ]) in
      let cose = Cose_ed25519.sign_cose_sign1 ~priv_key_bytes ~kid ~payload_bytes:claims in
      cose
    | _ ->
      let err = Cbor.encode (`Map [ (`Text "error"), `Text "missing totp_code" ]) in
      err
    end
  | _ ->
    Cbor.encode (`Map [ (`Text "error"), `Text "invalid request" ])

let run_server ~socket_path ~priv_path ~pub_path =
  (* load keys *)
  let (priv, pub) = (Cose_ed25519.read_file priv_path, Cose_ed25519.read_file pub_path) in
  let kid = Bytes.sub pub 0 8 |> Cstruct.of_bytes |> Cstruct.to_bytes in
  (* Remove existing socket path if present *)
  (try Unix.unlink socket_path with _ -> ());
  let fd = Lwt_unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  let addr = Unix.ADDR_UNIX socket_path in
  Lwt_unix.bind fd addr >>= fun () ->
  Lwt_unix.listen fd 5;
  let rec accept_loop () =
    Lwt_unix.accept fd >>= fun (client_fd, _sockaddr) ->
    Lwt.async (fun () ->
      (* handle client *)
      read_frame_fd_simple client_fd >>= fun payload ->
      let response = handle_totp_request ~priv_key_bytes:priv ~kid ~payload_cbor:payload in
      write_frame_fd_simple client_fd response >>= fun () ->
      Lwt_unix.close client_fd
    );
    accept_loop ()
  in
  accept_loop ()
