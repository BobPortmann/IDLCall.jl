# convienence routines
help() = execute("help")
help(s::AbstractString) = execute("help, "*s)
idlhelp(s::AbstractString) = execute("?"*s)
idlhelp(strarr::Array{T,1}) where {T<:AbstractString} = println("IDL.idlhelp: Array input not supported")
shell_command(s::AbstractString) = println("% Shell commands not allowed in IDLRPC")
shell_command(strarr::Array{T,1}) where {T<:AbstractString} = println("% Shell commands not allowed in IDLRPC")
reset() = execute(".reset_session")
full_reset() = execute(".full_reset_session")
dotrun(filename::AbstractString) = execute(".run $filename")

function execute(str::AbstractString)
   ok, strarr, msg = convert_command(str)
   ok || error(msg)
   println("start")
   execute_converted(strarr)
   println("done")
   return nothing
end

function execute_converted(strarr::Array{T,1}) where {T<:AbstractString}
   # does no conversion of interpolated vars, continuation chars, or newlines
   for str in strarr
      execute_converted(str) || return false
   end
   return true
end

function put_var_from_name(name::AbstractString, abort::Bool=true)
   # abort=false causes routine to not issue error
   ok = true
   msg = ""
   if !isdefined(Main, Symbol(name))
      ok = false
      msg = "IDL.put_var_from_name: undefined variable $name in Module Main"
      if abort
         error(msg)
      else
         return (ok, msg)
      end
   end
   put_var(getfield(Main, Symbol(name)), name)
   return (ok, msg)
end

function put_var(arr::Array{T,N}, name::AbstractString) where {T<:AbstractString,N}
   # Sort of a HACK: do direcly since ImportNamedArray doesn't work
   execute("$name = strarr"*replace(string(size(arr)), ",)", ")"))
   for i=1:length(arr)
      j = i-1
      str = arr[i]
      execute("$name[$j] = '$str'")
   end
   return
end

const mask64 = 0x0000000000000000ffffffffffffffff
const mask32 = 0x000000000000000000000000ffffffff

