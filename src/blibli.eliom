module%shared _ = Main
module%shared _ = Game

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

let create_service ~path ~meth run =
  let service = Eliom_service.create ~path ~meth () in
  App.register ~service run;
  service

let game_service =
  create_service ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.(suffix (string "room_name")))
    Game.run

let newgame_service =
  Eliom_registration.Redirection.create ~options:`TemporaryRedirect
    ~path:(Eliom_service.Path [ "new" ])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    (Newgame.redirect ~game_service)

let _main_service =
  create_service ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    (Main.run ~newgame_service)

let _ =
  Ocsigen_server.start
    ~ports:[ (`All, 8080) ]
    ~command_pipe:"local/var/run/blibli-cmd" ~logdir:"local/var/log/blibli"
    ~datadir:"local/var/data/blibli" ~default_charset:(Some "utf-8")
    [
      Ocsigen_server.host ~regexp:".*"
        [
          Staticmod.run ~dir:"local/var/www/blibli" ();
          Eliom.run ();
          Cors.run ~max_age:86400 ~credentials:true
            ~methods:[ `POST; `GET; `HEAD ]
            ~exposed_headers:
              [
                "x-eliom-application";
                "x-eliom-location";
                "x-eliom-set-process-cookies";
                "x-eliom-set-cookie-substitutes";
              ]
            ();
        ];
    ]
