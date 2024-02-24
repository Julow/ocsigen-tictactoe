open%shared Shared

let%shared view room_name () =
  Lwt.return
    Eliom_content.Html.F.(
      html
        (head (title (txt ("blibli room " ^ room_name))) html_common_head)
        (body
           [
             h1
               [ txt "Welcome from Eliom's "; em [ txt "distillery" ]; txt "!" ];
           ]))
