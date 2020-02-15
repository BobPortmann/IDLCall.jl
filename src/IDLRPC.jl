include("idl_types.jl")
include("common-funcs.jl")
include("common-macros.jl")

# RPC client
struct RPCclient
   ptr::Ptr{Nothing}
   process::Union{Nothing, Base.Process}
end
RPCclient() = RPCclient(C_NULL, nothing)
RPCclient(ptr::Ptr{Nothing}) = RPCclient(ptr, nothing)

pclient = RPCclient()

function rpc_init()
   ccall((:IDL_RPCInit, libidl_rpc), Ptr{Nothing}, (Clong, Ptr{UInt8}), 0, C_NULL)
end

function rpc_cleanup()
   ecode = ccall((:IDL_RPCCleanup, libidl_rpc), Cint, (Ptr{Nothing}, Cint), pclient.ptr, 0)
   ecode != 1 && error("IDL.exit: failed")
   if pclient.process != nothing
      kill(pclient.process)
   end
   return
end

function __init__()
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
end

function execute_converted(str::AbstractString)
   # does no conversion of interpolated vars, continuation chars, or newlines
   ecode = ccall((:IDL_RPCExecuteStr, libidl_rpc), Cint, (Ptr{Nothing},Ptr{UInt8}), pclient.ptr, str)
   if ecode != 1
      # since error get printed by IDL, we just reset error state
      ecode = ccall((:IDL_RPCExecuteStr, libidl_rpc), Cint, (Ptr{Nothing},Ptr{UInt8}), pclient.ptr,
         "message, /RESET")
      flush()
      return false
   end
   flush()
   return true
end

function capture(flag::Bool)
   nlines = flag ? 5000 : 0
   ecode = ccall((:IDL_RPCOutputCapture, libidl_rpc), Cint, (Ptr{Nothing}, Cint), pclient.ptr, nlines)
   ecode != 1 && error("IDL.capture: IDL_RPCOutputCapture failed")
   return nothing
end

function get_output!(line_s::IDL_RPC_LINE_S)
   ecode = ccall((:IDL_RPCOutputGetStr, libidl_rpc), Cint, (Ptr{Nothing},Ref{IDL_RPC_LINE_S},Cint),
      pclient.ptr, line_s, 0)
   ecode == 1 ? true : false
end

flag_set(x, flag) = (x & flag) == flag

function flush()
   line_s = IDL_RPC_LINE_S()
   # gc()
   while get_output!(line_s)
      println(unsafe_string(line_s.buf))
      flag_set(line_s.flags, IDL_TOUT_F_NLPOST) && print("\n")
   end
end

# no free_cb needed in libidl_rpc (I think)
free_cb = C_NULL

# NOTE: Put_var makes a copy of the data in the array when it is put into idlrpc process.
#       This is different than callable idl where the pointer to the data is copied.
#       I think the difference is because callable idl runs in the same process but
#       idlrpc does not. Thus, no free_cb is needed in idlrpc version.
function put_var(arr::Array{T,N}, name::AbstractString) where {T,N}
   if !isbitstype(eltype(arr)) || (idl_type(arr) < 0)
      error("IDL.put_var: only works with some vars containing bits types")
   end
   dim = zeros(Int, IDL_MAX_ARRAY_DIM)
   dim[1:N] = [size(arr)...]
   vptr = ccall((:IDL_RPCImportArray, libidl_rpc), Ptr{IDL_Variable},
      (Cint, IDL_ARRAY_DIM, Cint, Ptr{T}, IDL_ARRAY_FREE_CB),
      N, dim, idl_type(arr), arr, free_cb)
   ecode = ccall((:IDL_RPCSetVariable, libidl_rpc), Cint,
      (Ptr{Nothing}, Ptr{UInt8}, Ptr{IDL_Variable}), pclient.ptr, name, vptr)
   ecode != 1 && error("IDL.put_var: failed")
   return
end

