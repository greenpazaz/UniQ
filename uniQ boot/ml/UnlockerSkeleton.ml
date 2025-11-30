(* Minimal unlocker skeleton: collect operator TOTP and ask cryptod *)
open Lwt.Infix

let () =
  Lwt_main.run (
    Lwt_io.printf "unlocker skeleton started\n"
  )
