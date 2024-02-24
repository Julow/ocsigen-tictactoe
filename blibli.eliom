let%server application_name = "blibli"
let%client application_name = Eliom_client.get_application_name ()

(* Create a module for the application. See
   https://ocsigen.org/eliom/manual/clientserver-applications for more
   information. *)
module%shared App = Eliom_registration.App (struct
  let application_name = application_name
  let global_data_path = Some [ "__global_data__" ]
end)

(* As the headers (stylesheets, etc) won't change, we ask Eliom not to
   update the <head> of the page when changing page. (This also avoids
   blinking when changing page in iOS). *)
let%client _ = Eliom_client.persist_document_head ()

let%server main_service =
  Eliom_service.create ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit) ()

let%client main_service = ~%main_service
let%shared () = App.register ~service:main_service Main.view

let%server game_service =
  Eliom_service.create ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.(suffix (string "room_name")))
    ()

let%client game_service = ~%game_service
let%shared () = App.register ~service:game_service Game.view
