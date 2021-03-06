local function simple() end
local function simlple_with_param(a,b,c) end
local function add(a, b) return a + b end

local a = "ok"
local function with_upvalue(b)
	return a + b
end

local function recursive(n)
	if n == 0 or n == 1
		then return 1
		else return n * recursive(n)
	end 
end

local function uses_global(n)
	return math.abs(n)
end

local mut_rec1
local function mut_rec2(a)
	if a > 5 then 
		return mut_rec1(a - 1)
	end
	return 0 
end 

mut_rec1 = function(a)
	if a < 5 then 
		return mut_rec2(a - 1)
	end 

	return 0
end 


local shared = 5
local function sharerA(a) 
	return a + shared
end 

local function sharerB(a)
	return a - shared
end 

local GoodCases = 
{
	{ actual = simple , 			id = "simple function"},
	{ actual = simlple_with_param , id = "simple function with param"},
	{ actual = add,					id = "add function"}, 
	{ actual = with_upvalue , 		id = "function with upvalue"},
	{ actual = recursive , 			id = "recusive function" },
	{ actual = uses_global , 		id = "global function"},
}

local SharedCases = 
{
	{ actual = { sharerA, sharerB   } , id = "sharing an upvalue" },
	
	--Gives a matching error... I don't know if this is because of an error in 
	--closure or that the functions just are different.
	--{ actual = { mut_rec1, mut_rec2 } , id = "mutualy recursive functions" }
}

--Functions that should not work
local NonFunctionCases = 
{
	{ actual = nil},
	{ actual = false },
	{ actual = true},
	{ actual = 19371 },	
	{ actual = "string" },
	{ actual = {} },
	{ actual = coroutine.running() },
	{ actual = io.stdout }
}

--As I understand there are two kinds of C Functions
--Light C functions which is basically a C function pointer 
--And C functions with upvalues.
--I do not know which standard functions are 
local CFunctionCases =
{
	{ actual = print }
}

runtest {
	mapping = standard.closure,
	noregression = true,
	GoodCases
}

runtest {
	mapping = standard.tuple{{mapping=standard.closure}, {mapping=standard.closure}},
	noregression = true, 
	SharedCases
}

runtest {
	mapping = standard.closure,
	encodeerror = "expected function",
	NonFunctionCases,
}

runtest {
	mapping = standard.closure, 
	encodeerror = "unable to dump given function",
	CFunctionCases,
}