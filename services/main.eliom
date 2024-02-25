open Eliom_content.Html
open Shared

let run ~newgame_service () () =
  Lwt.return
    F.(
      html
        (head (title (txt "blibli")) html_common_head)
        (body
           [
             h1 [ txt "Welcome to "; em [ txt "blibli" ]; txt "!" ];
             p [ a ~service:newgame_service [ txt "Start a new game" ] () ];
           ]))
