import Toybox.Lang;
import Toybox.Math;

class SlidingAverage {
    private var _buffer as Array<Float>;
    private var _size as Number;
    private var _head as Number;
    private var _count as Number;

    function initialize(size as Number) {
        _size = size;
        _head = 0;
        _count = 0;
        _buffer = new Array<Float>[size];
        for (var i = 0; i < size; i++) {
            _buffer[i] = 0.0f;
        }
    }

    function push(value as Float) as Void {
        _buffer[_head] = value;
        _head = (_head + 1) % _size;
        if (_count < _size) {
            _count++;
        }
    }

    function getAverage() as Float {
        if (_count == 0) { return 0.0f; }
        var sum = 0.0f;
        for (var i = 0; i < _count; i++) {
            sum += _buffer[i];
        }
        return sum / _count;
    }

    function getCount() as Number {
        return _count;
    }
}

class NormalizedPower {
    private var _rolling as SlidingAverage;
    private var _sum4th as Double;
    private var _count as Number;

    function initialize() {
        _rolling = new SlidingAverage(30);
        _sum4th = 0.0d;
        _count = 0;
    }

    function push(power as Float) as Void {
        _rolling.push(power);
        if (_rolling.getCount() >= 30) {
            var avg = _rolling.getAverage();
            var sq = avg * avg;
            _sum4th += (sq * sq).toDouble();
            _count++;
        }
    }

    function getNP() as Float {
        if (_count == 0) { return 0.0f; }
        return Math.pow(_sum4th / _count, 0.25).toFloat();
    }
}
