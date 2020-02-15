using IDL, Test

# scalar passing
execute("a = 1")
help()
execute("a += 1")
a = get_var("a")
@test a == 2

# string passing
line = """
b = '1+1 '
"""
execute(line)
b = get_var("b")
@test b == "1+1 "

# array passing
a = [1,2,3]
put_var(a, "a")
execute("a += 1")
a = get_var("a")
@test a == [2,3,4]


# call function
line = """
PRINT, 'HELLO WORLD!'
"""
execute(line)

# If you don't say reset(), rpc will remember everything, even in the next call!
IDL.reset()


# Why is this not working?
#execute("1+1")
