open%client Js_of_ocaml
open%client Js_of_ocaml_lwt
open%shared Eliom_content.Html

open Shared

type%shared count = int [@@deriving json]

let bus = Eliom_bus.create [%json: count]

(* Server side counter, updated via [bus]. *)
let count = ref 0
let _ = Lwt_stream.iter (( := ) count) (Eliom_bus.stream bus)

let%client client counter_elt incr_button =
  let counter_elt = To_dom.of_element counter_elt in
  let incr_button = To_dom.of_button incr_button in
  let bus = ~%bus in

  (* Client side counter. *)
  let count = ref !(~%count) in

  let update_counter c =
    count := c;
    counter_elt##.innerText := Js.string (string_of_int c)
  in

  let incr_counter () =
    update_counter (!count + 1);
    Eliom_bus.write bus !count
  in

  Lwt.async (fun () -> Lwt_stream.iter update_counter (Eliom_bus.stream bus));

  Lwt.async (fun () ->
      Lwt_js_events.clicks incr_button (fun _ _ -> incr_counter ()));
  ()

let run () () =
  let counter_elt = D.(span [ txt (string_of_int !count) ]) in
  let incr_button = D.(button [ txt "+1" ]) in
  let _ = [%client (client ~%counter_elt ~%incr_button : unit)] in
  Lwt.return
    F.(
      html
        (head (title (txt "blibli")) html_common_head)
        (body
           [
             h1 [ txt "Welcome to "; em [ txt "blibli" ]; txt "!" ];
             p [ txt "Count so far: "; counter_elt; txt " "; incr_button ];
           ]))
