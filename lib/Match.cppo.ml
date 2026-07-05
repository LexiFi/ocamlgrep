(*
   Type-aware structural search for OCaml code.

   Originally written for the ocamlgrep project (formerly cmt_grep);
   evolved in the merlin project as Expr_search and imported back here.
*)

open Asttypes
open Parsetree
open Typedtree
open Longident

exception Cannot_parse_type of exn

(* private exception used to fail a match *)
exception DontMatch

(* Safe substring - doesn't raise Invalid_argument *)
let substring str start_pos end_pos =
  let start_pos = max 0 start_pos in
  let end_pos = min (String.length str) end_pos in
  if end_pos <= start_pos then ""
  else String.sub str start_pos (end_pos - start_pos)

let matched (finding : Export.finding) =
  let start_col = finding.location.start.column in
  let end_col = finding.location.end_.column in
  match finding.lines with
  | [] -> []
  | [line] ->
      [substring line start_col end_col]
  | first :: other ->
      let first = substring first start_col max_int in
      first :: (
        match List.rev other with
        | [] -> assert false
        | last :: rev_other ->
            let last = substring last 0 end_col in
            List.rev (last :: rev_other)
      )

let initial_env = lazy (Compmisc.initial_env ())

let parse_type t =
  let env = Lazy.force initial_env in
  try (Typetexp.transl_type_scheme env t).ctyp_type with
  | e -> raise (Cannot_parse_type e)

let memoize h f k =
  match Hashtbl.find_opt h k with
  | None ->
      let r = f k in
      Hashtbl.add h k r;
      r
  | Some r -> r

(* warning: global, ever-growing cache *)
let parse_type = memoize (Hashtbl.create 10) parse_type

(* This global is cleared before each search.
   Consider passing it around explicitly as part of an 'env' argument. *)
let wildcards = ref ([] : (Asttypes.label * Parsetree.expression) list)

(* wildcards are in the form __123 ie.
   the two first characters are underscores;
   the following characters are digits.
*)
let is_wildcard str =
  String.length str > 2
  && str.[0] = '_'
  && str.[1] = '_'
  &&
  let r = ref true in
  for i = 2 to String.length str - 1 do
    match str.[i] with
    | '0' .. '9' -> ()
    | _ -> r := false
  done;
  !r

let check_wildcard id e =
  try
    let e' = List.assoc id !wildcards in
    if e <> e' then raise DontMatch
  with
  | Not_found -> wildcards := (id, e) :: !wildcards

let check_wildcard_lid id lid =
  let e = Ast_helper.Exp.ident (mknoloc lid) in
  check_wildcard id e

#if OCAML_VERSION >= (5, 4, 0)
let match_equal equal a b = if not (equal a b) then raise DontMatch
#endif

let try_match f x =
  let w = !wildcards in
  try
    f x;
    true
  with
  | DontMatch ->
      wildcards := w;
      false

let one_of f l =
  if not (List.exists (fun x -> try_match f x) l) then raise DontMatch

let match_set f ps ts =
  let ok = Hashtbl.create 8 in
  let f t p =
    f p t;
    Hashtbl.add ok p ()
  in
  List.iter (fun t -> one_of (f t) ps) ts;
  List.iter (fun p -> if not (Hashtbl.mem ok p) then raise DontMatch) ps

let rec path_matches_lident l p =
  match (l, p) with
  | Lident "__", _ -> true
#if OCAML_VERSION >= (5, 4, 0)
  | Ldot (l0, { txt = s2; _ }), Path.Pdot (p0, s1) when s1 = s2 || s2 = "__" ->
      path_matches_lident l0.txt p0
#else
  | Ldot (l0, s2), Path.Pdot (p0, s1) when s1 = s2 || s2 = "__" ->
      path_matches_lident l0 p0
#endif
  | Lident s2, Path.Pdot (_, s1) when s1 = s2 ->
      true (* the longident can be a suffix of the path *)
  | Lident s, Path.Pident id -> Ident.name id = s
  | (Lident _ | Ldot _ | Lapply _),
    (Pident _ | Pdot _ | Papply _
#if OCAML_VERSION >= (5, 1, 0)
    | Pextra_ty _
#endif
    ) ->
      false

let rec constructor_match p t =
  match (p, t) with
  | Lident "__", _ -> ()
  | Lident s, _ when is_wildcard s -> check_wildcard_lid s t
  | Lident s2, Lident s1 when s1 = s2 -> ()
#if OCAML_VERSION >= (5, 4, 0)
  | Lident s2, Ldot (_, { txt = s1; _ }) when s1 = s2 ->
      () (* the ident can be a suffix *)
  | Ldot (_, { txt = s2; _ }), Lident s1 when s1 = s2 -> ()
  | Ldot (p, s2), Ldot (t, s1) when s1.txt = s2.txt ->
      constructor_match p.txt t.txt
#else
  | Lident s2, Ldot (_, s1) when s1 = s2 ->
      () (* the ident can be a suffix *)
  | Ldot (_, s2), Lident s1 when s1 = s2 -> ()
  | Ldot (p, s2), Ldot (t, s1) when s1 = s2 ->
      constructor_match p t
#endif
  | (Lident _ | Ldot _ | Lapply _), (Lident _ | Ldot _ | Lapply _) ->
      raise DontMatch

let remove_loc =
  let super = Ast_mapper.default_mapper in
  {
    super with
    location = (fun _ _ -> Location.none);
    attributes = (fun _ _ -> []);
  }

let match_opt f p t =
  match (p, t) with
  | None, None -> ()
  | None, Some _
  | Some _, None ->
      raise DontMatch
  | Some p, Some t -> f p t

let match_list f p t =
  if List.compare_lengths p t = 0 then List.iter2 f p t else raise DontMatch

#if OCAML_VERSION >= (5, 4, 0)
let match_string : string -> string -> unit = match_equal String.equal

let match_label : string option -> string option -> unit =
  match_opt match_string

(* As of ocaml 5.4, labeled tuple expressions may not be reordered, so we
   match each labeled pair in order and require the labels to agree. *)
let match_labeled f (p_lbl, p) (t_lbl, t) =
  match_label p_lbl t_lbl;
  f p t
#endif

let tconstant_equal_pconst tconst pconst =
  match Typecore.constant pconst with
  | Error _ -> false
  | Ok pconst -> Parmatch.const_compare tconst pconst = 0

let rec match_expr (pexpr : Parsetree.expression) texpr =
  if texpr.exp_loc.loc_ghost && not pexpr.pexp_loc.loc_ghost then
    raise DontMatch;

  match (pexpr.pexp_desc, texpr.exp_desc) with
  (* __ matches any expression *)
  | Pexp_ident { txt = Lident "__"; _ }, _ -> ()
  (* __1234 matches any expression, and checks equality *)
  | Pexp_ident { txt = Lident id; _ }, _ when is_wildcard id ->
      let e =
        remove_loc.expr remove_loc
          Untypeast.(default_mapper.expr default_mapper texpr)
      in
      check_wildcard id e
  | Pexp_ident { txt = lid; _ }, Texp_ident (path, _, _)
    when path_matches_lident lid path ->
      ()
#if OCAML_VERSION >= (5, 4, 0)
  | Pexp_tuple pexprs, Texp_tuple texprs ->
      (* as of ocaml 5.4, labeled tuple expressions may not be reordered
         so they must match as-is without sorting *)
      match_list (match_labeled match_expr) pexprs texprs
  | Pexp_array pexprs, Texp_array (_, texprs) -> match_exprs pexprs texprs
#else
  | Pexp_tuple pexprs, Texp_tuple texprs ->
      match_exprs pexprs texprs
  | Pexp_array pexprs, Texp_array texprs -> match_exprs pexprs texprs
#endif
  | Pexp_constant pconst, Texp_constant tconst
    when tconstant_equal_pconst tconst pconst ->
      ()
  | Pexp_apply (pexpr, pargs), Texp_apply (tapply_expr, targs) ->
      match_expr pexpr tapply_expr;
      let rec check_all targs = function
        | [] -> () (* ok if more arguments in the typed expression *)
        | ( (Asttypes.Optional _ as lab),
            {
              pexp_desc =
                Pexp_construct
                  ({ txt = Lident (("MISSING" | "PRESENT") as cstr); _ }, None);
              _;
            } )
          :: pargs ->
            let pr = cstr = "PRESENT" in
            let rec loop = function
              | [] -> raise DontMatch
#if OCAML_VERSION >= (5, 4, 0)
              | (l, Arg targ) :: targs when l = lab ->
#else
              | (l, Some targ) :: targs when l = lab ->
#endif
                  if pr = targ.exp_loc.loc_ghost then raise DontMatch;
                  targs
              | x :: targs -> x :: loop targs
            in
            check_all (loop targs) pargs
        | (lab, parg) :: pargs ->
            let rec loop = function
              | [] -> raise DontMatch
#if OCAML_VERSION >= (5, 4, 0)
              | (l, Arg targ) :: targs when l = lab ->
#else
              | (l, Some targ) :: targs when l = lab ->
#endif
                  match_expr parg targ;
                  targs
              | ( (Asttypes.Optional _ as l),
#if OCAML_VERSION >= (5, 4, 0)
                  Arg
#else
                  Some
#endif
                    {
                      exp_desc =
                        Texp_construct ({ txt = Lident "Some"; _ }, _, [ targ ]);
                      _;
                    } )
                :: targs
                when l = lab ->
                  match_expr parg targ;
                  targs
              | x :: targs -> x :: loop targs
            in
            check_all (loop targs) pargs
      in
      check_all targs pargs
#if OCAML_VERSION >= (5, 2, 0)
  | ( Pexp_function
        ( [ { pparam_desc = Pparam_val (Nolabel, None, _); _ } ],
          _,
          Pfunction_cases (pcases, _, _) ),
      Texp_function
        ( [ { fp_arg_label = Nolabel; _ } ],
          Tfunction_cases { cases = tcases; _ } ) ) ->
      match_cases pcases tcases
#else
  | Pexp_function pcases, Texp_function { cases = tcases; _ } ->
      match_cases pcases tcases
#endif
  | ( Pexp_construct (pcstr, pexpr_opt),
      Texp_construct (tcstr, _tconstr_desc, texprs) ) ->
      constructor_match pcstr.txt tcstr.txt;
      begin match (pexpr_opt, texprs) with
      | Some { pexp_desc = Pexp_ident { txt = Lident "__"; _ }; _ }, _ -> ()
      | None, [] -> ()
      | Some { pexp_desc = Pexp_tuple pexprs; _ }, _ :: _ :: _ ->
#if OCAML_VERSION >= (5, 4, 0)
          let pexprs = List.map snd pexprs in
#endif
          match_exprs pexprs texprs
      | Some pexpr, [ texpr ] -> match_expr pexpr texpr
      | _ -> raise DontMatch
      end
  | Pexp_variant (pl, pe), Texp_variant (tl, te) when tl = pl ->
      match_opt match_expr pe te
#if OCAML_VERSION >= (5, 3, 0)
  | Pexp_match (pe, pcases), Texp_match (te, tcases, _teffects, _) ->
#else
  | Pexp_match (pe, pcases), Texp_match (te, tcases, _) ->
#endif
      match_expr pe te;
      match_cases pcases tcases
#if OCAML_VERSION >= (5, 3, 0)
  | Pexp_try (pe, pcases), Texp_try (te, tcases, _teffects) ->
#else
  | Pexp_try (pe, pcases), Texp_try (te, tcases) ->
#endif
      match_expr pe te;
      match_cases pcases tcases
  | Pexp_let (prf, pvb, pe), Texp_let (trf, tvb, te) when trf = prf ->
      match_expr pe te;
      match_value_bindings pvb tvb
  | Pexp_ifthenelse (pe1, pe2, pe3), Texp_ifthenelse (te1, te2, te3) ->
      match_expr pe1 te1;
      match_expr pe2 te2;
      match_opt match_expr pe3 te3
  | Pexp_sequence (pe1, pe2), Texp_sequence (te1, te2)
  | Pexp_while (pe1, pe2), Texp_while (te1, te2) ->
      match_expr pe1 te1;
      match_expr pe2 te2
#if OCAML_VERSION >= (5, 1, 0)
  | Pexp_assert pe, Texp_assert (te, _)
#else
  | Pexp_assert pe, Texp_assert te
#endif
  | Pexp_lazy pe, Texp_lazy te ->
      match_expr pe te
  | Pexp_field (pexpr, pid), Texp_field (texpr, tid, _) ->
      constructor_match pid.txt tid.txt;
      match_expr pexpr texpr
  | Pexp_setfield (pe1, pid, pe2), Texp_setfield (te1, tid, _, te2) ->
      constructor_match pid.txt tid.txt;
      match_expr pe1 te1;
      match_expr pe2 te2
  | Pexp_field (pexpr, pid), Texp_setfield (te1, tid, _, _) ->
      constructor_match pid.txt tid.txt;
      match_expr pexpr te1
  | Pexp_constraint (pe, pt), _ ->
      match_expr pe texpr;
      if not (match_typ pt texpr.exp_type) then raise DontMatch
  | ( Pexp_record (pfields, pdef),
      Texp_record { fields = tfields; extended_expression = tdef; _ } ) ->
      match_opt match_expr pdef tdef;
      let f (pid, pe) (tid, _, te) =
        constructor_match pid.txt tid.txt;
        match_expr pe te
      in
      let tfields =
        List.filter_map
          (function
            | _, Kept _ -> None
            | lbl, Overridden (id, e) -> Some (id, lbl, e))
          (Array.to_list tfields)
      in
      match_set f pfields tfields
  | Pexp_send (pe, { txt = ps; _ }), Texp_send (te, Tmeth_name ts) when ts = ps
    ->
      match_expr pe te
  | Pexp_send (pe, { txt = ps; _ }), Texp_send (te, Tmeth_val id)
    when Ident.name id = ps ->
      match_expr pe te
  | Pexp_new lid, Texp_new (path, _, _) when path_matches_lident lid.txt path ->
      ()
  | ( Pexp_for (pident, pexpr1, pexpr2, pdir_flag, pexpr),
      Texp_for (tident, patident, texpr1, texpr2, tdir_flag, texpr) )
    when tdir_flag = pdir_flag ->
      begin match (pident.ppat_desc, patident.ppat_desc) with
      | Ppat_any, Ppat_any -> ()
      | Ppat_var { txt = "__"; loc = _ }, Ppat_any -> ()
      | Ppat_any, Ppat_var { txt; loc = _ }
        when String.starts_with ~prefix:"_" txt ->
          ()
      | Ppat_var { txt; loc = _ }, Ppat_var _
        when path_matches_lident (Longident.Lident txt) (Path.Pident tident) ->
          ()
      | ( ( Ppat_any | Ppat_var _ | Ppat_alias _ | Ppat_constant _
          | Ppat_interval _ | Ppat_tuple _ | Ppat_construct _ | Ppat_variant _
          | Ppat_record _ | Ppat_array _ | Ppat_or _ | Ppat_constraint _
          | Ppat_type _ | Ppat_lazy _ | Ppat_unpack _ | Ppat_exception _
#if OCAML_VERSION >= (5, 3, 0)
          | Ppat_effect _
#endif
          | Ppat_extension _ | Ppat_open _ ),
          _ ) ->
          raise DontMatch
      end;
      match_expr pexpr1 texpr1;
      match_expr pexpr2 texpr2;
      match_expr pexpr texpr
  | ( ( Pexp_ident _ | Pexp_constant _ | Pexp_let _ | Pexp_function _
#if OCAML_VERSION < (5, 2, 0)
      | Pexp_fun _
#endif
      | Pexp_apply _ | Pexp_match _ | Pexp_try _ | Pexp_tuple _
      | Pexp_construct _ | Pexp_variant _ | Pexp_record _ | Pexp_field _
      | Pexp_setfield _ | Pexp_array _ | Pexp_ifthenelse _ | Pexp_sequence _
      | Pexp_while _ | Pexp_for _ | Pexp_coerce _ | Pexp_send _ | Pexp_new _
      | Pexp_setinstvar _ | Pexp_override _
#if OCAML_VERSION >= (5, 5, 0)
      | Pexp_struct_item _
#else
      | Pexp_letmodule _ | Pexp_letexception _ | Pexp_open _
#endif
      | Pexp_assert _ | Pexp_lazy _ | Pexp_poly _
      | Pexp_object _ | Pexp_newtype _ | Pexp_pack _
      | Pexp_letop _ | Pexp_extension _ | Pexp_unreachable ),
      ( Texp_ident _ | Texp_constant _ | Texp_let _ | Texp_function _
      | Texp_apply _ | Texp_match _ | Texp_try _ | Texp_tuple _
      | Texp_construct _ | Texp_variant _ | Texp_record _
#if OCAML_VERSION >= (5, 4, 0)
      | Texp_atomic_loc _
#endif
      | Texp_field _ | Texp_setfield _ | Texp_array _ | Texp_ifthenelse _
      | Texp_sequence _ | Texp_while _ | Texp_for _ | Texp_send _ | Texp_new _
      | Texp_instvar _ | Texp_setinstvar _ | Texp_override _
#if OCAML_VERSION >= (5, 5, 0)
      | Texp_struct_item _
#else
      | Texp_letmodule _ | Texp_letexception _
#endif
      | Texp_assert _ | Texp_lazy _ | Texp_object _
      | Texp_pack _ | Texp_letop _ | Texp_unreachable
#if OCAML_VERSION >= (5, 5, 0)
      | Texp_extension_constructor _ ) ) ->
#else
      | Texp_extension_constructor _ | Texp_open _ ) ) ->
