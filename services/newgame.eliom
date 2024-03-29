let redirect ~game_service () () =
  let new_room_name = Game_sessions.fresh_game_name () in
  Lwt.return
    (Eliom_registration.Redirection
       (Eliom_service.preapply ~service:game_service new_room_name))
