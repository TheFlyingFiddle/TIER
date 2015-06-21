local format	= require"format"

local core = { }
function core.getid(mapping)
    local id = mapping.id
    if id == nil then
        local buffer  = format.outmemorystream()
        local encoder = core.encoder(format.writer(buffer), false)
        encoder.types = { }
        encoder.types[mapping] = encoder.writer:getposition()
        mapping:encodemeta(encoder)
        encoder:close()
        local body = buffer:getdata()
        id = format.packvarint(mapping.tag) .. format.packvarint(#body) .. body
    end
    return id
end

local Encoder = { }
Encoder.__index = Encoder

--Encodes data using the specified mapping.
function Encoder:encode(mapping, data)
   self.writer:flushbits()
   if self.usemetadata then
      self.writer:raw(core.getid(mapping))
   end
   
   mapping:encode(self, data)	
   self.writer:flush()
end

--Finishes any pending operations and closes 
--the encoder. After this operation the encoder can no longer be used.
function Encoder:close()
   self.writer:flush()
   self.objects = nil;
   self.writer  = nil;
   setmetatable(self, nil);
end

function core.encoder(writer, usemetadata)
	local encoder = setmetatable({ }, Encoder)
    encoder.writer = writer;
	encoder.objects = { }
	encoder.usemetadata = usemetadata
	return encoder	
end


local Decoder = { }
Decoder.__index = Decoder

--Decodes using the specified mapping.
function Decoder:decode(mapping)
   self.reader:discardbits()   
   if self.usemetadata then 
      local id = core.getid(mapping)
      local meta_types = self.reader:raw(#id)
      assert(meta_types == id)
   end 
   
   return mapping:decode(self)
end

--Closes the decoder.
--After this operation is performed the decoder can no longer be used.
function Decoder:close()
   self.objects = nil
   self.reader  = nil
   setmetatable(self, nil)
end

--Creates a decoder
function core.decoder(reader, usemetadata)
	local decoder = setmetatable({ }, Decoder)
    decoder.reader  = reader
	decoder.objects = { }
	decoder.usemetadata = usemetadata
	return decoder
end

return core