#endif
      raise DontMatch

and match_typ ptyp texpr =
  match parse_type ptyp with
  | typ ->
      let env = Lazy.force initial_env in
#if OCAML_VERSION >= (5, 5, 0)
      begin try Ctype.is_moregeneral env typ texpr with
#else
      begin try Ctype.is_moregeneral env false typ texpr with
#endif
      | Assert_failure _ -> false
      end
  | exception _ -> begin
      match (ptyp.Parsetree.ptyp_desc, Types.get_desc texpr) with
      | ( Ptyp_constr ({ Location.txt; loc = _ }, pty_args),
          Tconstr (path, ty_args, _) ) ->
          if path_matches_lident txt path then begin
            match pty_args with
            | [
             {
               ptyp_desc =
                 Ptyp_constr ({ Location.txt = Lident "__"; loc = _ }, []);
               _;
             };
            ] ->
                true
            | _ ->
                if List.length ty_args = List.length pty_args then
                  List.for_all2 match_typ pty_args ty_args
                else false
          end
          else false
#if OCAML_VERSION >= (5, 4, 0)
      | Ptyp_tuple pty_args, Ttuple ty_args ->
          if List.length ty_args = List.length pty_args then
            List.for_all2
              (fun (_, pty) (_, ty) -> match_typ pty ty)
              pty_args ty_args
          else false
