open Lwt.Syntax
(** Store the states of current games. *)

module%shared Grid : sig
  (** Represent the 3x3 grid of a tictactoe. *)

  type cell = X | O [@@deriving json]
  type t [@@deriving json]

  val create : unit -> t
  (** Create an empty grid. *)

  val get : t -> int -> int -> cell option
  (** Returns [None] if the cell is empty.

      @raise [Not_found]. *)

  val set : t -> int -> int -> cell -> [ `Winner of cell | `Draw | `Going_on ]
  (** Fill an empty cell of the grid and compute whether the game ends.

      Returns [`Draw] if the game ends in a draw.
      Returns [`Winner cell] if the game ends with a winner.
      Returns [`Going_on] if the game is still going.

      @raise [Invalid_argument] if the specified cell was not empty.
      @raise [Not_found].
  *)
end = struct
  type cell = X | O [@@deriving json]
  type t = cell option array [@@deriving json]

  let create () = Array.make 9 None

  let index_of_coords x y =
    if x < 0 || y < 0 || x > 2 || y > 2 then raise Not_found;
    (y * 3) + x

  let get t x y = t.(index_of_coords x y)

  (* Returns [1] if [index] is a valid index within the grid and the cell at
     [index] is filled and equal to [cell]. Returns [0] otherwise. *)
  let count_cell t index cell =
    if index < 0 || index > 8 then 0
    else match t.(index) with Some cell' when cell' = cell -> 1 | _ -> 0

  (* [base_index] is the starting index of the row, column or diagonal. *)
  let count_cells t base_index step cell =
    count_cell t base_index cell
    + count_cell t (base_index + step) cell
    + count_cell t (base_index + (step * 2)) cell

  (** Check whether filling [index] was a finishing move. *)
  let check_finished t index cell =
    if
      (* Vertically *)
      count_cells t (index mod 3) 3 cell = 3
      (* Horizontally *)
      || count_cells t (index - (index mod 3)) 1 cell = 3
      (* Diagonals *)
      || count_cells t 0 4 cell = 3
      || count_cells t 2 2 cell = 3
    then `Winner cell
    else if not (Array.memq None t) then
      (* Grid is full, game ends on a draw. *)
      `Draw
    else `Going_on

  let set t x y cell =
    let index = index_of_coords x y in
    if t.(index) <> None then invalid_arg "Game_state.Grid.set";
    t.(index) <- Some cell;
    check_finished t index cell
end

type%shared state =
  | Waiting_for_player1
  | Waiting_for_player2
  | Turn of [ `P1 | `P2 ]
  | Game_ended of [ `P1 | `P2 | `Draw ]
[@@deriving json]

type%shared client_msg = Click of int * int [@@deriving json]

type%shared server_msg =
  | State_changed of state * Grid.t  (** The state or the grid changed. *)
[@@deriving json]

type t = {
  mutable state : state;
  mutable grid : Grid.t;
  player1 : (client_msg, client_msg) Eliom_bus.t;
  player2 : (client_msg, client_msg) Eliom_bus.t;
  bus : (server_msg, server_msg) Eliom_bus.t;
}

let make () =
  {
    state = Waiting_for_player1;
    grid = Grid.create ();
    player1 = Eliom_bus.create [%json: client_msg];
    player2 = Eliom_bus.create [%json: client_msg];
    bus = Eliom_bus.create [%json: server_msg];
  }

let set_state t state =
  t.state <- state;
  Eliom_bus.write t.bus (State_changed (state, t.grid))

(** Return the same as [Grid.set]. *)
let set_grid_cell t x y cell =
  let r = Grid.set t.grid x y cell in
  let+ () = Eliom_bus.write t.bus (State_changed (t.state, t.grid)) in
  r

(** Send the unchanged state to clients. Used when the client made a unlawful move. *)
let notify t = Eliom_bus.write t.bus (State_changed (t.state, t.grid))

let games : (string, t) Hashtbl.t = Hashtbl.create 64

let get_game name =
  try Hashtbl.find games name
  with Not_found ->
    let t = make () in
    Hashtbl.add games name t;
    t

let game_counter = ref 0

(** Generate a pseudo random name composed of 5 digits in base 16. *)
let fresh_game_name () =
  incr game_counter;
  let id = Hashtbl.hash !game_counter mod 0xFFFFF in
  Printf.sprintf "%05x" id
