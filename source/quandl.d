module quandl;

import std.net.curl: get;
import std.string;
import std.json;
import std.algorithm: map;
import config: QUANDL_API_KEY;

enum Datatype {OPEN, HIGH, LOW, LAST, CHANGE, SETTLE, VOLUME, OPEN_INTEREST};

string getDataset(string databaseCode, string instrumentCode)
{
	string url = format("https://www.quandl.com/api/v3/datasets/%s/%s/data.json?api_key=%s", 
		 databaseCode, instrumentCode, QUANDL_API_KEY);
	
	string response = cast(string)get(url);
	
	return response;
}

auto getPrice(Datatype type, string rawData)
{
	
	JSONValue[string] document = parseJSON(rawData).object;
	
	JSONValue[string] datasetDoc = document["dataset_data"].object;
	
	JSONValue[] data = datasetDoc["data"].array;
	
	return map!((a) => a[6].floating)(data);
}


unittest
{
	assert(getPrice(Datatype.SETTLE, `{"dataset_data":{"data":[[0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 9.0]]}}`)[0] == 6.);
}