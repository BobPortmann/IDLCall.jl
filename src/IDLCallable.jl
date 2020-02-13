
include("idl_types.jl")
include("common-funcs.jl")
include("common-macros.jl")

using Libdl

if Sys.isapple()
   cd(IDL_LIB_DIR) do
      Libdl.dlopen("libidl")
   end
end

function init()
   ecode = ccall((:IDL_Init, idlcall), Cint, (Cint, Ptr{Cint}, Ptr{Ptr{UInt8}}),
      0, C_NULL, C_NULL)
   ecode == 0 && error("IDL.init: IDL init failed")
   global output_cb
   ccall((:IDL_ToutPush, idlcall), Nothing, (Ptr{Nothing},), output_cb)
end

# function execute{T<:AbstractString}(strarr::Array{T,1})
#     println("Strarray")
#     strarr =  ASCIIString[string(s) for s in strarr]
#     ecode = ccall((:IDL_Execute, idlcall), Cint, (Cint, Ptr{Ptr{UInt8}},), length(strarr), strarr)
#     if ecode != 0
#         # since error get printed by IDL, we just reset error state
#         ecode = ccall((:IDL_ExecuteStr, idlcall), Cint, (Ptr{UInt8},), "message, /RESET")
#     end
#     return nothing
# end

function execute_converted(str::AbstractString)
   # does no conversion of interpolated vars, continuation chars, or newlines
   ecode = ccall((:IDL_ExecuteStr, idlcall), Cint, (Ptr{UInt8},), str)
   if ecode != 0
      # since error get printed by IDL, we just reset error state
      ecode = ccall((:IDL_ExecuteStr, idlcall), Cint, (Ptr{UInt8},), "message, /RESET")
   end
   return true
end

function get_output(flags::Cint, buf::Ptr{UInt8}, n::Cint)
   line = unsafe_string(buf, n)
   stderr = (flags & IDL_TOUT_F_STDERR) != 0
   newline = (flags & IDL_TOUT_F_NLPOST) != 0
   if newline line = line*"\n" end
   print(line)
   return
end

output_cb = @cfunction(get_output, Nothing, (Cint, Ptr{UInt8},Cint))

# function exit()
#     # probably better to do a .full_reset instead
#     ecode = ccall((:IDL_Cleanup, idlcall), Cint, (Cint,), IDL_TRUE)
#     return nothing
# end

# hold a ref to imported variable so they don't get gc'ed
const var_refs = Dict{Ptr{UInt8}, Any}()

function done_with_var(p::Ptr{UInt8})
   if !haskey(var_refs, p)
      error("IDL.done_with_var: ptr not found: "*string(p))
   end
   delete!(var_refs, p)
   return
end

free_cb = @cfunction(done_with_var, Nothing, (Ptr{UInt8},))

function put_var(arr::Array{T,N}, name::AbstractString) where {T,N}
   if !isbits(eltype(arr)) || (idl_type(arr) < 0)
      error("IDL.put_var: only works with some vars containing bits types")
   end
   dim = zeros(Int, IDL_MAX_ARRAY_DIM)
   dim[1:N] = [size(arr)...]
   vptr = ccall((:IDL_ImportNamedArray, idlcall), Ptr{IDL_Variable},
   (Ptr{UInt8}, Cint, IDL_ARRAY_DIM, Cint, Ptr{UInt8}, IDL_ARRAY_FREE_CB , Ptr{Nothing}),
   name, N, dim, idl_type(arr), pointer(arr), free_cb, C_NULL)
   if vptr == C_NULL
      error("IDL.put_var: failed")
   end
   var_refs[pointer(arr)] = (name, vptr, arr)
   return
end

function put_var(x, name::AbstractString)
   # Sort of a HACK: import as one-element array and then truncate to scalar
   # IDL_ImportArray(int n_dim, IDL_MEMINT dim[], int type,
   #                 UCHAR *data, IDL_ARRAY_FREE_CB free_cb, Nothing *s)
   if !isbits(x) || (idl_type(x) < 0)
      error("IDL.put_var: only works with some vars containing bits types")
   end
   dim = zeros(Int, IDL_MAX_ARRAY_DIM)
   dim[1] = 1
   ccall((:IDL_ImportNamedArray, idlcall), Ptr{Nothing},
      (Ptr{UInt8}, Cint, Ptr{IDL_MEMINT}, Cint, Ptr{UInt8}, Ptr{Nothing}, Ptr{Nothing}),
      name, 1, dim, idl_type(x), pointer([x]), C_NULL, C_NULL)
   execute("$name = $name[0]")
   return
end

function put_var(str::AbstractString, name::AbstractString)
   # Sort of a HACK: do direcly since ImportNamedArray doesn't work
   execute("$name = '$str'")
   return
end

function get_name(vptr::Ptr{IDL_Variable})
   str = ccall((:IDL_VarName, idlcall), Ptr{Cchar}, (Ptr{IDL_Variable},), vptr)
   return unsafe_string(str)
end

function get_vptr(name::AbstractString)
   # returns C_NULL if name not in scope
   name = uppercase(name)
   vptr = ccall((:IDL_GetVarAddr, idlcall), Ptr{IDL_Variable}, (Ptr{UInt8},), name)
   vptr
end

function get_var(name::AbstractString)
   name = uppercase(name)
   vptr = ccall((:IDL_GetVarAddr, idlcall), Ptr{IDL_Variable}, (Ptr{UInt8},), name)
   if vptr == C_NULL
      error("IDL.get_var: variable $name does not exist")
   end
   get_var(vptr)
end
