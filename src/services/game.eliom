open%client Js_of_ocaml
open%client Js_of_ocaml_lwt
open%shared Eliom_content.Html
open%client Lwt.Syntax

open Html_utils

let%shared cell_of_player = function
  | `P1 -> Game_state.Grid.X
  | `P2 -> Game_state.Grid.O

let%shared other_player = function `P1 -> `P2 | `P2 -> `P1

(** Handle events from the client on the server side.

   The server might decide that the client has done an unlawful move and not
   register it. In this case, [Game_state.notify] is used to send the correct
   state back to the client, which might have updated its model of the game. *)
let handle_client_events state current_player = function
  | Game_state.Click (x, y) -> (
      if
        (* Not the current player turn. *)
        state.Game_state.state <> Turn current_player
      then Game_state.notify state
      else
        let player_cell = cell_of_player current_player in
        match Game_state.Grid.set state.Game_state.grid x y player_cell with
        | exception _ ->
            (* Invalid values for [x] and [y] triggers exceptions. *)
            Game_state.notify state
        | `Winner cell ->
            let cell =
              if cell = player_cell then current_player
              else other_player current_player
            in
            Game_state.set_state state
              (Game_ended (cell :> [ `P1 | `P2 | `Draw ]))
        | `Draw -> Game_state.set_state state (Game_ended `Draw)
        | `Going_on ->
            Game_state.set_state state (Turn (other_player current_player)))
  | Rematch -> (
      match state.Game_state.state with
      | Game_state.Game_ended _ ->
          (* First player to click rematch. *)
          Game_state.set_state state
            (Waiting_for_rematch (other_player current_player))
      | Waiting_for_rematch p when p = current_player ->
          (* Second player to click rematch, start a new game. *)
          Game_state.set_state state
            ~grid:(Game_state.Grid.create ())
            (Turn `P1)
      | _ -> Game_state.notify state)

(* Ask the server to enter the game. Returns [None] if the game is already in
    progress. *)
let%rpc enter_game (room_name : string) :
    ([ `P1 | `P2 ] * (Game_state.client_msg, Game_state.client_msg) Eliom_bus.t)
    option
    Lwt.t =
  let state = Game_sessions.get_game room_name in
  let enter_player player =
    (* Use a bus for client-to-server events instead of a [let%rpc] as the
       closure authenticates the player for free. *)
    let bus = Eliom_bus.create [%json: Game_state.client_msg] in
    Game_sessions.record_player state player bus;
    (* React to client events. *)
    Lwt.async (fun () ->
        Lwt_stream.iter
          (handle_client_events state player)
          (Eliom_bus.stream bus));
    Lwt.return (Some (player, bus))
  in

  match state.Game_state.state with
  | Waiting_for_player1 ->
      Game_state.set_state state Waiting_for_player2;
      enter_player `P1
  | Waiting_for_player2 ->
      Game_state.set_state state (Turn `P1);
      enter_player `P2
  | _ ->
      (* The game do not await new players *)
      Lwt.return None

(* Change the corresponding cell element to [cell]. *)
let%client set_cell_elt cell_elt cell =
  let txt =
    match cell with Some Game_state.Grid.X -> "X" | Some O -> "O" | None -> ""
  in
  cell_elt##.innerText := Js.string txt

(* Update the [grid_elts] according to [grid]. *)
let%client update_grid grid_elts grid =
  for x = 0 to 2 do
    for y = 0 to 2 do
      set_cell_elt grid_elts.(y).(x) (Game_state.Grid.get grid x y)
    done
  done

(* Start the game as a player. *)
let%client player ~state ~grid ~server_events ~player_bus ~current_player
    ~grid_elts ~status_elt ~rematch_button =
  let state = ref state and grid = ref grid in

  let cell_clicked x y cell_elt =
    match !state with
    | Game_state.Turn p when p = current_player ->
        set_cell_elt cell_elt (Some (cell_of_player current_player));
        Eliom_bus.write player_bus (Game_state.Click (x, y))
    | _ -> Lwt.return_unit
  in

  (* Setup the click listener on the 9 cells. *)
  Array.iteri
    (fun y row_elts ->
      Array.iteri
        (fun x cell_elt ->
          Lwt.async (fun () ->
              Lwt_js_events.clicks cell_elt (fun _ _ ->
                  cell_clicked x y cell_elt)))
        row_elts)
    grid_elts;

  let update_status state =
    (* Text to show to the player. [status_attr] is used for styling. *)
    let txt, status_attr =
      match state with
      | Game_state.Waiting_for_player1 -> ("Waiting for player 1", "waiting")
      | Waiting_for_player2 -> ("Waiting for player 2", "waiting")
      | Turn p when p = current_player -> ("It's your turn", "playing")
      | Turn _ -> ("Opponent turn", "waiting")
      | Game_ended ((`P1 | `P2) as p) when p = current_player ->
          ("Victory !", "victory")
      | Game_ended (`P1 | `P2) -> ("You loose :(", "defeat")
      | Game_ended `Draw -> ("Game ended on a draw", "draw")
      | Waiting_for_rematch p when p = current_player ->
          ("Opponent ready for rematch", "playing")
      | Waiting_for_rematch _ -> ("Waiting for opponent", "waiting")
    in

    (* Whether to show the rematch button. *)
    let rematch =
      match state with
      | Game_ended _ -> true
      | Waiting_for_rematch p when p = current_player -> true
      | _ -> false
    in
    rematch_button##.disabled := Js.bool (not rematch);
    status_elt##setAttribute (Js.string "data-status") (Js.string status_attr);
    status_elt##.innerText := Js.string txt
  in

  update_status !state;
  update_grid grid_elts !grid;

  (* [rematch_button] click events. *)
  Lwt.async (fun () ->
      Lwt_js_events.clicks rematch_button (fun _ _ ->
          Eliom_bus.write player_bus Game_state.Rematch));

  (* Listen to server events. *)
  Lwt.async (fun () ->
      Lwt_stream.iter
        (function
          | Game_state.State_changed (s, g) ->
              grid := g;
              state := s;
              update_grid grid_elts g;
              update_status s)
        server_events);
  Lwt.return_unit

