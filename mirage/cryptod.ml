open Lwt.Syntax

module Main (C: Mirage_console.S) (V: Mirage_vchan.S) = struct

  let mix_entropy () =
    (* Request 64 bytes of entropy from entropyd *)
    match Entropy_client.fetch () with
    | Some e -> Mirage_crypto_rng.reseed e
    | None -> ()

  let derive_key otp_ok =
    (* Derive ephemeral key only if OTP is valid *)
    if not otp_ok then Cstruct.create 0
    else begin
      mix_entropy ();
      let seed = Mirage_crypto_rng.generate 32 in
      Mirage_crypto.KDF.hkdf ~prk:seed ~info:"luks-ephemeral" 32
    end

  let validate_otp ~secret code =
    let expected = TOTP.generate secret in
    expected = code

  let start console vchan =
    let* () = C.log console "cryptod ready" in
    let* server = V.listen ~port:850 vchan in

    let rec serve () =
      (* Receive request from unlocker *)
      let* packet = V.read server in
      let otp_code = Request.decode packet in

      let otp_ok = validate_otp ~secret:Secrets.otp otp_code in
      let key = derive_key otp_ok in

      (* Send ephemeral key or zero buffer *)
      let response = Response.encode key otp_ok in
      let* () = V.write server response in

      (* log event *)
      Audit.log otp_ok;

      serve ()
    in
    serve ()
end

