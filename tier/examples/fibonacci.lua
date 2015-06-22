--Contains everything needed to encode simple things.
local encoding = require"tier.encoding"
local standard = encoding.standard

--A mapping object maps application value to and from TIER encodings.
--This particular mapping maps tables to list of 32 bit integers. 
local mapping = standard.list(encoding.primitive.int32)

--Data to encode.
local out_list = { 1, 1, 2, 3, 5, 8, 13 } 

--Destination file. 
local output = io.open("Fibonacci.dat", "wb")

--Encodes the list in the TIER format using the mapping. 
encoding.encode(output, out_list, mapping)
output:close()

--We read from the destination file. 
local input   = io.open("Fibonacci.dat", "rb");

--Decodes the file into a list again.
--Metadata is encoded together with the sequence so we 
--Dont have to supply a mapping.
local in_list = encoding.decode(input)
input:close()

--Check that the list contains the same stuff.
for i=1, #out_list do
	assert(out_list[i] == in_list[i])
end