function get_var(vptr::Ptr{IDL_Variable}, name::AbstractString="")
   var = unsafe_load(vptr)
   # some types not dealt with
   if (var.flags & IDL_V_FILE) != 0
      error("IDL.extract_from_vptr: $name: assoc type not setup")
   end
   ## if (var.flags & IDL_V_DYNAMIC) != 0
   ##     println("dynamic")
   ## end
   if (var.flags & IDL_V_NULL) != 0
      error("IDL.extract_from_vptr: $name: variable is null")
   end

   # array types
   if (var.flags & IDL_V_ARR) != 0
      if var.vtype == IDL_TYP_STRING
         parr = reinterpret(Ptr{IDL_Array}, convert(Int, var.buf))
         idl_arr = unsafe_load(parr)
         pdata = reinterpret(Ptr{IDL_String}, idl_arr.data)
         strarr = Array(Compat.ASCIIString, dims(idl_arr.dim, idl_arr.n_dim))
         for i=1:idl_arr.n_elts
            data = unsafe_load(pdata, i)
            strarr[i] = data.slen > 0 ? unsafe_string(data.s, Int(data.slen)) : ""
         end
         return strarr
      elseif var.vtype == IDL_TYP_STRUCT
         error("IDL.extract_from_vptr: $name: STRUCT not setup")
      elseif var.vtype == IDL_TYP_PTR
         error("IDL.extract_from_vptr: $name: PTRARR types not setup")
      elseif var.vtype == IDL_TYP_OBJREF
         error("IDL.extract_from_vptr: $name: OBJARR types not setup")
      else
         parr = reinterpret(Ptr{IDL_Array}, convert(Int, var.buf))
         idl_arr = unsafe_load(parr)
         jl_t = jl_type(var.vtype)
         pdata = reinterpret(Ptr{jl_t}, idl_arr.data)
         # not sure why this doesn't work
         # arr = unsafe_wrap(Array, pdata, dims(idl_arr.dim, idl_arr.n_dim))
         arr = Array(jl_t, dims(idl_arr.dim, idl_arr.n_dim))
         for i=1:idl_arr.n_elts
            arr[i] = unsafe_load(pdata, i)
         end
         return arr
      end
   end

   # Scalar value
   if var.vtype == IDL_TYP_UNDEF
      error("IDL.extract_from_vptr: $name: undefined variable")
   elseif var.vtype == IDL_TYP_BYTE
      return reinterpret(Int8, convert(UInt8, var.buf))
   elseif var.vtype == IDL_TYP_INT
      return reinterpret(Int16, convert(UInt16, var.buf))
   elseif var.vtype == IDL_TYP_LONG
      return reinterpret(Int32, convert(UInt32, var.buf))
   elseif var.vtype == IDL_TYP_FLOAT
      return reinterpret(Float32, convert(UInt32, var.buf))
   elseif var.vtype == IDL_TYP_DOUBLE
      return reinterpret(Float64, convert(UInt64, var.buf))
   elseif var.vtype == IDL_TYP_COMPLEX
      return complex(reinterpret(Float32, convert(UInt32, var.buf & mask32)),
      reinterpret(Float32, convert(UInt32, var.buf >> 32)))
   elseif var.vtype == IDL_TYP_STRING
      slen = reinterpret(Int32, convert(UInt32,var.buf & mask32))
      stype = reinterpret(Int32, convert(UInt32,(var.buf & mask64) >> 32))
      println(stype)
      s = reinterpret(Ptr{Cchar}, convert(UInt64,var.buf >> 64))
      return slen > 0 ? unsafe_string(s, slen) : ""
   elseif var.vtype == IDL_TYP_STRUCT
      error("IDL.extract_from_vptr: $name: STRUCT not setup")
   elseif var.vtype == IDL_TYP_DCOMPLEX
      return complex(reinterpret(Float64, convert(UInt64, var.buf & mask64)),
      reinterpret(Float64, convert(UInt64, var.buf >> 64)))
   elseif var.vtype == IDL_TYP_PTR
      error("IDL.extract_from_vptr: $name: PTR not setup")
   elseif var.vtype == IDL_TYP_OBJREF
      error("IDL.extract_from_vptr: $name: OBJREF not setup")
   elseif var.vtype == IDL_TYP_UINT
      return reinterpret(UInt16, convert(UInt16, var.buf))
   elseif var.vtype == IDL_TYP_ULONG
      return reinterpret(UInt32, convert(UInt32, var.buf))
   elseif var.vtype == IDL_TYP_LONG64
      return reinterpret(Int64, convert(UInt64, var.buf))
   elseif var.vtype == IDL_TYP_ULONG64
      return reinterpret(UInt64, convert(UInt64, var.buf))
   end
   # should be impossible to get here
   error("IDL.extract_from_vptr: $name: type is not setup")
end

function inside_string(pt::Int, line::AbstractString)
   for re in (r"('[^']+')", r"(\"[^\"]+\")")
      for m in eachmatch(re, line)
         if m.offset+endof(m.captures[1]) > pt ≥ m.offset
            return true
         end
      end
   end
   return false
end

function convert_continuations(line)
   # remove trailing comments and continuation lines
   # will remove continuation on final line which is invalid idl syntax
   #pt = start(line)
   pt = strip(line)
   while (pt = findfirst(r";|\$", pt)) > 0
      if !inside_string(pt, line)
         line = replace(line, r"(;|\$).*(\n|$)", "", 1)
      end
      if pt < endof(line)
         pt = next(line, pt)[2]
      end
   end
   return true, line, ""
end

function convert_newlines(line)
   # separates line at newline ("\n") characters into string array
   # assumes that continuation characters are already removed
   # not type stable but should not matter for repl use
   line = chomp(line)
   if in('\n', line)
      line = split(line, '\n', keep=false)
   end
   return line
end

function replace_interpolated_vars(line)
   # use %var to automatically pull var into idl and use it
   while (m = match(r"\%(\w+)", line)) != nothing
      if !inside_string(m.offset, line)
         ok, msg = put_var_from_name(ascii(m.captures[1]), false)
         if !ok
            return false, line, msg
         end
         line = line[1:m.offset-1]*line[m.offset+1:end]
      end
   end
   return true, line, ""
end

function convert_command(line)
   ok, line, msg = replace_interpolated_vars(line)
   ok || return ok, line, msg
   #ok, line, msg = convert_continuations(line) # hyzhou: remove while testing
   ok || return ok, line, msg
   line = convert_newlines(line)
   return true, line, msg
end
