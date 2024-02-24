open Eliom_content.Html
open Shared

let run room_name () =
  Lwt.return
    F.(
      html
        (head (title (txt ("blibli room " ^ room_name))) html_common_head)
        (body
           [
             h1
               [ txt "Welcome from Eliom's "; em [ txt "distillery" ]; txt "!" ];
           ]))