#else
      | Ptyp_tuple pty_args, Ttuple ty_args ->
          if List.length ty_args = List.length pty_args then
            List.for_all2 match_typ pty_args ty_args
          else false
#endif
      | Ptyp_arrow (_, pty1, pty2), Tarrow (_, ty1, ty2, _) ->
          match_typ pty1 ty1 && match_typ pty2 ty2
      | Ptyp_any, _ -> true
      | ( ( Ptyp_var _ | Ptyp_arrow _ | Ptyp_tuple _ | Ptyp_constr _
          | Ptyp_object _ | Ptyp_class _ | Ptyp_alias _ | Ptyp_variant _
          | Ptyp_poly _ | Ptyp_package _ | Ptyp_extension _
#if OCAML_VERSION >= (5, 2, 0)
          | Ptyp_open _
#endif
#if OCAML_VERSION >= (5, 5, 0)
          | Ptyp_functor _
#endif
          ),
          ( Tvar _ | Tarrow _ | Ttuple _ | Tconstr _ | Tobject _ | Tfield _
          | Tnil | Tlink _ | Tsubst _ | Tvariant _ | Tunivar _ | Tpoly _
#if OCAML_VERSION >= (5, 5, 0)
          | Tpackage _ | Tfunctor _ ) ) ->
#else
          | Tpackage _ ) ) ->
