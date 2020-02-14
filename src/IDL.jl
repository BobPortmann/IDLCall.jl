module IDL

export get_var, put_var, execute
export help

# Find IDL library directory if on Linux
if Sys.isunix()
   IDL_LIB_DIR = "/Applications/exelis/idl85/bin/bin.darwin.x86_64"
   const libidl_rpc = joinpath(IDL_LIB_DIR,"libidl_rpc.dylib")
   const idlrpc = "/Applications/exelis/idl85/bin/idlrpc"
else # Windows
   const idlcall = "libidl"
   const idlrpc = "libidl_rpc"
end

jl_idl_type = get(ENV, "JL_IDL_TYPE", Sys.iswindows() ? "CALLABLE" : "RPC")

jl_idl_type == "RPC" ? include("IDLRPC.jl") :
jl_idl_type == "CALLABLE" ? include("IDLCallable.jl") :
Sys.iswindows() ? error("JL_IDL_TYPE must be CALLABLE on windows") :
error("JL_IDL_TYPE must be RPC or CALLABLE")

end
