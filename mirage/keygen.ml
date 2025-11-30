(* keygen.ml *)

open Lwt.Infix

(* Optional: merge external entropy if provided by a companion unikernel *)
let maybe_mix_external_entropy () =
  match Entropy_channel.fetch () with
  | Some more_entropy ->
      Mirage_crypto_rng.reseed more_entropy
  | None ->
      ()

let generate () =
  (* Mix any external entropy source before final keygen *)
  maybe_mix_external_entropy ();

  (* Use MirageOS’s secure RNG — safe on Xen *)
  Mirage_crypto_rng.generate 32