#endif
          false
    end

and match_pat : type k. _ -> k general_pattern -> _ =
 fun ppat tpat ->
  match (ppat.ppat_desc, tpat.pat_desc) with
  | Ppat_any, Tpat_any -> ()
  | Ppat_var { txt = "__"; _ }, _ -> ()
#if OCAML_VERSION >= (5, 2, 0)
  | Ppat_var { txt = s2; _ }, Tpat_var (_, { txt = s1; _ }, _)
    when is_wildcard s2 ->
      check_wildcard_lid s2 (Lident s1)
  | Ppat_var { txt = s2; _ }, Tpat_var (_, { txt = s1; _ }, _) when s1 = s2 ->
      ()
#else
  | Ppat_var { txt = s2; _ }, Tpat_var (_, { txt = s1; _ })
    when is_wildcard s2 ->
      check_wildcard_lid s2 (Lident s1)
  | Ppat_var { txt = s2; _ }, Tpat_var (_, { txt = s1; _ }) when s1 = s2 ->
      ()
#endif
#if OCAML_VERSION >= (5, 4, 0)
  | Ppat_tuple (pl, _closed_flag), Tpat_tuple tl ->
      match_list (match_labeled match_pat) pl tl
#else
  | Ppat_tuple pl, Tpat_tuple tl ->
      match_list match_pat pl tl