(* View an in progress game without interacting. Returns when clicking the play
   button. *)
let%client spectator ~room_name ~state ~grid ~server_events ~grid_elts
    ~status_elt ~play_button =
  let update_status state =
    let play_btn_disabled =
      match state with
      | Game_state.Waiting_for_player1 | Waiting_for_player2 -> false
      | _ -> true
    in
    play_button##.disabled := Js.bool play_btn_disabled;
    let updt ~status txt =
      status_elt##setAttribute (Js.string "data-status") (Js.string status);
      status_elt##.innerText := Js.string txt
    in
    (* Text to show to the spectator. *)
    match state with
    | Game_state.Waiting_for_player1 ->
        updt ~status:"waiting" "Waiting for player 1"
    | Waiting_for_player2 -> updt ~status:"waiting" "Waiting for player 2"
    | Turn _ -> updt ~status:"spectator" "Playing"
    | Game_ended `P1 -> updt ~status:"spectator" "Player 1 wins"
    | Game_ended `P2 -> updt ~status:"spectator" "Player 2 wins"
    | Game_ended `Draw -> updt ~status:"spectator" "Game ended on a draw"
    | _ -> ()
  in

  let return_p, return_u = Lwt.wait () in
  let try_enter_game () =
    (* Enter the game, the server returns [None] if the game is in
       progress. *)
    let+ game = enter_game room_name in
    match game with
    | Some r ->
        play_button##.disabled := Js.bool true;
        Lwt.wakeup_later return_u (`Enter_game r)
    | None -> ()
  in

  update_status state;
  update_grid grid_elts grid;

  (* Normally do not terminate but we need a return value compatible with
     [return_p]. *)
  let listeners =
    let+ () =
      Lwt.pick
        [
          (* Listen to clicks on the play button. *)
          Lwt_js_events.clicks play_button (fun _ _ -> try_enter_game ());
          (* Listen to server events. *)
          Lwt_stream.iter
            (function
              | Game_state.State_changed (s, g) ->
                  update_grid grid_elts g;
                  update_status s)
            server_events;
        ]
    in
    `Exit
  in
  (* Cancel the listeners when returning. *)
  Lwt.pick [ return_p; listeners ]

(* Main client code. *)
let%client client room_name state grid server_events grid_elts status_elt
    play_button rematch_button player_state =
  let status_elt = To_dom.of_span status_elt in
  let play_button = To_dom.of_button play_button in
  let rematch_button = To_dom.of_button rematch_button in

  let grid_elts =
    Array.map
      (fun row_elts ->
        Array.map (fun cell_elt -> To_dom.of_div cell_elt) row_elts)
      grid_elts
  in
  play_button##.disabled := Js.bool true;
  rematch_button##.disabled := Js.bool true;

  let play ~current_player ~player_bus =
    player ~state ~grid ~server_events ~player_bus ~current_player ~grid_elts
      ~status_elt ~rematch_button
  in

  match player_state with
  | Some (current_player, player_bus) ->
      (* Player is already playing on this game. *)
      play ~current_player ~player_bus
  | None -> (
      (* Enter spectator mode until the play button is clicked. *)
      let* r =
        spectator ~room_name ~state ~grid ~server_events ~grid_elts ~status_elt
          ~play_button
      in
      match r with
      | `Enter_game (current_player, player_bus) ->
          play ~current_player ~player_bus
      | `Exit -> Lwt.return_unit)

let run room_name () =
  let state = Game_sessions.get_game room_name in

  let status_elt = D.(span [ txt "" ])
  and play_button =
    D.(button ~a:[ a_class [ "status-btn" ]; a_disabled () ] [ txt "Play" ])
  and rematch_button =
    D.(button ~a:[ a_class [ "status-btn" ]; a_disabled () ] [ txt "Rematch" ])
  and grid_elts =
    (* The sensitive parts of the grid. *)
    Array.init 3 (fun _ -> Array.init 3 (fun _ -> D.(div [ txt "" ])))
  in

  let player_state = Game_sessions.is_player_in_game state in
  let _ =
    [%client
      (client ~%room_name ~%(state.state) ~%(state.grid)
         ~%(state.server_channel) ~%grid_elts ~%status_elt ~%play_button
         ~%rematch_button ~%player_state
        : unit Lwt.t)]
  in

  (* The final HTML grid. *)
  let grid_elts =
    Array.map
      (fun row ->
        F.div (Array.map (fun cell -> F.div [ cell ]) row |> Array.to_list))
      grid_elts
    |> Array.to_list
  in

  Lwt.return
    F.(
      html
        (head (title (txt "blibli")) html_common_head)
        (body
           [
             h1 [ txt "Welcome to "; em [ txt "blibli" ]; txt "!" ];
             div
               ~a:[ a_class [ "game-container" ] ]
               [
                 div
                   ~a:[ a_class [ "status" ] ]
                   [ status_elt; play_button; rematch_button ];
                 div ~a:[ a_class [ "grid" ] ] grid_elts;
               ];
           ]))
