# keep this separate because it may change between IDL versions

# some constants from idl_export.h
const IDL_TRUE = convert(Int32, 1)
const IDL_FALSE = convert(Int32, 0)
const IDL_MAX_ARRAY_DIM = 8

# IDL types from idl_export.h
const IDL_TYP_UNDEF =      0
const IDL_TYP_BYTE =       1
const IDL_TYP_INT =        2
const IDL_TYP_LONG =       3
const IDL_TYP_FLOAT =      4
const IDL_TYP_DOUBLE =     5
const IDL_TYP_COMPLEX =    6
const IDL_TYP_STRING =     7
const IDL_TYP_STRUCT =     8
const IDL_TYP_DCOMPLEX =   9
const IDL_TYP_PTR =        10
const IDL_TYP_OBJREF =     11
const IDL_TYP_UINT =       12
const IDL_TYP_ULONG =      13
const IDL_TYP_LONG64 =     14
const IDL_TYP_ULONG64 =    15

# translating IDL/C types to julia
const IDL_MEMINT  = Int
const IDL_UMEMINT = UInt
const UCHAR = Cuchar
# NOTE: IDL_ARRAY_DIM is fixed length array IDL_MEMINT[IDL_MAX_ARRAY_DIM] (i.e, Int[8])
const IDL_ARRAY_DIM = Ptr{IDL_MEMINT}
const IDL_ARRAY_FREE_CB = Ptr{Nothing}
const IDL_FILEINT = Int     # possibly different on Windows
const IDL_STRING_SLEN_T = Cint
const IDL_STRING_MAX_SLEN = 2147483647   # should you check this?

# /***** IDL_VARIABLE flag values ********/
const IDL_V_CONST =       1
const IDL_V_TEMP =        2
const IDL_V_ARR =         4
const IDL_V_FILE =        8
const IDL_V_DYNAMIC =     16
const IDL_V_STRUCT =      32
const IDL_V_NULL =        64

function idl_type(jl_t)
    # IDL type index from julia type
    t = typeof(jl_t)
    if t <: AbstractArray
        t = eltype(jl_t)
    end
    idl_t = -1
    if t == UInt8
        idl_t = IDL_TYP_BYTE
    elseif t == Int16
        idl_t = IDL_TYP_INT
    elseif t == Int32
        idl_t = IDL_TYP_LONG
    elseif t == Float32
        idl_t = IDL_TYP_FLOAT
    elseif t == Float64
        idl_t = IDL_TYP_DOUBLE
    elseif t == ComplexF64
        idl_t = IDL_TYP_COMPLEX
    elseif t <: AbstractString
        idl_t = IDL_TYP_STRING
    elseif t == UInt16
        idl_t = IDL_TYP_UINT
    elseif t == UInt32
        idl_t = IDL_TYP_ULONG
    elseif t == Int64
        idl_t = IDL_TYP_LONG64
    elseif t == UInt64
        idl_t = IDL_TYP_ULONG64
    end
    if idl_t < 0 error("IDL.idl_type: type not found: " * string(t)) end
    return idl_t
end

function jl_type(idl_t)
    # julia type from IDL type index
    jl_t = Any
    if idl_t == IDL_TYP_BYTE
        jl_t = UInt8
    elseif idl_t == IDL_TYP_INT
        jl_t = Int16
    elseif idl_t == IDL_TYP_LONG
        jl_t = Int32
    elseif idl_t == IDL_TYP_FLOAT
        jl_t = Float32
    elseif idl_t == IDL_TYP_DOUBLE
        jl_t = Float64
    elseif idl_t == IDL_TYP_COMPLEX
        jl_t = ComplexF64
    elseif idl_t == IDL_TYP_STRING
        jl_t = Compat.String
        #elseif idl_t == IDL_TYP_DCOMPLEX
        #    jl_t = Complex128
    elseif idl_t == IDL_TYP_UINT
        jl_t = UInt16
    elseif idl_t == IDL_TYP_ULONG
        jl_t = UInt32
    elseif idl_t == IDL_TYP_LONG64
        jl_t = Int64
    elseif idl_t == IDL_TYP_ULONG64
        jl_t = UInt64
    end
    if jl_t == Any
        error("IDL.jl_type: type not found: " * string(idl_t))
    end
    return jl_t
end

#*************************************************************************************************#
# some IDL types from extern.jl
# sizeof(buf) is max size of IDL_ALLTYPES Union (64x2=128 bits or 16 bytes on all platforms)
const IDL_ALLTYPES = UInt128
struct IDL_Variable
    vtype::UCHAR
    flags::UCHAR
    flags2::UCHAR
    buf::IDL_ALLTYPES
end

# works as a fixed length array
struct IDL_DIMS
    d1::IDL_MEMINT
    d2::IDL_MEMINT
    d3::IDL_MEMINT
    d4::IDL_MEMINT
    d5::IDL_MEMINT
    d6::IDL_MEMINT
    d7::IDL_MEMINT
    d8::IDL_MEMINT
end

dims(d::IDL_DIMS) = (d.d1,d.d2,d.d3,d.d4,d.d5,d.d6,d.d7,d.d8)
dims(d::IDL_DIMS, ndims::Integer) = (d.d1,d.d2,d.d3,d.d4,d.d5,d.d6,d.d7,d.d8)[1:ndims]

struct IDL_Array
    elt_len::IDL_MEMINT                 # Length of element in char units
    arr_len::IDL_MEMINT                 # Length of entire array (char)
    n_elts::IDL_MEMINT                  # total # of elements
    data::Ptr{UCHAR}                    # ^ to beginning of array data
    n_dim::UCHAR                        # # of dimensions used by array
    flags::UCHAR                        # Array block flags
    file_unit::Cshort                   # # of assoc file if file var
    dim::IDL_DIMS                       # dimensions
    free_cb::IDL_ARRAY_FREE_CB          # Free callback
    offset::IDL_FILEINT                 # Offset to base of data for file var
    data_guard::IDL_MEMINT              # Guard longword
end

struct IDL_String
    slen::IDL_STRING_SLEN_T             # Length of string, 0 for null
    stype::Cshort                       # type of string, static or dynamic
    s::Ptr{Cchar}                       # Addr of string
    IDL_String() = new(0, 0, Base.unsafe_convert(Ptr{Cchar}, Array{Cchar}(undef, IDL_RPC_MAX_STRLEN)))
end

# From idl_rpc.h
const IDL_RPC_MAX_STRLEN = 512		# max string length
struct IDL_RPC_LINE_S
    flags::Cint
    buf::Ptr{Cchar}
    IDL_RPC_LINE_S() = new(0, Base.unsafe_convert(Ptr{Cchar}, Array{Cchar}(undef, IDL_RPC_MAX_STRLEN)))
end

const IDL_TOUT_F_STDERR = 1	# Output to stderr instead of stdout
const IDL_TOUT_F_NLPOST = 4	# Output a newline at end of line
