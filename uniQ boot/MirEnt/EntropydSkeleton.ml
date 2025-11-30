(* Minimal entropyd skeleton: publish entropy chunks on vchan *)
open Lwt.Infix

let () =
  Lwt_main.run (
    Lwt_io.printf "entropyd skeleton started\n"
  )
