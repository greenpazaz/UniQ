open Lwt.Syntax

module Main (C: Mirage_console.S) (V: Mirage_vchan.S) = struct
  let start console vchan =
    let* () = C.log console "MirageOS Unlocker Booting..." in

    (* Load OTP secret *)
    let secret = Otp.load_secret "/secrets/otp.secret" in

    (* Ask operator for OTP *)
    let* () = C.log console "Enter OTP:" in
    let* user_entry = C.read_line console in
    let otp_code = int_of_string user_entry in

    if not (Otp.validate ~secret otp_code) then
      let* () = C.log console "OTP INVALID" in
      exit 1
    else
      let* () = C.log console "OTP OK" in

    (* Generate ephemeral unlock key *)
    let key = Keygen.generate () in

    (* Prepare packet *)
    let packet = Vchan_protocol.(serialize { version = 1; key }) in

    (* Connect to dom0 *)
    let* () = C.log console "Connecting to dom0 via vchan..." in
    let* chan = V.connect ~domid:0 ~port:800 vchan in

    (* Transmit key once *)
    let* () = V.write chan packet in

    (* Zeroize key *)
    Mirage_crypto_pk.Rsa.priv_of_cstruct (Cstruct.create 0) |> ignore;

    let* () = C.log console "Key sent — halting." in
    exit 0
end

