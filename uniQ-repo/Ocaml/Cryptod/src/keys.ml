(* Key helper: generate or load keypair for dev.
   Usage:
     dune exec -- ./keys.exe generate --priv sealed_priv.key --pub pub.key
     dune exec -- ./keys.exe show --priv sealed_priv.key --pub pub.key
*)
open Printf

let generate priv_path pub_path =
  let (priv, pub) = Cose_ed25519.generate_and_save_keypair ~priv_path ~pub_path in
  printf "Wrote priv=%s pub=%s\n" priv_path pub_path

let show_keys priv_path pub_path =
  let priv = Cose_ed25519.read_file priv_path in
  let pub = Cose_ed25519.read_file pub_path in
  printf "priv(%d) bytes, pub(%d) bytes\n" (String.length priv) (String.length pub)
