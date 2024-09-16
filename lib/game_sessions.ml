(** Game states and user states, server-side. *)

(** {1 Player sessions} *)

let player_sessions : Game_state.player_token Eliom_reference.Volatile.eref =
  let scope = Eliom_common.default_session_scope in
  Eliom_reference.Volatile.eref_from_fun ~scope (fun () -> object end)

(** Whether the current user is a player in the given game. *)
let is_player_in_game game_state =
  (* The current user might be playing several games *)
  let token = Eliom_reference.Volatile.get player_sessions in
  List.find_map
    (fun p ->
      if p.Game_state.player_token == token then Some (p.player, p.player_bus)
      else None)
    game_state.Game_state.players

let record_player (game_state : Game_state.t) player player_bus =
  let player_token = Eliom_reference.Volatile.get player_sessions in
  game_state.players <-
    { player_token; player; player_bus } :: game_state.players

(** {1 In-progress games} *)

let games : (string, Game_state.t) Hashtbl.t = Hashtbl.create 64

let get_game name =
  try Hashtbl.find games name
  with Not_found ->
    let t = Game_state.make () in
    Hashtbl.add games name t;
    t

let game_counter = ref 0

(** Generate a pseudo random name composed of 5 digits in base 16. *)
let fresh_game_name () =
  incr game_counter;
  let id = Hashtbl.hash !game_counter mod 0xFFFFF in
  Printf.sprintf "%05x" id
