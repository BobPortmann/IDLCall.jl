import REPL:respond, LineEdit, mode_keymap

function idl_repl()
    # Setup idl prompt
    prompt = LineEdit.Prompt("IDL> ";
        prompt_prefix=Base.text_colors[:blue],
        prompt_suffix=Base.text_colors[:white])

    !isdefined(Base, :active_repl) && return

    repl = Base.active_repl

    prompt.on_done = respond(repl,prompt) do line
        ok2, line, msg = convert_continuations(line)
        if !ok2
            println(msg)
            println()
            return
        end
        ok2, line, msg = replace_interpolated_vars(line)
        if !ok2
            println(msg)
            println()
            return
        end
        ec = execute_converted(line)
        nothing
    end

    main_mode = repl.interface.modes[1]

    # replace existing IDL REPL if present
    i_mode = find_prompt_in_modes(repl.interface.modes, "IDL> ")
    if i_mode < 1
        push!(repl.interface.modes,prompt)
    else
        repl.interface.modes[i_mode] = prompt
    end

    hp = main_mode.hist
    hp.mode_mapping[:idl] = prompt
    prompt.hist = hp

    idl_keymap = Dict{Any,Any}(
        '>' => function (s,args...)
        if isempty(s)
            if !haskey(s.mode_state,prompt)
                s.mode_state[prompt] = LineEdit.init_state(repl.t,prompt)
            end
            LineEdit.transition(s,prompt)
        else
            LineEdit.edit_insert(s,'>')
        end
    end)

    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    mk = mode_keymap(main_mode)

    b = Dict{Any,Any}[skeymap, mk, LineEdit.history_keymap,
        LineEdit.default_keymap, LineEdit.escape_defaults]
        prompt.keymap_dict = LineEdit.keymap(b)

    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict,
        idl_keymap)
    nothing
end

function find_prompt_in_modes(modes, name)
    j = -1
    for (i,mode) in enumerate(modes)
        if :prompt in fieldnames(typeof(mode)) && mode.prompt == name
            j = i
            break
        end
    end
    return j
end
