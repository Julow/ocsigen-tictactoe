let handle_file_client nm =
  let target_base = Filename.basename nm and dep = Filename.concat ".." nm in
  if Filename.check_suffix nm ".pp.eliom" then ()
  else if Filename.check_suffix nm ".pp.eliomi" then ()
  else if Filename.check_suffix nm ".eliom" then
    let target = Filename.chop_extension target_base in
    Printf.printf
      "(rule (target %s.ml) (deps %s)\n\
      \  (action\n\
      \    (with-stdout-to %%{target}\n\
      \      (chdir .. (run ../tools/eliom_ppx_client.exe --as-pp -server-cmo \
       %%{cmo:%s} --impl %%{deps})))))\n"
      target dep
      (Filename.chop_extension dep)
  else if Filename.check_suffix nm ".eliomi" then
    let target = Filename.chop_extension target_base in
    Printf.printf
      "(rule (target %s.mli) (deps %s)\n\
      \  (action\n\
      \    (with-stdout-to %%{target}\n\
      \      (chdir .. (run ../tools/eliom_ppx_client.exe --as-pp --intf \
       %%{deps})))))\n"
      target dep

let read_dir d = Sys.readdir d |> Array.map (fun f -> Filename.concat d f)

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  Array.concat (List.map read_dir args)
  |> Array.to_list |> List.sort compare
  |> List.iter handle_file_client
