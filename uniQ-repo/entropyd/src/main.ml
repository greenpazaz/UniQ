open Lwt.Infix

let socket_path = "/tmp/entropyd.sock"

let publish_entropy ~target_socket =
  (* Generate 64 bytes of entropy *)
  let entropy = Mirage_crypto_rng.generate 64 |> Cstruct.to_bytes in
  let cbor = Cbor.encode (`Map [ (`Text "schema"), `Text "entropy_pub"; (`Text "entropy_chunk"), `Bytes (Bytes.of_string entropy); (`Text "timestamp"), `Int (int_of_float (Unix.time ())) ]) in
  (* connect to target_socket and send framed message *)
  let open Lwt_unix in
  let fd = socket PF_UNIX SOCK_STREAM 0 in
  let addr = ADDR_UNIX target_socket in
  connect fd addr >>= fun () ->
  let len = Bytes.length cbor in
  let header = Bytes.create 4 in
  Bytes.set_int32_be header 0 (Int32.of_int len);
  Lwt_unix.write fd (Bytes.to_string header |> Bytes.of_string) 0 4 >>= fun _ ->
  Lwt_unix.write fd cbor 0 len >>= fun _ ->
  Lwt_unix.close fd

let main () =
  (* publish once to cryptod at /tmp/cryptod_entropy.sock or similar *)
  publish_entropy ~target_socket:"/tmp/cryptod_entropy.sock"

let () = Lwt_main.run (main ())