#endif
  | Ppat_constant pc, Tpat_constant tc when tconstant_equal_pconst tc pc -> ()
  | ( Ppat_construct (pcstr, ppat_opt),
      Tpat_construct (tcstr, _tconstr_desc, tpats, _) ) ->
      constructor_match pcstr.txt tcstr.txt;
      begin match (ppat_opt, tpats) with
      | None, [] -> ()
#if OCAML_VERSION >= (5, 4, 0)
      | ( Some (_, { ppat_desc = Ppat_tuple (ppats, _closed_flag); _ }),
          _ :: _ :: _ ) ->
          let ppats = List.map snd ppats in
          match_list match_pat ppats tpats
#else
      | ( Some (_, { ppat_desc = Ppat_tuple ppats; _ }),
          _ :: _ :: _ ) ->
          match_list match_pat ppats tpats
#endif
      | Some (_, ppat), [ tpat ] -> match_pat ppat tpat
      | _ -> raise DontMatch
      end
  | Ppat_constraint (ppat, pt), _ ->
      match_pat ppat tpat;
      let pt = parse_type pt in
      let env = Lazy.force initial_env in
#if OCAML_VERSION >= (5, 5, 0)
      let eq = Ctype.is_moregeneral env pt tpat.pat_type in
#else
      let eq = Ctype.is_moregeneral env false pt tpat.pat_type in
