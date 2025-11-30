(* Minimal cryptod skeleton: vchan server + token issuing placeholder.
   Fill in COSE signing, storage, and TOTP validation.
*)
open Lwt.Infix

let () =
  Lwt_main.run (
    (* TODO: initialize vchan listener, load signing keys, accept requests *)
    Lwt_io.printf "cryptod skeleton started\n"
  )
