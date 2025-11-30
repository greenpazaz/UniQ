(* Corrected Mirage config: build a job for the chosen UNIKERNEL and register it.
   Usage:
     UNIKERNEL=cryptod mirage configure -t xen && make
     UNIKERNEL=entropyd mirage configure -t solo5 && make
*)

open Mirage

let stack = generic_stackv4 default_network

let cryptod = foreign "Unikernel.Cryptod" (console @-> stackv4 @-> job)
let entropyd = foreign "Unikernel.Entropyd" (console @-> stackv4 @-> job)
let unlocker = foreign "Unikernel.Unlocker" (console @-> stackv4 @-> job)
let policy_pd = foreign "Unikernel.Policy_pd" (console @-> stackv4 @-> job)
let netfw_pd = foreign "Unikernel.Netfw_pd" (console @-> stackv4 @-> job)
let ivm_pd = foreign "Unikernel.Ivm_pd" (console @-> stackv4 @-> job)

let job_for name =
  match name with
  | "cryptod" -> cryptod $ default_console $ stack
  | "entropyd" -> entropyd $ default_console $ stack
  | "unlocker" -> unlocker $ default_console $ stack
  | "policy_pd" -> policy_pd $ default_console $ stack
  | "netfw_pd" -> netfw_pd $ default_console $ stack
  | "ivm_pd" -> ivm_pd $ default_console $ stack
  | s -> failwith ("Unknown UNIKERNEL: " ^ s)

let () =
  let target = try Sys.getenv "UNIKERNEL" with Not_found -> "cryptod" in
  let job = job_for target in
  register target [ job ]
