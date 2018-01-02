struct CashFlow {
private:
  double amount;
  size_t epoch;
public:
  @safe pure this(size_t _epoch, double _amount) immutable {
    amount = _amount;
    epoch = _epoch;
  }
  
  @safe pure double value(size_t i) immutable {
    if(i < epoch) return 0;
    
    return amount;
  }
}

interface FinancialInstrument {
  @safe pure double value(size_t) immutable;
  @safe pure bool hasCashFlow(size_t) immutable;
  @safe pure immutable(CashFlow) cashFlow(size_t) immutable;
}


class FutureContract: FinancialInstrument {
private:
  double entryPrice;
  size_t entryEpoch;
  size_t expiration;
  immutable(double)[] prices;
  
public: 
  @safe this(double _entryPrice, size_t _entryEpoch, size_t _expiration, double[] _values) immutable {
    entryPrice = _entryPrice;
    entryEpoch = _entryEpoch;
    expiration = _expiration;
    prices = _values.idup;
  }
  
  @safe pure double value(size_t i) immutable {
    if(i > expiration) return 0;
    
    if(i < entryEpoch) return 0;
    
    if(i >= prices.length) return 0;
    
    return entryPrice - prices[i];
  }
  
  @safe pure bool hasCashFlow(size_t i) immutable {
    return this.value(i) == 0;
  }
  
  @safe pure immutable(CashFlow) cashFlow(size_t i) immutable {
    if (i == entryEpoch) {
      return immutable(CashFlow)(i, -prices[i]*0.2);
    } else {
      return immutable(CashFlow)(i, this.value(i));
    }
  }
}

unittest {
  import std.math;
  auto instrument = new immutable(FutureContract)(105.8, 2, 3, [100., 102.0, 105.6, 111.23, 105.7]);
  
  assert(approxEqual(instrument.value(2), .2));
  assert(instrument.value(0) == 0);
  assert(instrument.value(4) == 0);
  assert(instrument.value(6) == 0);
  
  auto marginDeposit = instrument.cashFlow(2);
  assert(approxEqual(marginDeposit.value(2), -.2*105.6));
}