#endif
      if not eq then raise DontMatch
  | Ppat_or (p1, p2), Tpat_or (t1, t2, _) ->
      match_pat p1 t1;
      match_pat p2 t2
  | _, Tpat_value t -> match_pat ppat (t :> value general_pattern)
  | ( ( Ppat_any | Ppat_var _ | Ppat_alias _ | Ppat_constant _ | Ppat_interval _
      | Ppat_tuple _ | Ppat_construct _ | Ppat_variant _ | Ppat_record _
      | Ppat_array _ | Ppat_or _ | Ppat_type _ | Ppat_lazy _ | Ppat_unpack _
      | Ppat_exception _
#if OCAML_VERSION >= (5, 3, 0)
      | Ppat_effect _
#endif
      | Ppat_extension _ | Ppat_open _ ),
      _ ) ->
      raise DontMatch

and match_pat_expr : type k. _ -> k general_pattern -> _ =
 fun pexpr tpat ->
  match (pexpr.pexp_desc, tpat.pat_desc) with
  | ( Pexp_field
        ( { pexp_desc = Pexp_ident { txt = Lident "__"; _ }; _ },
          { txt = Lident s; _ } ),
      Tpat_record (fields, _) ) ->
      if
        not
          (List.exists
             (fun (_, {
#if OCAML_VERSION >= (5, 4, 0)
               Data_types.lbl_name;
#else
               Types.lbl_name;
#endif
               _ }, _) -> lbl_name = s)
             fields)
      then raise DontMatch
  | ( ( Pexp_ident _ | Pexp_constant _ | Pexp_let _ | Pexp_function _
#if OCAML_VERSION < (5, 2, 0)
      | Pexp_fun _
#endif
      | Pexp_apply _ | Pexp_match _ | Pexp_try _ | Pexp_tuple _
      | Pexp_construct _ | Pexp_variant _ | Pexp_record _ | Pexp_field _
      | Pexp_setfield _ | Pexp_array _ | Pexp_ifthenelse _ | Pexp_sequence _
      | Pexp_while _ | Pexp_for _ | Pexp_constraint _ | Pexp_coerce _
      | Pexp_send _ | Pexp_new _ | Pexp_setinstvar _ | Pexp_override _
#if OCAML_VERSION >= (5, 5, 0)
      | Pexp_struct_item _
#else
      | Pexp_letmodule _ | Pexp_letexception _ | Pexp_open _
#endif
      | Pexp_assert _ | Pexp_lazy _
      | Pexp_poly _ | Pexp_object _ | Pexp_newtype _ | Pexp_pack _
      | Pexp_letop _ | Pexp_extension _ | Pexp_unreachable ),
      _ ) ->
      raise DontMatch

