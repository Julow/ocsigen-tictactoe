open%client Js_of_ocaml
open%client Js_of_ocaml_lwt
open%shared Eliom_content.Html

open! Lwt.Syntax
open Shared

let%shared cell_of_player = function
  | `P1 -> Game_state.Grid.X
  | `P2 -> Game_state.Grid.O

let%shared other_player = function `P1 -> `P2 | `P2 -> `P1

let enter_game state =
  match state.Game_state.state with
  | Waiting_for_player1 ->
      Game_state.set_state state Waiting_for_player2;
      (state.player1, `P1)
  | Waiting_for_player2 ->
      Game_state.set_state state (Turn `P1);
      (state.player2, `P2)
  | _ -> failwith "Game in progress"

(** Change the corresponding cell element to [cell]. *)
let%client set_cell_elt cell_elt cell =
  let txt =
    match cell with Some Game_state.Grid.X -> "X" | Some O -> "O" | None -> ""
  in
  cell_elt##.innerText := Js.string txt

(** Main client code. *)
let%client client state grid server_events current_player player_bus grid_elts =
  let state = ref state and grid = ref grid in

  let cell_clicked x y cell_elt =
    match !state with
    | Game_state.Turn p when p = current_player ->
        set_cell_elt cell_elt (Some (cell_of_player current_player));
        Eliom_bus.write player_bus (Game_state.Click (x, y))
    | _ -> Lwt.return_unit
  in

  let grid_elts =
    (* Setup the click listener on the 9 cells. *)
    Array.mapi
      (fun y row_elts ->
        Array.mapi
          (fun x cell_elt ->
            let cell_elt = To_dom.of_div cell_elt in
            Lwt.async (fun () ->
                Lwt_js_events.clicks cell_elt (fun _ _ ->
                    cell_clicked x y cell_elt));
            cell_elt)
          row_elts)
      grid_elts
  in

  (* The server sends a new grid. *)
  let update_grid g =
    grid := g;
    for x = 0 to 2 do
      for y = 0 to 2 do
        set_cell_elt grid_elts.(y).(x) (Game_state.Grid.get g x y)
      done
    done
  in

  let handle_server_events = function
    | Game_state.State_changed (s, g) ->
        update_grid g;
        state := s
  in

  Lwt.async (fun () -> Lwt_stream.iter handle_server_events server_events);
  ()

(* Handle events from the client on the server side.

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

let run room_name () =
  let state = Game_state.get_game room_name in
  let player_bus, current_player = enter_game state in
  let grid_elts =
    Array.init 3 (fun _ -> Array.init 3 (fun _ -> D.(div [ txt "" ])))
  in

  (* React to client events. *)
  Lwt.async (fun () ->
      Lwt_stream.iter
        (handle_client_events state current_player)
        (Eliom_bus.stream player_bus));

  let _ =
    [%client
      (client ~%(state.state) ~%(state.grid) ~%(state.server_channel)
         ~%current_player ~%player_bus ~%grid_elts
        : unit)]
  in

  Lwt.return
    F.(
      html
        (head (title (txt "blibli")) html_common_head)
        (body
           [
             h1 [ txt "Welcome to "; em [ txt "blibli" ]; txt "!" ];
             div
               ~a:[ a_class [ "grid" ] ]
               [
                 div (Array.to_list grid_elts.(0));
                 div (Array.to_list grid_elts.(1));
                 div (Array.to_list grid_elts.(2));
               ];
           ]))
