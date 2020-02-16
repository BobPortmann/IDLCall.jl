module IDL

export get_var, put_var, @get_var, @put_var, execute
export help

# Find IDL library directory if on Linux
if Sys.isunix()
   IDL_EXEC = chomp(read(`which idl`,String))
   if islink(IDL_EXEC)
      IDL_DIR = dirname(readlink(IDL_EXEC))
   else
      IDL_DIR = dirname(IDL_EXEC)
   end
   IDL_LIB_DIR = joinpath(IDL_DIR,"bin.darwin.x86_64")
   const libidl_rpc = joinpath(IDL_LIB_DIR,"libidl_rpc.dylib")
   const idlrpc = joinpath(IDL_DIR,"idlrpc")
else # Windows
   const idlcall = "libidl"
   const idlrpc = "libidl_rpc"
end

#=
jl_idl_type = get(ENV, "JL_IDL_TYPE", Sys.iswindows() ? "CALLABLE" : "RPC")

jl_idl_type == "RPC" ? include("IDLRPC.jl") :
jl_idl_type == "CALLABLE" ? include("IDLCallable.jl") :
Sys.iswindows() ? error("JL_IDL_TYPE must be CALLABLE on windows") :
error("JL_IDL_TYPE must be RPC or CALLABLE")
=#

include("IDLRPC.jl")
include("IDLREPL.jl")

function __init__()
   # Initializing RPC
   olderr = stderr
   (rd, wr) = redirect_stderr() # Redirect error messages
   ptr = rpc_init()
   if ptr != C_NULL # Check if idlrpc is already running
      global pclient = RPCclient(ptr)
   else # Start up idlrpc
      println("Initializing IDL")
      run(`$idlrpc`, wait=false)
      ptr = C_NULL
      cnt = 0
      while ptr == C_NULL && cnt < 60 # Allow for startup time
         ptr = rpc_init()
         cnt = cnt + 1
         sleep(1)
         print(".")
      end
      println("")
      ptr == C_NULL && error("IDL.init: IDLRPC init failed")
      global pclient = RPCclient(ptr, proc)
   end
   capture(true) # Capture output from IDL
   redirect_stderr(olderr)
   # Register cleanup function to be called at exit
   atexit(rpc_cleanup)

   # Initializing REPL
   idl_repl()
end

end
