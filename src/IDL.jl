module IDL

export get_var, put_var, @get_var, @put_var, execute

# Find IDL library directory if on Linux
if Sys.isunix()
    idl_exec = chomp(read(`which idl`,String))
    if islink(idl_exec)
        idl_dir = dirname(readlink(idl_exec))
    else
        idl_dir = dirname(idl_exec)
    end
    idl_lib_dir = joinpath(idl_dir,"bin.darwin.x86_64")
    const libidl_rpc = joinpath(idl_lib_dir,"libidl_rpc.dylib")
    const idlrpc = joinpath(idl_dir,"idlrpc")
    const idlcall = joinpath(idl_lib_dir,"libidl.dylib")
else # Windows
    const idlcall = "libidl"
    const idlrpc = "libidl_rpc"
end


jl_idl_type = get(ENV, "JL_IDL_TYPE", Sys.iswindows() ? "CALLABLE" : "RPC")

jl_idl_type == "RPC" ? include("IDLRPC.jl") :
jl_idl_type == "CALLABLE" ? include("IDLCallable.jl") :
Sys.iswindows() ? error("JL_IDL_TYPE must be CALLABLE on windows") :
error("JL_IDL_TYPE must be RPC or CALLABLE")

include("IDLREPL.jl")

function __init__()
    if jl_idl_type == "RPC"
        rpc_init()
    elseif jl_idl_type == "CALLABLE"
        callable_init() # not yet working for MaxOS and Linux
    end

    # Initializing REPL
    idl_repl()
end

end
