import std.algorithm.sorting: sort;
import std.range: enumerate;
import std.conv: to;
import std.math: isNaN;

class TimeserieException: Exception {
  this(string s) {
    super(s);
  }
}

enum NaNPolicy {drop, complete, nothing};

struct Timeserie(T) {
private:
  immutable(T)[] _serie;
  size_t[ulong] _index;
  bool _hasNaN;
  
  pure void addValue(ulong epoch, size_t i, T value) {
    _index[epoch] = i;
    _serie ~= to!(immutable(T))(value);
    if(isNaN(value)) _hasNaN = true;
  }
  
public:
  pure this(T[ulong] _array, NaNPolicy _policy) {
    auto indexedKeys = enumerate(sort(_array.keys()));
    size_t notNaNIndex = 0;
    foreach(i, epoch; indexedKeys) {
      auto currentValue = _array[epoch];
      final switch(_policy) {
        
        case NaNPolicy.drop:
        if(!isNaN(currentValue)) {
          addValue(epoch, notNaNIndex, currentValue);
          ++notNaNIndex;
        }
        break;
        
        case NaNPolicy.nothing:
        addValue(epoch, i, currentValue);
        break;
        
        case NaNPolicy.complete:
        _index[epoch] = i;
        if(isNaN(currentValue)) {
          long k = i - 1;
          auto lastValue = currentValue;
          while(isNaN(lastValue) && k > 0) {
            lastValue = _serie[k];
            --k;
          }
          currentValue = lastValue;
        }
        addValue(epoch, i, currentValue);
        break;
      }
    }
  }
  
  pure this(this) {
    _serie = _serie.dup;
    _index = _index.dup;
    _hasNaN = _hasNaN;
  }
  
  T value(ulong epoch) {
    if(epoch !in _index) throw new TimeserieException("Epoch not in index");
    
    return _serie[index[epoch]];
  }
  
  @property @safe pure size_t[ulong] index() {
    return _index;
  }
  
  @property @safe pure immutable(T)[] values() {
    return _serie;
  }
  
  @safe pure bool hasNaN() {
    return _hasNaN;
  }  
}

unittest {
  double[ulong] values = [6000: 40., 6001: double.nan, 6002: -10., 5000: 2., 5001:4., 5002:-1., 5010: double.nan];
  alias DoubleTS = Timeserie!(double); 
  DoubleTS serie = DoubleTS(values, NaNPolicy.nothing);
  
  assert(serie.hasNaN());
  assert(serie.value(5000) == 2.);
  try {
    serie.value(5003);
  } catch (TimeserieException e) {
    assert(e !is null);
  }
  
  size_t[ulong] expectedIndex = [5000: 0, 5001: 1, 5002: 2, 5010: 3, 6000: 4, 6001: 5, 6002: 6];
  assert(serie.index == expectedIndex);
  
  assert(serie.values[0..3] == [2., 4., -1.]);
  assert(serie.values[4] == 40.);
  
  auto clone = serie;
  assert(clone !is serie);
  assert(clone.values[0..3] == [2., 4., -1.]);
  
  DoubleTS clean = DoubleTS(values, NaNPolicy.complete);
  assert(!clean.hasNaN());
  assert(clean.index == expectedIndex);
  assert(clean.values == [2., 4., -1., -1., 40., 40., -10.]);
  
  size_t[ulong] drilledIndex = [5000: 0, 5001: 1, 5002: 2, 6000: 3, 6002: 4];
  DoubleTS drilled = DoubleTS(values, NaNPolicy.drop);
  assert(!drilled.hasNaN());
  assert(drilled.index == drilledIndex);
  assert(drilled.values == [2., 4., -1., 40., -10.]);
  
  double[ulong] nanValues = [5000: double.nan, 5001:double.nan, 5002:-1.];
  size_t[ulong] uncompletableIndex = [5000: 0, 5001: 1, 5002: 2];
  DoubleTS uncompletable = DoubleTS(nanValues, NaNPolicy.complete);
  assert(uncompletable.hasNaN());
  assert(uncompletable.index == uncompletableIndex);
}