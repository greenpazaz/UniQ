(* ivm_pd: inter-VM policy daemon (skeleton)
   Responsibilities:
   - request and validate capability tokens for inter-VM actions
   - enforce policies that govern cross-VM access (e.g., which VM can attach to which device)
   - remain stateless with respect to secret material
*)

open Lwt.Infix

let main () =
  Lwt_io.printf "ivm_pd skeleton started\n%!"
  >>= fun () ->
  (* TODO:
     - Implement token issuance requests
     - Validate cryptod attestations
     - Provide enforcement hooks for hypervisor/dom0 integration
  *)
  let forever, _ = Lwt.wait () in
  forever

let () = Lwt_main.run (main ())
