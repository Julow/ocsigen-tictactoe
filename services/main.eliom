open%shared Shared

let%shared view () () =
  Lwt.return
    Eliom_content.Html.F.(
      html
        (head (title (txt "blibli")) html_common_head)
        (body [ h1 [ txt "Welcome to "; em [ txt "blibli" ]; txt "!" ]; p [] ]))
