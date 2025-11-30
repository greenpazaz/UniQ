(* Minimal policy PD skeleton: request capability tokens and enforce scopes *)
open Lwt.Infix

let () =
  Lwt_main.run (
    Lwt_io.printf "policy_pd skeleton started\n"
  )
