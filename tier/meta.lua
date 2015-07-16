local tags   = require"tier.tags"
local core   = require"tier.core"
local format = require"format"

local pack 	 = format.packvarint
local unpack = format.unpackvarint

local meta = { }
local meta_types = { }

local function newmetatype(tag)
	assert(tag)
	
	local mt = {} mt.__index = mt
	mt.tag = tag
	meta_types[tag] = mt
	return mt
end 

local simple_metatypes = 
{
	[tags.VOID] 	= true,
	[tags.NULL] 	= true,
	[tags.VARINT] 	= true,
	[tags.VARINTZZ] = true,
	[tags.CHAR]		= true,
	[tags.WCHAR]	= true,
	[tags.TYPE]		= true,
	[tags.DYNAMIC]	= true,
	[tags.FLAG]		= true,
	[tags.SIGN]		= true,
	[tags.BOOLEAN]	= true,
	[tags.UINT8]	= true,
	[tags.UINT16]	= true,
	[tags.UINT32]	= true,
	[tags.UINT64]	= true,
	[tags.SINT8]	= true,
	[tags.SINT16]	= true,
	[tags.SINT32]	= true,
	[tags.SINT64]	= true,
	[tags.HALF]		= true,
	[tags.FLOAT]	= true,
	[tags.DOUBLE]	= true,
	[tags.QUAD]		= true,
	[tags.STREAM]	= true,
	[tags.STRING]	= true,
	[tags.WSTRING]	= true
}

for entry, _ in pairs(simple_metatypes) do 
	meta[tags[entry]:lower()] = { tag = entry, id = pack(entry) }
end

local function metafromtag(tag)
	return meta[tags[tag]:lower()]
end 


local function encodeid(encoder, type)
	local writer = encoder.writer
	if simple_metatypes[type.tag] then
		writer:varint(type.tag)
	elseif type.tag == tags.TYPEREF then
		assert(type[1] ~= nil, "incomplete typeref") 
		encodeid(encoder, type[1])
	else 
		local index = encoder.types[type]
		if index == nil then 
			encoder.types[type] = writer:getposition()
			writer:varint(type.tag)
		 	type:encode(encoder)			
		else
			local offset = writer:getposition() - index
			writer:varint(tags.TYPEREF)
			writer:varint(offset)
		end 
	end 
end

local outstream = format.outmemorystream
local newwriter  = format.writer 
local newencoder = core.encoder 

