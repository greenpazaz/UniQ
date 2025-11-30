open Printf

let () =
  (* generate keypair files in /tmp for testing *)
  let priv = "/tmp/test_priv.key" and pub = "/tmp/test_pub.key" in
  let (priv_bytes, pub_bytes) = Cose_ed25519.generate_and_save_keypair ~priv_path:priv ~pub_path:pub in
  let kid = String.sub pub 0 8 |> Cstruct.of_string |> Cstruct.to_bytes in
  let payload = Cbor.encode (`Map [ (`Text "foo"), `Text "bar" ]) in
  let signed = Cose_ed25519.sign_cose_sign1 ~priv_key_bytes:priv_bytes ~kid ~payload_bytes:payload in
  let ok = Cose_ed25519.verify_cose_sign1 ~pub_key_bytes:pub_bytes ~expected_kid:(String.sub pub 0 8) ~cbor_bytes:signed in
  if ok then printf "COSE test PASS\n" else (printf "COSE test FAIL\n"; exit 1)
