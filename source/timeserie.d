import std.algorithm.sorting: sort;
import std.algorithm.iteration: map;
import std.range: enumerate;
import std.conv: to;
import std.math: isNaN;
import std.array: array;
import std.traits: isFloatingPoint;

class TimeserieException: Exception {
  this(string s) {
    super(s);
  }
}

enum NaNPolicy {drop, complete, nothing};

struct Timeserie(T) if (isFloatingPoint!T) {
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
  
  pure this(size_t[ulong] _index, immutable(T)[] _serie, bool _hasNaN) {
    this._index = _index.dup;
    this._serie = _serie.dup;
    this._hasNaN = _hasNaN;
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
  
  @property @safe pure bool hasNaN() {
    return _hasNaN;
  }
  
  Timeserie!T apply(T function(T) fun) {
    auto _newSerie = map!(fun)(_serie);
    return Timeserie!T(_index, to!(immutable(T)[])(_newSerie.array), _hasNaN);
  }
  
  Timeserie opBinary(string op)(Timeserie!T rhs) if (op == "+") {
    if(_serie.length != rhs._serie.length || _index != rhs._index) throw new TimeserieException("Not compatible timeseries");
    
    auto result = new T[_serie.length];
    result[] = _serie[] + rhs._serie[];
    return Timeserie(_index, to!(immutable(T)[])(result), _hasNaN || rhs._hasNaN);
  }
  
  Timeserie opBinary(string op)(Timeserie!T rhs) if (op == "-") {
    if(_serie.length != rhs._serie.length || _index != rhs._index) throw new TimeserieException("Not compatible timeseries");
    
    auto result = new T[_serie.length];
    result[] = _serie[] - rhs._serie[];
    return Timeserie(_index, to!(immutable(T)[])(result), _hasNaN || rhs._hasNaN);
  }
  
  Timeserie opBinary(string op)(Timeserie!T rhs) if (op == "*") {
    if(_serie.length != rhs._serie.length || _index != rhs._index) throw new TimeserieException("Not compatible timeseries");
    
    auto result = new T[_serie.length];
    result[] = _serie[] * rhs._serie[];
    return Timeserie(_index, to!(immutable(T)[])(result), _hasNaN || rhs._hasNaN);
  }
  
  Timeserie opBinary(string op)(Timeserie!T rhs) if (op == "/") {
    if(_serie.length != rhs._serie.length || _index != rhs._index) throw new TimeserieException("Not compatible timeseries");
    foreach(v; rhs._serie) {
      if(v == 0) throw new TimeserieException("Divider has some zeros");
    }
    
    auto result = new T[_serie.length];
    result[] = _serie[] / rhs._serie[];
    return Timeserie(_index, to!(immutable(T)[])(result), _hasNaN || rhs._hasNaN);
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

unittest {
  double[ulong] values = [5000: 2., 5001:4., 5002:-1.];
  auto fun = (double a) => a + 1;
  auto ts = Timeserie!double(values, NaNPolicy.nothing);
  auto newTs = ts.apply(fun);
  size_t[ulong] expectedIndex = [5000: 0, 5001: 1, 5002: 2];
  assert(newTs.index == expectedIndex);
  assert(newTs.values == [3., 5., 0.]);
}

unittest {
  double[ulong] values = [5000: 2., 5001:4., 5002:-1., 5003: -5., 5004: -12.];
  auto lts = Timeserie!double(values, NaNPolicy.nothing);
  double[ulong] otherValues = [5000: -2., 5001:-4., 5002:1., 5003: 5., 5004: 12.];
  auto rts = Timeserie!double(otherValues, NaNPolicy.nothing);
  assert((lts + rts).values == [0., 0., 0., 0., 0.]);
  assert((lts - rts).values == [4., 8., -2., -10., -24.]);
  assert((rts - lts).values == [-4., -8., 2., 10., 24.]);
  assert((lts * rts).values == [-4., -16., -1., -25., -144.]);
  assert((lts / rts).values == [-1., -1., -1., -1., -1.]);
}

unittest {
  double[ulong] values = [5000: 2., 5001: double.nan, 5002:-1., 5003: -5., 5004: -12.];
  auto lts = Timeserie!double(values, NaNPolicy.nothing);
  double[ulong] otherValues = [5000: -2., 5001:-4., 5002:1., 5003: double.nan, 5004: 12.];
  auto rts = Timeserie!double(otherValues, NaNPolicy.nothing);
  assert(isNaN((lts + rts).values[1]));
  assert(isNaN((lts + rts).values[3]));
  assert(isNaN((lts - rts).values[1]));
  assert(isNaN((rts - lts).values[3]));
  assert(isNaN((lts * rts).values[1]));
  assert(isNaN((lts * rts).values[3]));
  assert(isNaN((lts / rts).values[1]));
  assert(isNaN((lts / rts).values[3]));
}

unittest {
  double[ulong] values = [5000: 2., 5001: double.nan, 5002:-1., 5003: -5., 5004: -12.];
  auto lts = Timeserie!double(values, NaNPolicy.nothing);
  double[ulong] otherValues = [5000: -2., 5001:-4., 5002:1., 5003: double.nan, 5004: 12.];
  auto rts = Timeserie!double(otherValues, NaNPolicy.nothing);
  assert(isNaN((lts + rts).values[1]));
  assert(isNaN((lts + rts).values[3]));
  assert(isNaN((lts - rts).values[1]));
  assert(isNaN((rts - lts).values[3]));
  assert(isNaN((lts * rts).values[1]));
  assert(isNaN((lts * rts).values[3]));
  assert(isNaN((lts / rts).values[1]));
  assert(isNaN((lts / rts).values[3]));
}

unittest {
  double[ulong] values = [5000: 2., 5001: 0., 5002:-1., 5003: -5., 5004: -12.];
  auto lts = Timeserie!double(values, NaNPolicy.nothing);
  double[ulong] otherValues = [5000: -2., 5001:-4., 5002:1., 5003: 0., 5004: 12.];
  auto rts = Timeserie!double(otherValues, NaNPolicy.nothing);
  try {
    auto wrongTs = lts / rts;
  } catch(TimeserieException e) {
    assert(e !is null);
  }
}

struct TimeserieBundle(T) if (isFloatingPoint!T) {
private:
  size_t[ulong] _index;
  Timeserie!T[string] _series;
  
public:
  void add_timeserie(ref Timeserie!T _serie, string name) {
    if(_index.length == 0) _index = _serie.index;
    
    if(_index != _serie.index) throw new TimeserieException("Serie\'s index not equals bundle\'s index");
    
    _series[name] = _serie;
  }
  
  @property @safe pure size_t[ulong] index() {
    return _index;
  }
  
  Timeserie!T timeserie(string name) {
    if(name !in _series) throw new TimeserieException("Series not in bundle");
    
    return _series[name];
  }
  
  T value(string name, ulong epoch) {
    auto ts = timeserie(name);
    
    return ts.value(epoch);
  }
}

unittest {
  double[ulong] values = [5000: 2., 5001:4., 5002:-1.];
  auto ts = Timeserie!double(values, NaNPolicy.nothing);
  auto bundle = TimeserieBundle!double();
  bundle.add_timeserie(ts, "values");
  
  size_t[ulong] expectedIndex = [5000: 0, 5001: 1, 5002: 2];
  assert(bundle.index == expectedIndex);
  assert(bundle.timeserie("values") == ts);
  try {
    auto wrongValues = bundle.timeserie("unknown");
  } catch (TimeserieException e) {
    assert(e !is null);
  }
  
  assert(bundle.value("values", 5000) == 2.);
  try {
    auto wrongValue = bundle.value("values", 5003);
  } catch (TimeserieException e) {
    assert(e !is null);
  }
}