local function getencodeid(type)
	if not type.id then
		local buffer  = outstream()
		encoder       = newencoder(newwriter(buffer))
		encoder.types = { }
		encoder.types[type] = encoder.writer:getposition()
		type:encodeid(encoder) 
		encoder:close()		

		local body = buffer:getdata()
		type.id    = pack(type.tag) .. pack(#body) .. body	
	end 
	return type.id 
end 

function meta.encodetype(encoder, type)
	encoder.writer:raw(getencodeid(type))	
end 

local function newdecodetype(decoder, MetaTable)
	local type = setmetatable({}, MetaTable)
end 

local function decodeid(decoder)
	local reader = decoder.reader

	local tag = reader:varint()
	if simple_metatypes[tag] then
		return metafromtag(tag)
	elseif tag == tags.TYPEREF then 
		local pos     = reader:getposition() - 1	
		local typeref = pos - reader:varint() 
		local type    = decoder.types[typeref]
		return type
	else 
		local pos  = reader:getposition()
		local type = meta_types[tag]
		
		--We have to create a value of the appropriate type 
		--before we can start decoding to fix potential typereference. 
		local item = setmetatable({}, type)
		type:decode(decoder, item)		
		
		return type_reader:decode(decoder)
	end 
end 

local instream  = format.inmemorystream
local newreader  = format.reader
local newdecoder = core.decoder
function meta.decodetype(decoder)
	local tag = decoder.reader:varint()
	if simple_metatypes[tag] then 
		return metafromtag(tag)
	else 
		local data    	 = pack(tag) .. decoder.reader:stream()
		local decoder 	 = newdecoder(newreader(instream(data)))
		decoder.types 	 = { }
		return decodeid(decoder)			
	end  
end

do 
	local Array = newmetatype(tags.ARRAY)
	function Array:encode(encoder)
		encoder.writer:varint(self.size)
		encodeid(encoder, self[1])
	end
	
	function Array:decode(decoder, item)
		item.size = decoder.reader:varint()
		item[1]	  = decodeid(decodeid)
	end
	
	function meta.array(element_type, size)
		local array = setmetatable({ }, Array)
		array[1]  = element_type
		array.size = size 
		return array
	end
end 

do 
	local List = newmetatype(tags.LIST) 
	function List:encode(encoder)
		encoder.writer:varint(self.size)
		encodeid(encoder, self[1])
	end
	
	function List:decode(decoder, item)
		item.size 		  = decoder.reader:varint()
		item[1]			  = decodeid(decodeid)
	end
	
	function meta.list(element_type, size)
		if size == nil then size = 0 end
		local list 	  = setmetatable({ }, List)
		list[1] 	  = element_type
		list.size 	  = size
		return list 
	end
end 

do 
	local Set = newmetatype(tags.SET) 
	function Set:encode(encoder)
		encoder.writer:varint(self.size)
		encodeid(encoder, self[1])
	end
	
	function Set:decode(decoder, item)
		item.size 	= decoder.reader:varint()
		item[1]		= decodedid(decoder)
	end
	
	function meta.set(element_type, size)
		if size == nil then size = 0 end
		local set = setmetatable({}, Set)
		set[1]	  = element_type
		set.size  = size 
		set.tag   = tags.SET
		return set
	end
end 

do
	local Map 	= newmetatype(tags.MAP)
	function Map:encode(encoder)
		encoder.writer:varint(self.size)
		encodeid(encoder, self[1])
		encodeid(encoder, self[2])
	end
	
	function Map:decode(decoder, item)
		item.size    = encoder.reader:varint()
		item[1]		 = decodeid(decoder)
		item[2]		 = decodeid(decoder)
	end
	
	function meta.map(key_type, value_type, size)
		if size == nil then size = 0 end
		
		local map = setmetatable({ }, Map)
		map[1]    = key_type
		map[2]	  = value_type
		map.size  = size
		return map
	end
end 

do
	local Tuple = newmetatype(tags.TUPLE)
	function Tuple:encode(encoder)
		encoder.writer:varint(#self)
		for i=1, #self do 
			encodeid(encoder, self[i])	
		end
	end
	
	function Tuple:decode(decoder, item)
		local size  = encoder.reader:varint()
		for i=1, size do 
			item[i] = decodeid(decoder)
		end 
	end
	
	function meta.tuple(types)
		local tuple = setmetatable({}, Tuple)
		for i=1, #types do 
			tuple[i] = types[i]
		end 
		return tuple
	end
end 

do 
	local Union = newmetatype(tags.UNION)
	function Union:encode(encoder)
		encoder.writer:varint(self.size)
		encoder.writer:varint(#self)
		
		for i=1, #self do 
			encodeid(encoder, self[i])
		end 
	end
	
	function Union:decode(decoder, item)
		item.size = encoder.reader:varint()
		for i=1, size do 
			item[i] = decodeid(decoder)
		end 
	end 
	 
	function meta.union(types, size)
		if size == nil then size = 0 end 
		local union = setmetatable({}, Union)
		for i=1, #types do 
			union[i] = types[i]
		end 
		
		union.size = size 
		return union
	end
end 

do
	local Object = newmetatype(tags.OBJECT)
	function Object:encode(encoder)
		encodeid(encoder, self[1])
	end
	
	function Object:decode(decoder, item)
		item[1]		= decodeid(decoder)
	end
	
	function meta.object(element_type)
		local obj = setmetatable({}, Object)
		obj[1]	  = element_type
		return obj
	end
end 

do 
	local Embedded = newmetatype(tags.EMBEDDED)
	function Embedded:encode(encoder)
		encodeid(encoder, self[1])
	end 
	
	function Embedded:decode(decoder, item)
		item[1] = decodeid(decoder)
	end 
	
	function meta.embedded(element_type)
		local emb = setmetatable({}, Embedded)
		emb[1]	  = element_type
		return emb
	end
end 

do 
	local Semantic = newmetatype(tags.SEMANTIC)
	function Semantic:encode(encoder)
		encoder.writer:stream(self.identifier)
		encodeid(encoder, self[1])
	end
	
	function Semantic:decode(decoder, item)
		item.identifier = decoder.reader:stream()
		item[1] = decodeid(decoder)
	end 
	 
	function meta.semantic(id, element_type)
		local semantic 		= setmetatable({}, SemanticMeta)
		semantic[1]	   		= element_type
		semantic.identifier = id 
		return semantic
	end
end 

do 
	local Align   = { tags = tags.ALIGN } Align.__index = Align
	function Align:encode(encoder)
		encoder.writer:varint(varint)
		encodeid(encoder, self[1])
	end  
	
	function Align:decode(decoder, item)
		item.size = decoder.reader:varint()
		item[1]   = decodeid(decoder)
	end
	
	local function fixedalignencode(self, encoder)
		encodeid(encoder, self[1])
	end
	
	local function fixedaligndecode(self, decoder, item)
		item[1] = decodeid(decoder)
	end 
	
	local function newaligntype(tag, size)
		local type = newmetatype(tag)
		type.fixedsize = size 
		type.encode = fixedalignencode
		type.decode = fixedaligndecode
		return type 
	end 
	
	local align_tables = 
	{
		[1] = newaligntype(tags.ALIGN1, 1),
		[2] = newaligntype(tags.ALIGN2, 2),
		[4] = newaligntype(tags.ALIGN4, 4),
		[8] = newaligntype(tags.ALIGN8, 8)
	}
	
	function meta.align(element_type, size)
		local align = { }
		align[1]    = element_type
		align.size  = size 
		if align_tables[size] == nil then 
			setmetatable(align, Align)
		else 
			setmetatable(align, align_tables[size])
		end 
	end
end 

do 
	local Uint = newmetatype(tags.UINT)
	function Uint:encode(encoder)
		encoder.writer:varint(self.size)
	end
	
	function Uint:decode(decoder, item)
		item.size = decoder.reader:varint()
	end 
	
	function meta.uint(size)
		local uint = setmetatable({}, Uint)
		uint.size  = size 
		return uint
	end 
end

do  
	local Sint = newmetatype(tags.UINT)
	function Sint:encode(encoder)
		encoder.writer:varint(self.size)
	end
	
	function Sint:decode(decoder, item)
		item.size = decoder.reader:varint()
	end 
	
	function meta.int(size)
		local sint = setmetatable({}, Sint)
		sint.size  = size 
		return sint
	end
end 