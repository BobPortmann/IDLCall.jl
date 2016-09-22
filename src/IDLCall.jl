
module IDLCall

using Compat

# Find IDL library directory if on macOS or Linux
if is_unix()
    idl_dir = dirname(chomp(readstring(`which idl`)))
    idl_lib = chomp(readstring(`bash -c "ls -d $(idl_dir)/bin.*"`))
    push!(Libdl.DL_LOAD_PATH, idl_lib)
end

export init, get_var, put_var, execute, @get_var, @put_var, idl_repl

jl_idl_type = get(ENV, "JL_IDL_TYPE", is_windows() ? "CALLABLE" : "RPC")

jl_idl_type == "RPC" ? include("IDLRPC.jl") :
jl_idl_type == "CALLABLE" ? include("IDLCallable.jl") :
is_windows() ? error("JL_IDL_TYPE must be CALLABLE on windows") :
error("JL_IDL_TYPE must be RPC or CALLABLE")

include("IDLREPL.jl")

init()
idl_repl()
repl = idl_repl

end
