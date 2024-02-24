let html_common_head =
  Eliom_content.Html.F.
    [
      css_link
        ~uri:
          (make_uri
             ~service:(Eliom_service.static_dir ())
             [ "css"; "blibli.css" ])
        ();
    ]
