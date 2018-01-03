import std.algorithm: sort;
import std.range: enumerate;
import std.conv: to;

struct Timeseries(T) {
private:
  immutable(T)[] _serie;
  size_t[ulong] _index;
  
public:
  pure this(T[ulong] _array) {
    auto _buffer = new T[_array.length];
    auto indexedKeys = enumerate(sort(_array.keys()));
    foreach(i, epoch; indexedKeys) {
      _index[epoch] = i;
      _buffer[i] = _array[epoch];
    }
    _serie ~= to!(immutable(T)[])(_buffer);
  }
  
  @safe pure T value(ulong epoch) {
    if(epoch !in _index) return double.nan;
    
    return _serie[index[epoch]];
  }
  
  @property @safe pure size_t[ulong] index() {
    return _index;
  }
  
  @property @safe pure immutable(T)[] values() {
    return _serie;
  }
}

unittest {
  import std.math: isNaN;
  alias DoubleTS = Timeseries!(double); 
  DoubleTS serie = DoubleTS([5000: 2., 5001:4., 5002:-1.]);
  
  assert(serie.value(5000) == 2.);
  assert(isNaN(serie.value(5003)));
  
  size_t[ulong] expectedIndex = [5000: 0, 5001: 1, 5002: 2];
  assert(serie.index == expectedIndex);
  
  assert(serie.values == [2., 4., -1.]);
  
}