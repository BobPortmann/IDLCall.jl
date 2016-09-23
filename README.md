# IDL interface for the Julia language

[![Build Status](https://travis-ci.org/BobPortmann/IDLCall.jl.svg?branch=master)](https://travis-ci.org/BobPortmann/IDLCall.jl)

IDLCall is an interface to call IDL from the Julia language.

## Installation

Within Julia, use the package manager:
```julia
Pkg.clone("https://github.com/BobPortmann/IDLCall.jl.git")
```

You also need julia to be able to find the IDL library. Note that I have only used
OSX and am only guessing on other platforms (please provide feedback if you learn
how it works).

- OSX: set DYLD_FALLBACK_LIBRARY_PATH="/Applications/exelis/idl/bin/bin.darwin.x86_64"
  in shell before starting julia.
- Linux: Automatically found in julia
- Windows: Same as Linux?

IDL can be called using either the `RPC` or `Callable` interfaces. On windows only the `Callable`
interface is available. To use the `RPC` interface you must run `idlrpc` in a shell before
starting `IDLCall`. You can set the environmental variable `JL_IDL_TYPE` to `RPC` or `CALLABLE`
to force the use of that interface. Note that by default IDLCall uses the `RPC` interface
on OSX and Linux and `Callable` on Windows. The biggest difference between these is that:

- `Callable` IDL runs in one program space and thus arrays can be shared between julia and idl.
  In `RPC` all arrays are copied between processes. Note that I have run into issues with IDL
  loading DLM's while using `Callable` (e.g., NetCDF).

- The IDL `RPC` program runs independently of the julia process (e.g., julia
  can be restarted without killing the IDL RPC process). Note that you must start the
  `RPC` process in a shell using `idlrpc` command before starting IDLCall.

- IDL `RPC` is not supported on windows

## Quickstart

I recommend you start your code with

```julia
import IDLCall
idl = IDLCall
```
Then you can add a julia variable to the IDL process with

```
idl.put_var(x, "x")
```

and you can retrieve variable into julia using

```
x = idl.get_var("x")
```

You can run an arbitrary chunk of code in IDL using

```
idl.execute("any valid idl code")
```
Note that only primitive data types are supported at this time (e.g., structure variables
are not supported yet).

## REPL

You can drop into an IDL REPL by typing `>` at the julia prompt. Then you can type any valid
IDL commands, including using continuation characters `$` for multi-line commands. One
experimental feature I have added is the use of `%var` will auto-magically import the julia
variable `var` into the IDL process. This works at the IDL prompt or in strings passed into the
`execute` function.

## ToDo

- Add tests

- Make more flexible to install on all platforms

- Add more variable types to be transferred between julia and IDL.
