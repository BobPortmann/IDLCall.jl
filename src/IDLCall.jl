
module IDLCall

using Compat

# Find IDL library directory if on Linux
if Sys.isunix()
    idl_dir = dirname(chomp(readstring(`which idl`)))
    idl_lib_dir = chomp(readstring(`bash -c "ls -d $(idl_dir)/bin.*"`))
    const idlcall = idl_lib_dir*"/libidl"
    const idlrpc = idl_lib_dir*"/libidl_rpc"
else
    const idlcall = "libidl"
    const idlrpc = "libidl_rpc"
end

export init, get_var, put_var, execute, @get_var, @put_var, idl_repl

jl_idl_type = get(ENV, "JL_IDL_TYPE", Sys.iswindows() ? "CALLABLE" : "RPC")

jl_idl_type == "RPC" ? include("IDLRPC.jl") :
jl_idl_type == "CALLABLE" ? include("IDLCallable.jl") :
Sys.iswindows() ? error("JL_IDL_TYPE must be CALLABLE on windows") :
error("JL_IDL_TYPE must be RPC or CALLABLE")

include("IDLREPL.jl")

init()
idl_repl()
repl = idl_repl

end
