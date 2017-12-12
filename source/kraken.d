module kraken;

import std.net.curl: get, CurlException;
import std.string;
import std.json;
import std.stdio;

struct ServerTime {
  long unixTime;
  string rfc1123;
}

bool hasResourceError(ref JSONValue[string] document) pure
{
  JSONValue[] error = document["error"].array;

  if(error.length > 0)
  {
    return true;
  }

  return false;
}

void getServerTime(ref ServerTime serverTime)
{
  string result = cast(string)get("https://api.kraken.com/0/public/Time");
  JSONValue[string] doc = parseJSON(result).object;

  auto hasError = hasResourceError(doc);

  if(hasError == false)
  {
    JSONValue[string] content = doc["result"].object;
    serverTime.unixTime = content["unixtime"].integer;
    serverTime.rfc1123 = content["rfc1123"].str;
  }
  else {
    serverTime.unixTime = 0;
    serverTime.rfc1123 = "";
  }
}

// unittest
// {
//   ServerTime serverTime;
//   getServerTime(serverTime);
//   assert(serverTime.unixTime != 0);
// }