and match_exprs pexprs texprs = match_list match_expr pexprs texprs

and match_cases : type k. _ -> k case list -> _ =
 fun pcases tcases -> match_set match_case pcases tcases

and match_value_bindings p t = match_set match_value_binding p t

and match_value_binding { pvb_pat; pvb_expr; _ } { vb_pat; vb_expr; _ } =
  match_expr pvb_expr vb_expr;
  match_pat pvb_pat vb_pat

and match_case : type k. _ -> k case -> _ =
 fun { pc_lhs; pc_guard; pc_rhs } { c_lhs; c_guard; c_rhs; _ } ->
  match_pat pc_lhs c_lhs;
  match_opt match_expr pc_guard c_guard;
  match_expr pc_rhs c_rhs

let parse_query query =
  (* Use the standard compiler-libs parser; no merlin-specific lexer needed. *)
  try Parse.expression (Lexing.from_string query) with
  | _ -> failwith "Could not parse search expression."

let search_cmt query_expr (cmt : Cmt_format.cmt_infos) =
  let res = ref [] in
  let cmt_search : Tast_iterator.iterator =
    let super = Tast_iterator.default_iterator in
    let pat : type k. _ -> k general_pattern -> _ =
     fun self p ->
      try
        match_pat_expr query_expr p;
        res := p.Typedtree.pat_loc :: !res
      with
      | DontMatch -> super.pat self p
    in
    let expr self e =
      wildcards := [];
      try
        match_expr query_expr e;
        res := e.Typedtree.exp_loc :: !res
      with
      | DontMatch -> super.expr self e
    in
    { super with expr; pat }
  in
  begin match cmt.cmt_annots with
  | Implementation str -> cmt_search.structure cmt_search str
  | Interface sg -> cmt_search.signature cmt_search sg
  | _ -> ()
  end;
  List.sort Stdlib.compare !res

let read_lines path =
  In_channel.with_open_text path In_channel.input_all
  |> String.split_on_char '\n' |> Array.of_list

let location_of_loc (loc : Location.t) source_path : Export.location =
  {
    file = source_path;
    start =
      {
        row = loc.loc_start.pos_lnum - 1;
        column = loc.loc_start.pos_cnum - loc.loc_start.pos_bol;
      };
    end_ =
      {
        row = loc.loc_end.pos_lnum - 1;
        column = loc.loc_end.pos_cnum - loc.loc_end.pos_bol;
      };
  }

let search ~make_valid_source_path query_expr cmt =
  (* We can't assume a single source file because a preprocessed file
     contains locations referring to more than one source file. *)
  let get_file_lines = memoize (Hashtbl.create 10) read_lines in
  List.filter_map
    (fun ({ loc_start; loc_end; loc_ghost } as loc : Location.t) ->
      if loc_ghost then None
      else
        let source_path = make_valid_source_path loc_start.pos_fname in
        let src_lines = get_file_lines source_path in
        let num_lines = Array.length src_lines in
        let s = max 1 (min num_lines loc_start.pos_lnum) in
        let e = max s (min num_lines loc_end.pos_lnum) in
        let lines = List.init (e - s + 1) (fun k -> src_lines.(s - 1 + k)) in
        Some { Export.location = location_of_loc loc source_path; lines })
    (search_cmt query_expr cmt)
