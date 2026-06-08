let literal = "a"
let variable = literal

module Private : sig
  type t = private string

  val priv : t
end = struct
  type t = string

  let priv = "priv"
end
