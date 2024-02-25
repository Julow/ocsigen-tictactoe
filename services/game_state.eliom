(** Store the states of current games. *)

type%shared msg = Set_count of int [@@deriving json]

type%shared t = {
  mutable count : int;
  bus : (msg, msg) Eliom_bus.t;  (** Each games have a associated bus. *)
}

let%shared handle_msg t = function Set_count c -> t.count <- c

let make () =
  let bus = Eliom_bus.create [%json: msg] in
  let t = { count = 0; bus } in

  Lwt.async (fun () -> Lwt_stream.iter (handle_msg t) (Eliom_bus.stream bus));
  t

let games : (string, t) Hashtbl.t = Hashtbl.create 64

let get_game name =
  try Hashtbl.find games name
  with Not_found ->
    let t = make () in
    Hashtbl.add games name t;
    t

let game_counter = ref 0

(** Generate a pseudo random name composed of 5 digits in base 16. *)
let fresh_game_name () =
  incr game_counter;
  let id = Hashtbl.hash !game_counter mod 0xFFFFF in
  Printf.sprintf "%05x" id
