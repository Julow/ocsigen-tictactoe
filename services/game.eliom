open%client Js_of_ocaml
open%client Js_of_ocaml_lwt
open%shared Eliom_content.Html

open Shared

let%client client count bus counter_elt incr_button =
  let counter_elt = To_dom.of_element counter_elt in
  let incr_button = To_dom.of_button incr_button in

  (* Client side counter. *)
  let count = ref count in

  let update_counter c =
    count := c;
    counter_elt##.innerText := Js.string (string_of_int c)
  in

  let incr_counter () =
    update_counter (!count + 1);
    Eliom_bus.write bus (Game_state.Set_count !count)
  in

  let handle_msg = function Game_state.Set_count c -> update_counter c in

  Lwt.async (fun () -> Lwt_stream.iter handle_msg (Eliom_bus.stream bus));

  Lwt.async (fun () ->
      Lwt_js_events.clicks incr_button (fun _ _ -> incr_counter ()));
  ()

let run room_name () =
  let state = Game_state.get_game room_name in
  let counter_elt = D.(span [ txt (string_of_int state.count) ]) in
  let incr_button = D.(button [ txt "+1" ]) in
  let _ =
    [%client
      (client ~%state.count ~%state.bus ~%counter_elt ~%incr_button : unit)]
  in
  Lwt.return
    F.(
      html
        (head (title (txt "blibli")) html_common_head)
        (body
           [
             h1 [ txt "Welcome to "; em [ txt "blibli" ]; txt "!" ];
             p [ txt "Count so far: "; counter_elt; txt " "; incr_button ];
           ]))
