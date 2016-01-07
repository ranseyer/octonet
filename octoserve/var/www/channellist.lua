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

if #arg> 0 then
  method="GET"
  query="select=m3u"
  proto = "HTTP/1.0"
end

function SendError(err,desc)
  http_print(proto.." "..err)
  http_print("Content-Type: text/html")
  http_print()
  local file = io.open("e404.html")
  if file then
    local tmp = file:read("*a")
    tmp = string.gsub(tmp,"404 Not Found",err .. " " .. desc)
    http_print(tmp)
    file:close()
  end
end

function CreateM3U(host)
   local m3u = {}
   table.insert(m3u,"#EXTM3U".."\n")
   
   local file = io.open("/config/ChannelList.json")
   if file then
      local json = file:read("*a")
      file:close()
      local newdecoder = require("lunajson.decoder")
      local decode = newdecoder()
      local channellist = decode(json)
      for _,group in ipairs(channellist.GroupList) do
         for _,channel in ipairs(group.ChannelList) do
            table.insert(m3u,"#EXTINF:0,"..group.Title.." - "..channel.Title.."\n")
            table.insert(m3u,"rtsp://"..host..":554/?"..channel.Request.."\n")
         end
      end
   else
      local SourceList = LoadSourceList()
      for _,f in pairs(SourceList) do
         if f.system == "dvbs" or f.system == "dvbs2" then
            for _,c in ipairs(f.ChannelList) do
               table.insert(m3u,"#EXTINF:0,"..f.title.." - "..c.title.."\n")
               table.insert(m3u,"rtsp://"..host..":554/?src="..f.src.."&"..c.request.."\n")
            end
         else
            for _,c in ipairs(f.ChannelList) do
               table.insert(m3u,"#EXTINF:0,"..f.title.." - "..c.title.."\n")
               table.insert(m3u,"rtsp://"..host..":554/?"..c.request.."\n")
            end
         end
      end
   end
   return table.concat(m3u)
end

function JSONSource(host,SourceList,Title,System)
   local json = {}
   local src = ""
   local sep1 = "\n"
   local sep2 = "\n"

   table.insert(json,' "'..Title..'": [')
   sep1 = "\n"
   for _,f in pairs(SourceList) do
      if not System or f.system == System or f.system == System.."2" then
         table.insert(json,sep1)
         sep1 = ",\n"
         table.insert(json,'  {\n')
         table.insert(json,'   "Title": "'..f.title..'",\n')
         table.insert(json,'   "ChannelList": [')

         if System == "dvbs" then
            src = 'src='..f.src..'&'
         end

         sep2 = "\n"
         for _,c in ipairs(f.ChannelList) do
            table.insert(json,sep2)
            sep2 = ",\n"
            table.insert(json,'     {\n')
            table.insert(json,'      "Title": "'..string.gsub(c.title,'"','\\"')..'",\n')
            table.insert(json,'      "Request": "?'..src..c.request..'",\n')
            table.insert(json,'      "Tracks": ['..c.tracks..']\n')
            table.insert(json,'     }')
         end

         table.insert(json,'\n    ]\n')
         table.insert(json,'  }')
      end
   end
   table.insert(json,'\n ]')

   return table.concat(json)
end

function CreateJSON(host)
   local data = nil
   local file = io.open("/config/ChannelList.json")
   if file then
      data = file:read("*a")
      file:close()
   else
      local SourceList = LoadSourceList()
      local json = {}
      table.insert(json,"{\n")

      table.insert(json,JSONSource(host,SourceList,"GroupList",nil) .. ",\n")
--~       table.insert(json,JSONSource(host,SourceList,"SourceListSat","dvbs") .. ",\n")
--~       table.insert(json,JSONSource(host,SourceList,"SourceListCable","dvbc") .. ",\n")
--~       table.insert(json,JSONSource(host,SourceList,"SourceListTer","dvbt") .. "\n")

      table.insert(json,"}\n")
      data = table.concat(json)
   end
   return data
end

function LoadSourceList()
   local db = require("DataBase")
   local SourceList = {}

   for _,f in ipairs(db.SourceList) do
     f.ChannelList = {}
     SourceList[f.refid] = f
   end

   for _,c in ipairs(db.ChannelList) do
     local f = SourceList[c.refid]
     if f then
       table.insert(f.ChannelList,c)
     end
   end
   return SourceList
end

if method == "GET" then
  local filename = nil
  local contenttype = nil
  local data = nil

  if string.match(query,"select=m3u") then
    filename = "channellist.m3u"
    contenttype = "text/m3u; charset=utf-8"
    data = CreateM3U(host)
  elseif string.match(query,"select=json") then
    contenttype = "application/json; charset=utf-8"
    data = CreateJSON(host)
  end

  if data then
    http_print(proto.." 200" )
    http_print("Pragma: no-cache")
    http_print("Cache-Control: no-cache")
    http_print("Content-Type: "..contenttype)
    if filename then
      http_print('Content-Disposition: filename="'..filename..'"')
    end
    http_print(string.format("Content-Length: %d",#data))
    http_print()
    http_print(data)
  else
    SendError("404","not found")
  end

else
  SendError("500","What")
end
