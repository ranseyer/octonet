#!/usr/bin/lua

local host = os.getenv("HTTP_HOST")
local proto = os.getenv("SERVER_PROTOCOL")
local query = os.getenv("QUERY_STRING")
local method = os.getenv("REQUEST_METHOD")
local clength = os.getenv("CONTENT_LENGTH")
local ctype = os.getenv("CONTENT_TYPE")

function http_print(s)
  if s then
    io.stdout:write(tostring(s).."\r\n")
  else
    io.stdout:write("\r\n")
  end
end

function SendError(err,desc)
  http_print(proto.." "..err)
  http_print()
  local file = io.open("e404.html")
  if file then
    local tmp = file:read("*a")
    tmp = string.gsub(tmp,"404 Not Found",err .. " " .. desc)
    http_print(tmp)
    file:close()
  end
end

function ReadLine(file)
   local tmp = file:read("*l")
   if tmp then
      local values = {}
      local value
      for value in string.gmatch(tmp,"(%d+)") do
         table.insert(values,tonumber(value))
      end
      return values
   else
      return nil
   end
end

if method == "GET" then
   data = ""
      
   local file = io.open("/tmp/Temperatur.log")
   if file then
      local NumSensors,Interval,FanState,d = unpack(ReadLine(file))
      local Values = {}
      while true do
         local tmp = ReadLine(file)
         if tmp then
            table.insert(Values,tmp)
         else
            break
         end
      end
      file:close()
      
      data = "{\n"
      data = data .. "\"NumSensors\":\""..NumSensors.."\",\n"
      data = data .. "\"Interval\":\""..Interval.."\",\n"
      data = data .. "\"FanState\":\""..FanState.."\",\n"
      
      data = data .. "\"SensorData\": [\n"
      local i,j
      for i = 1,NumSensors,1 do
         data = data .. "["
         
         for j = #Values,1,-1 do
            local tmp = Values[j]
            data = data .. "\"" .. tmp[i] .. "\""
            if j > 1 then 
               data = data .. ","
            end
         end
         
         if i < NumSensors then 
            data = data .. "],\n" 
         else 
            data = data .. "]\n" 
         end
      end
      data = data .. "]\n"
      data = data .. "}\n"
   end


   http_print(proto.." 200" )
   http_print("Pragma: no-cache")
   http_print("Content-Type: application/json; charset=UTF-8")
   http_print(string.format("Content-Length: %d",#data))
   http_print()
   http_print(data)
else
   SendError("500","What")  
end

