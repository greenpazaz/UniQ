open Printf

let () =
  (* HKDF basic smoke test *)
  let ikm = Cstruct.of_string "inputkeymaterial" in
  let salt = Some (Cstruct.create 32) in
  let prk = Cryptod_hkdf.extract ~salt ~ikm in
  let ok = (Cstruct.length prk) = 32 in
  if not ok then (printf "HKDF extract FAIL\n"; exit 1) else printf "HKDF extract OK\n";
  (* TOTP basic smoke (non-standard seed) *)
  let seed = Cstruct.of_string "12345678901234567890" in
  let code = Cryptod_totp.totp ~key:seed ~digits:8 ~algo:`SHA1 ~step:30L ~time_fn:(fun () -> 59.0) () in
  (* RFC6238 test vector for seed "12345678901234567890" & T=59 -> code 94287082 (8 digits) *)
  if code = 94287082 then printf "TOTP RFC test PASS\n" else (printf "TOTP RFC test FAIL (%d)\n" code; exit 1)
