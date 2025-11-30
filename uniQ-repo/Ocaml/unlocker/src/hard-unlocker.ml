open Lwt.Infix

let socket_path = "/tmp/cryptod.sock"

let send_req_and_receive totp_code =
  let open Lwt_unix in
  let fd = socket PF_UNIX SOCK_STREAM 0 in
  let addr = ADDR_UNIX socket_path in
  connect fd addr >>= fun () ->
  (* Build CBOR request: { "schema":"totp_validate_req", "totp_code": bstr } *)
  let req = Cbor.encode (`Map [ (`Text "schema"), `Text "totp_validate_req"; (`Text "totp_code"), `Bytes (Bytes.of_string totp_code) ]) in
  let len = Bytes.length req in
  let header = Bytes.create 4 in
  Bytes.set_int32_be header 0 (Int32.of_int len);
  Lwt_unix.write fd (Bytes.to_string header |> Bytes.of_string) 0 4 >>= fun _ ->
  Lwt_unix.write fd req 0 len >>= fun _ ->
  (* read response frame *)
  let header_r = Bytes.create 4 in
  let rec readn buf off n =
    if n = 0 then Lwt.return_unit else
    Lwt_unix.read fd buf off n >>= fun r ->
    if r = 0 then Lwt.fail End_of_file else readn buf (off + r) (n - r)
  in
  readn header_r 0 4 >>= fun () ->
  let rlen =
    (Char.code (Bytes.get header_r 0) lsl 24) lor
    (Char.code (Bytes.get header_r 1) lsl 16) lor
    (Char.code (Bytes.get header_r 2) lsl 8) lor
    (Char.code (Bytes.get header_r 3))
  in
  let payload = Bytes.create rlen in
  readn payload 0 rlen >>= fun () ->
  Lwt.return payload

let verify_response ~pub_path payload =
  let pub = Cose_ed25519.read_file pub_path in
  (* For prototype, expected_kid = first 8 bytes of pub *)
  let expected_kid = String.sub pub 0 8 in
  let ok = Cose_ed25519.verify_cose_sign1 ~pub_key_bytes:pub ~expected_kid ~cbor_bytes:payload in
  if ok then Lwt_io.printf "UNLOCKER: token verified OK\n" else Lwt_io.printf "UNLOCKER: token verification FAILED\n"

let main argv =
  let totp_code = if Array.length argv > 1 then argv.(1) else "000000" in
  send_req_and_receive totp_code >>= fun payload ->
  verify_response ~pub_path:"/tmp/cryptod_pub.key" payload

let () = Lwt_main.run (main Sys.argv)
