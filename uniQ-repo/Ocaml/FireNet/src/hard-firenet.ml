(* netfw_pd: network firewall policy daemon (skeleton)
   Responsibilities:
   - request capability tokens from cryptod for policy changes
   - validate tokens for incoming control plane commands
   - apply data-plane rules locally (fast-path)
   - never hold raw cryptographic secrets
*)

open Lwt.Infix

let main () =
  Lwt_io.printf "netfw_pd skeleton started\n%!"
  >>= fun () ->
  (* TODO:
     - Implement vchan client to cryptod
     - Implement COSE signature verification for tokens
     - Implement a small in-memory rule table + apply hooks for data path
  *)
  let forever, _ = Lwt.wait () in
  forever

let () = Lwt_main.run (main ())