# there must be a slicker way to do this?
function uint_size(x)
   if sizeof(x) == 1
      UInt8
   elseif sizeof(x) == 2
      UInt16
   elseif sizeof(x) == 4
      UInt32
   elseif sizeof(x) == 8
      UInt64
   elseif sizeof(x) == 16
      UInt128
   end
end

function put_var(x, name::AbstractString)
   if !isbits(x) || (idl_type(x) < 0)
      error("IDL.put_var: only works with some vars containing bits types")
   end
   vptr = get_vptr(name)
   ccall((:IDL_RPCStoreScalar, libidl_rpc), Nothing,
      (Ptr{IDL_Variable}, Cint, Ref{UInt128}),
   vptr, idl_type(x), Ref{UInt128}(convert(UInt128,reinterpret(uint_size(x),x))))
   ecode = ccall((:IDL_RPCSetVariable, libidl_rpc), Cint,
      (Ptr{Nothing}, Ptr{UInt8}, Ptr{IDL_Variable}), pclient.ptr, name, vptr)
   return
end

function put_var(x::Complex{T}, name::AbstractString) where {T}
   T == Float32 || T == Float64 || error("IDL.put_var: only floating point complex types allowed")
   if T == Float64
      y = (convert(UInt128, reinterpret(UInt64, imag(x))) << 64) + reinterpret(UInt64, real(x))
   else
      y = (convert(UInt128, reinterpret(UInt32, imag(x))) << 32) + reinterpret(UInt32, real(x))
   end
   vptr = get_vptr(name)
   ccall((:IDL_RPCStoreScalar, libidl_rpc), Nothing,
      (Ptr{IDL_Variable}, Cint, Ref{UInt128}), vptr, idl_type(x), Ref{UInt128}(y))
   ecode = ccall((:IDL_RPCSetVariable, libidl_rpc), Cint,
      (Ptr{Nothing}, Ptr{UInt8}, Ptr{IDL_Variable}), pclient.ptr, name, vptr)
   return
end

# function put_var(str::AbstractString, name::AbstractString)
#     # Sort of a HACK: do direcly since ImportNamedArray doesn't work
#     execute("$name = '$str'")
#     return
# end

function put_var(str::AbstractString, name::AbstractString)
   idl_string = IDL_String()
   ccall((:IDL_RPCStrStore, libidl_rpc), Nothing, (Ptr{IDL_String}, Ptr{Cchar}),
      idl_string, str)
   ecode = ccall((:IDL_RPCSetVariable, libidl_rpc), Cint,
      (Ptr{Nothing}, Ptr{UInt8}, Ptr{IDL_Variable}), pclient.ptr, name, vptr)
   ecode != 1 && error("IDL.put_var: failed")
end

function get_name(vptr::Ptr{IDL_Variable})
   # not implemented for RPC
   str = ccall((:IDL_RPCVarName, libidl_rpc), Ptr{Cchar}, (Ptr{IDL_Variable},), vptr)
   return unsafe_string(str)
end

function get_vptr(name::AbstractString)
   # returns C_NULL if name not in scope
   ccall((:IDL_RPCGetMainVariable, libidl_rpc), Ptr{IDL_Variable},
      (Ptr{Nothing},Ptr{UInt8}), pclient.ptr, name)
end

function get_var(name::AbstractString)
   vptr = ccall((:IDL_RPCGetMainVariable, libidl_rpc), Ptr{IDL_Variable},
      (Ptr{Nothing},Ptr{UInt8}), pclient.ptr, name)
   # NOTE: IDL_RPCGetVariable never seems to return NULL in spite of docs
   if vptr == C_NULL
      error("IDL.get_var: variable $name does not exist")
   end
   var = get_var(vptr, name)
   # not sure if this is needed?
   vptr = ccall((:IDL_RPCDeltmp, libidl_rpc), Nothing, (Ptr{IDL_Variable},), vptr)
   var
end
