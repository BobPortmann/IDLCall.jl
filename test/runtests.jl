using IDL, Test

execute("a = 1")
help()
execute("a += 1")
a = get_var("a")
@test a == 2
# If you don't say reset(), rpc will remember everything, even in the next call!
IDL.reset()


# Why is this not working?
#execute("1+1")
