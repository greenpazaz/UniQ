(* entropyd.ml *)
open Lwt.Infix

module Main (C: Mirage_console.S) (V: Mirage_vchan.S) = struct

  let jitter () =
    (* Xen timestamp jitter extraction *)
    let t1 = Clock.elapsed_ns () in
    let t2 = Clock.elapsed_ns () in
    let delta = Int64.(sub t2 t1) |> Int64.to_int in
    Cstruct.of_string (string_of_int delta)

  let gather_entropy () =
    let e1 = jitter () in
    let e2 = Mirage_crypto_rng.generate 32 in
    Cstruct.concat [e1; e2]

  let start console vchan =
    let* () = C.log console "entropyd starting…" in
    let* ch = V.listen ~port:900 vchan in

    let rec loop () =
      let entropy = gather_entropy () in
      Mirage_crypto_rng.reseed entropy;
      let out = Mirage_crypto_rng.generate 64 in
      let* () = V.write ch out in
      loop ()
    in
    loop ()
end
