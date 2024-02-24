module%shared _ = Main
module%shared _ = Game
module%shared _ = Shared

let%server application_name = "blibli"
let%client application_name = Eliom_client.get_application_name ()

module%shared App = Eliom_registration.App (struct
  let application_name = application_name
  let global_data_path = None
end)

(* As the headers (stylesheets, etc) won't change, we ask Eliom not to
   update the <head> of the page when changing page. (This also avoids
   blinking when changing page in iOS). *)
let%client _ = Eliom_client.persist_document_head ()

let%server main_service =
  Eliom_service.create ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit) ()

let%server () = App.register ~service:main_service Main.run

let%server game_service =
  Eliom_service.create ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.(suffix (string "room_name")))
    ()

let%server () = App.register ~service:game_service Game.run
