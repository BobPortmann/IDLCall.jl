
module IDLCall

#using Compat

# Find IDL library directory if on Linux
if Sys.isunix()
   #IDL_DIR = dirname(chomp(readstring(`which idl`)))
   #idl_lib_dir = chomp(readstring(`bash -c "ls -d $(IDL_DIR)/bin.*"`))
   #IDL_DIR = dirname(chomp(read(`which idl`,String)))
   IDL_DIR = "/Applications/exelis/idl85/"
   #IDL_PATH='/Users/hyzhou/Idl:${IDL_DIR}/lib:${IDL_DIR}/lib/utilities'
   #IDL_STARTUP=idlrc
   idl_lib_dir = chomp(read(`bash -c "ls -d $(IDL_DIR)/bin.*"`,String))
   #const idlcall = idl_lib_dir*"/libidl"
   #const idlrpc = idl_lib_dir*"/libidl_rpc"
   const idlcall = joinpath(idl_lib_dir,"lib")
   const idlrpc = joinpath(idl_lib_dir,"libidl_rpc")
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
