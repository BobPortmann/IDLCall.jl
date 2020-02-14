# IDL interface for the Julia language

[![Build Status](https://travis-ci.org/BobPortmann/`IDL.jl`.jl.svg?branch=master)](https://travis-ci.org/BobPortmann/`IDL.jl`.jl)

The `IDL.jl` package is an interface for calling IDL from the Julia language. You must have a valid IDL license to use IDL from Julia.

## Installation

Within Julia, use the package manager:
```julia
Pkg.clone("https://github.com/BobPortmann/IDL.jl.git")
```

`IDL.jl` should find and load the IDL library automatically on Mac and Linux. It has not been
tested on Windows so please file an issue if you use Windows and want to help make it work.

IDL can be called using either the `RPC` or `Callable` interface. On windows only the `Callable`
interface is available. You can set an environmental variable `JL_IDL_TYPE` to `RPC` or `CALLABLE`
to force the use of that interface.
Alternatively you can set `ENV["JL_IDL_TYPE"]` within julia before starting `IDL.jl`.
Note that by default `IDL.jl` uses the `RPC` interface on Mac and Linux and `Callable` on Windows. The biggest difference between these is that:

- `Callable` IDL runs in one program space and thus arrays can be shared between julia and IDL.
  In `RPC` all arrays are copied between processes. Note that I have run into issues with IDL
  loading DLM's while using `Callable` (e.g., NetCDF).

- IDL `RPC` is not supported on windows

- `Callable` is always managed by `IDL.jl` while `RPC` can be managed by `IDL.jl` or the user.
  By managed we mean that it is opened it when you load `IDL.jl` and closed it when you close julia.
  To manage `RPC` yourself run `idlrpc` in a shell before starting `IDL.jl`. This allows the `idlrpc`
  session to persist and julia can be restarted without killing the `idlrpc` process.

## Quickstart

I recommend you start your code with

```julia
using IDL
```
Then you can add a Julia variable to the IDL process with

```
x = 1
put_var(x, "x")
```

and you can retrieve variable into Julia using

```
x = get_var("x")
```

You can run an arbitrary chunk of code in IDL using

```
idl.execute("any valid idl code")
```
Note that only primitive data types are supported at this time (e.g., structure variables
are not supported yet).

## REPL

You can drop into an IDL REPL by typing `>` at the Julia prompt. Then you can type any valid
IDL commands, including using continuation characters `$` for multi-line commands. One
experimental feature I have added is the use of `%var` will auto-magically import the julia
variable `var` into the IDL process. This works at the IDL prompt or in strings passed into the
`execute` function.

## ToDo

- Add tests

- Make more flexible to install on all platforms

- Add more variable types to be transferred between julia and IDL.
