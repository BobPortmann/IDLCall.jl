# These routines were modified from similar routines in MATLAB.jl
# E.G., @mput, @mget, _mput_multi, _mget_multi, make_getvar_statement

function put_var_multi(vs::Symbol...)
    nv = length(vs)
    if nv == 1
        v = vs[1]
        :(put_var($(v), string($(Meta.quot(v)))))
    else
        stmts = Array(Expr, nv)
        for i = 1:nv
            v = vs[i]
            stmts[i] = :(put_var($(v), string($(Meta.quot(v)))))
        end
        Expr(:block, stmts...)
    end
end

macro put_var(vs...)
    esc(put_var_multi(vs...))
end

function make_getvar_statement(v::Symbol)
    :($(v) = get_var(string($(Meta.quot(v)))))
end

function make_getvar_statement(ex::Expr)
    if !(ex.head == :(=))
        if ex.head == :kw
            error("Must call @get_var without parenthesis if using statements")
        else
            error("Invalid expression for @get_var: " * string(ex))
        end
    end
    v::Symbol = ex.args[1]
    k::Symbol = ex.args[2]
    :($(v) = get_var(string($(Meta.quot(k)))))
end

function get_var_multi(vs::Union{Symbol, Expr}...)
    # supress output by adding :nothing
    nv = length(vs)
    if nv == 1
        stmt = make_getvar_statement(vs[1])
        Expr(:block, stmt, :nothing)
    else
        stmts = Array(Expr, nv)
        for i = 1:nv
            stmts[i] = make_getvar_statement(vs[i])
        end
        Expr(:block, stmts..., :nothing)
    end
end

macro get_var(vs...)
    esc(get_var_multi(vs...))
end
