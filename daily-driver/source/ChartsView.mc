import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;
import Toybox.UserProfile;

class ChartsView extends WatchUi.DataField {

    private var _width as Number;
    private var _height as Number;

    private var _power5s as SlidingAverage;
    private var _hr3s as SlidingAverage;
    private var _np as NormalizedPower;

    private var _currentSpeed as Float;
    private var _avgSpeed as Float;
    private var _topSpeed as Float;
    private var _cadence as Float;
    private var _distance as Float;
    private var _totalAscent as Number;
    private var _elapsedTime as Number;
    private var _avgPower as Float;
    private var _avgHr as Float;

    private var _hrZoneBounds as Array<Number>?;
    private var _powerZoneBounds as Array<Number>?;
    private var _zonesLoaded as Boolean;
    private var _ftp as Number;
    private var _lthr as Number;
    private var _hrZoneRatios as Array<Float>?;
    private var _powerZoneRatios as Array<Float>?;

    private var _powerZoneColors as Array<Number>;
    private var _powerZoneColorsDark as Array<Number>;
    private var _hrZoneColors as Array<Number>;
    private var _hrZoneColorsDark as Array<Number>;
    private var _fgColor as Number;
    private var _dimColor as Number;
    private var _isDark as Boolean;

    function initialize() {
        DataField.initialize();
        _width = 282;
        _height = 470;
        _power5s = new SlidingAverage(5);
        _hr3s = new SlidingAverage(3);
        _np = new NormalizedPower();
        _currentSpeed = 0.0f;
        _avgSpeed = 0.0f;
        _topSpeed = 0.0f;
        _cadence = 0.0f;
        _distance = 0.0f;
        _totalAscent = 0;
        _elapsedTime = 0;
        _avgPower = 0.0f;
        _avgHr = 0.0f;
        _hrZoneBounds = null;
        _powerZoneBounds = null;
        _zonesLoaded = false;
        _ftp = 0;
        _lthr = 0;
        _hrZoneRatios = null;
        _powerZoneRatios = null;
        _powerZoneColors = [0xC89BD8, 0xB580CC, 0xA268C0, 0x8E50B4, 0x7B3DA8, 0x6A2E9C, 0x5A2090] as Array<Number>;
        _powerZoneColorsDark = [0xDDB8E8, 0xCC99DD, 0xBB80D4, 0xAA66CC, 0x9955BB, 0x8844AA, 0x7733AA] as Array<Number>;
        _hrZoneColors = [0xD8A0A0, 0xCC7878, 0xCC5050, 0xDD3333, 0xBB2222] as Array<Number>;
        _hrZoneColorsDark = [0xE8B8B8, 0xDD9090, 0xDD6666, 0xEE4444, 0xDD3333] as Array<Number>;
        _fgColor = Graphics.COLOR_WHITE;
        _dimColor = Graphics.COLOR_DK_GRAY;
        _isDark = true;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();
    }

    private function loadZones() as Void {
        if (_zonesLoaded) { return; }
        _zonesLoaded = true;
        _hrZoneBounds = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_BIKING);
        if (_hrZoneBounds == null || _hrZoneBounds.size() < 2) {
            _hrZoneBounds = [0, 120, 140, 155, 170, 185] as Array<Number>;
        }
        var profile = UserProfile.getProfile();
        if (profile != null && profile.restingHeartRate != null) {
            _hrZoneBounds[0] = profile.restingHeartRate;
        }

        if (_hrZoneBounds != null && _hrZoneBounds.size() >= 5) {
            _lthr = _hrZoneBounds[4];
        }

        if (UserProfile has :getPowerZones) {
            _powerZoneBounds = UserProfile.getPowerZones(Activity.SPORT_CYCLING);
        }

        var ftp = 250;
        if (UserProfile has :getFunctionalThresholdPower) {
            var ftpVal = UserProfile.getFunctionalThresholdPower(Activity.SPORT_CYCLING);
            if (ftpVal != null) { ftp = ftpVal; }
        }
        _ftp = ftp;

        if (_powerZoneBounds == null || _powerZoneBounds.size() < 2) {
            _powerZoneBounds = [0, (ftp*0.55).toNumber(), (ftp*0.75).toNumber(),
                (ftp*0.90).toNumber(), (ftp*1.05).toNumber(), (ftp*1.20).toNumber(),
                (ftp*1.50).toNumber()] as Array<Number>;
        }

        _hrZoneRatios = computeZoneRatios(_hrZoneBounds);
        _powerZoneRatios = computeZoneRatios(_powerZoneBounds);
    }

    private function computeZoneRatios(bounds as Array<Number>?) as Array<Float> {
        if (bounds == null || bounds.size() < 2) {
            return [0.0f, 1.0f] as Array<Float>;
        }
        var numZones = bounds.size() - 1;
        var weights = getZoneWeights(numZones);
        var total = 0.0f;
        for (var i = 0; i < numZones; i++) { total += weights[i]; }
        var ratios = new Array<Float>[numZones + 1];
        ratios[0] = 0.0f;
        var cum = 0.0f;
        for (var i = 0; i < numZones; i++) {
            cum += weights[i];
            ratios[i + 1] = cum / total;
        }
        return ratios;
    }

    private function getZoneWeights(numZones as Number) as Array<Float> {
        if (numZones >= 6) {
            return [1.0f, 3.0f, 2.5f, 2.5f, 2.0f, 1.0f, 1.0f] as Array<Float>;
        }
        return [1.0f, 3.0f, 3.0f, 2.0f, 1.0f] as Array<Float>;
    }

    function compute(info as Activity.Info) as Void {
        loadZones();
        var speed = info.currentSpeed;
        _currentSpeed = (speed != null) ? speed * 3.6f : 0.0f;
        var avgSpd = info.averageSpeed;
        _avgSpeed = (avgSpd != null) ? avgSpd * 3.6f : 0.0f;
        var maxSpd = info.maxSpeed;
        if (maxSpd != null) {
            var maxKmh = maxSpd * 3.6f;
            if (maxKmh > _topSpeed) { _topSpeed = maxKmh; }
        }
        if (_currentSpeed > _topSpeed) { _topSpeed = _currentSpeed; }

        var power = info.currentPower;
        if (power != null) {
            var pf = power.toFloat();
            _power5s.push(pf);
            _np.push(pf);
        }
        var hr = info.currentHeartRate;
        if (hr != null) { _hr3s.push(hr.toFloat()); }
        var cad = info.currentCadence;
        _cadence = (cad != null) ? cad.toFloat() : 0.0f;
        var dist = info.elapsedDistance;
        _distance = (dist != null) ? dist / 1000.0f : 0.0f;
        var ascent = info.totalAscent;
        _totalAscent = (ascent != null) ? ascent : 0;
        var timer = info.timerTime;
        _elapsedTime = (timer != null) ? timer / 1000 : 0;
        var ap = info.averagePower;
        _avgPower = (ap != null) ? ap.toFloat() : 0.0f;
        var ahr = info.averageHeartRate;
        _avgHr = (ahr != null) ? ahr.toFloat() : 0.0f;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var bgColor = getBackgroundColor();
        _isDark = (bgColor == Graphics.COLOR_BLACK);
        _fgColor = _isDark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        _dimColor = _isDark ? 0xAAAAAA : 0x555555;

        dc.setColor(_fgColor, bgColor);
        dc.clear();

        var barW = 28;
        var gaugeH = 155;

        // Draw power bar (left)
        var pwrColors = _isDark ? _powerZoneColorsDark : _powerZoneColors;
        var hrColors = _isDark ? _hrZoneColorsDark : _hrZoneColors;
        var pwrVal = _power5s.getAverage();
        var hrVal = _hr3s.getAverage();
        var pwrActiveZone = getZoneIndex(pwrVal, _powerZoneBounds);
        var hrActiveZone = getZoneIndex(hrVal, _hrZoneBounds);
        var ftpRatio = valueToBarRatio(_ftp.toFloat(), _powerZoneBounds, _powerZoneRatios);
        var ltRatio = valueToBarRatio(_lthr.toFloat(), _hrZoneBounds, _hrZoneRatios);
        drawZoneBar(dc, 0, 0, barW, _height,
            _powerZoneRatios, pwrColors, ftpRatio, pwrActiveZone);
        drawBarTriangle(dc, 0, 0, barW, _height,
            pwrVal, _powerZoneBounds, _powerZoneRatios);
        drawBarLine(dc, 0, 0, barW, _height,
            _np.getNP(), _powerZoneBounds, _powerZoneRatios);

        // Draw HR bar (right)
        drawZoneBar(dc, _width - barW, 0, barW, _height,
            _hrZoneRatios, hrColors, ltRatio, hrActiveZone);
        drawBarTriangle(dc, _width - barW, 0, barW, _height,
            hrVal, _hrZoneBounds, _hrZoneRatios);
        drawBarLine(dc, _width - barW, 0, barW, _height,
            _avgHr, _hrZoneBounds, _hrZoneRatios);

        // Speed gauge centered
        var gx = barW + 2;
        var gw = _width - barW * 2 - 4;
        drawSpeedGauge(dc, gx, 4, gw, gaugeH);

        // Center data panel below gauge
        drawDataPanel(dc, barW, gaugeH + 6, _width - barW * 2, _height - gaugeH - 6);
    }

    private function speedToArcRatio(spd as Float) as Float {
        var avg = _avgSpeed;
        var maxScale = _topSpeed;
        if (avg < 5.0f) { avg = 25.0f; }
        if (maxScale < avg * 1.3f) { maxScale = avg * 1.3f; }
        if (spd <= 0.0f) { return 0.0f; }
        if (spd <= avg) {
            var x = spd / avg;
            return 0.5f * Math.pow(x, 1.6).toFloat();
        }
        var x = (spd - avg) / (maxScale - avg);
        if (x > 1.0f) { x = 1.0f; }
        var ratio = 0.5f + 0.5f * Math.pow(x, 0.5).toFloat();
        return ratio > 1.0f ? 1.0f : ratio;
    }

    private function drawSpeedGauge(
        dc as Graphics.Dc,
        x0 as Number, y0 as Number, w as Number, h as Number
    ) as Void {
        var cx = x0 + w / 2;
        var r = (w / 2) - 16;
        var cy = y0 + r + 6;

        var avg = _avgSpeed;
        if (avg < 5.0f) { avg = 25.0f; }
        var maxScale = _topSpeed;
        if (maxScale < avg * 1.3f) { maxScale = avg * 1.3f; }

        // Background arc
        dc.setPenWidth(20);
        dc.setColor(_isDark ? 0x1A1A1A : 0xE0E0E0, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 180, 0);
        dc.setPenWidth(1);

        // Dot showing current speed position on the arc
        var speedRatio = speedToArcRatio(_currentSpeed);
        if (speedRatio > 0.0f) {
            var dotAngle = Math.PI + (Math.PI * speedRatio);
            var dotX = cx + (r * Math.cos(dotAngle)).toNumber();
            var dotY = cy + (r * Math.sin(dotAngle)).toNumber();
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dotX, dotY, 12);
        }

        // Avg tick at top
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx, cy - r + 8, cx, cy - r - 8);
        dc.setPenWidth(1);

        // 0 below left end of arc
        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - r, cy + 14, Graphics.FONT_XTINY, "0", Graphics.TEXT_JUSTIFY_CENTER);

        // Top speed below right end of arc
        dc.drawText(cx + r, cy + 14, Graphics.FONT_XTINY,
            maxScale.toNumber().toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Current speed - big number
        var speedStr = _currentSpeed > 0.1f ? _currentSpeed.format("%.1f") : "--";
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 28, Graphics.FONT_NUMBER_THAI_HOT, speedStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Avg speed above current speed (smaller)
        if (_avgSpeed > 0.0f) {
            dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 76, Graphics.FONT_NUMBER_MILD, _avgSpeed.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawDataPanel(
        dc as Graphics.Dc,
        x0 as Number, y0 as Number, w as Number, h as Number
    ) as Void {
        var cx = x0 + w / 2;
        var leftCol = x0 + w / 4;
        var rightCol = x0 + w * 3 / 4;
        var rowH = 70;
        var pad = 8;

        // === ROW 1: Power & HR ===
        var r1y = y0 + 4;

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftCol, r1y - 4, Graphics.FONT_XTINY, "POWER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var pwrVal = _power5s.getAverage();
        var pwrStr = pwrVal > 0.0f ? pwrVal.toNumber().toString() : "--";
        dc.drawText(leftCol, r1y + 14, Graphics.FONT_NUMBER_HOT, pwrStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Vertical divider
        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, r1y + 2, cx, r1y + rowH - 2);

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightCol, r1y - 4, Graphics.FONT_XTINY, "HR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var hrVal = _hr3s.getAverage();
        var hrStr = hrVal > 0.0f ? hrVal.toNumber().toString() : "--";
        dc.drawText(rightCol, r1y + 14, Graphics.FONT_NUMBER_HOT, hrStr, Graphics.TEXT_JUSTIFY_CENTER);

        // === Separator ===
        var sepY = r1y + rowH + 4;
        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0 + pad, sepY, x0 + w - pad, sepY);

        // === ROW 2: Avg Power | Avg HR ===
        var r2y = sepY + 6;

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftCol, r2y - 4, Graphics.FONT_XTINY, "AVG PWR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var avgPwrStr = _avgPower > 0.0f ? _avgPower.toNumber().toString() : "--";
        dc.drawText(leftCol, r2y + 14, Graphics.FONT_NUMBER_MILD, avgPwrStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, r2y + 2, cx, r2y + 44);

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightCol, r2y - 4, Graphics.FONT_XTINY, "AVG HR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var avgHrStr = _avgHr > 0.0f ? _avgHr.toNumber().toString() : "--";
        dc.drawText(rightCol, r2y + 14, Graphics.FONT_NUMBER_MILD, avgHrStr, Graphics.TEXT_JUSTIFY_CENTER);

        // === Separator ===
        var sep2Y = r2y + 50;
        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0 + pad, sep2Y, x0 + w - pad, sep2Y);

        // === ROW 3: NP | Cadence ===
        var r3y = sep2Y + 6;

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftCol, r3y - 4, Graphics.FONT_XTINY, "NORM PWR", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var npVal = _np.getNP();
        var npStr = npVal > 0.0f ? npVal.toNumber().toString() : "--";
        dc.drawText(leftCol, r3y + 14, Graphics.FONT_NUMBER_MILD, npStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, r3y + 2, cx, r3y + 44);

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightCol, r3y - 4, Graphics.FONT_XTINY, "CADENCE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var cadStr = _cadence > 0.0f ? _cadence.toNumber().toString() : "--";
        dc.drawText(rightCol, r3y + 14, Graphics.FONT_NUMBER_MILD, cadStr, Graphics.TEXT_JUSTIFY_CENTER);

        // === Separator ===
        var sep3Y = r3y + 50;
        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0 + pad, sep3Y, x0 + w - pad, sep3Y);

        // === ROW 4: Dist | Elev ===
        var r4y = sep3Y + 6;

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftCol, r4y - 4, Graphics.FONT_XTINY, "DIST", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftCol, r4y + 14, Graphics.FONT_NUMBER_MILD,
            _distance.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, r4y + 2, cx, r4y + 44);

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightCol, r4y - 4, Graphics.FONT_XTINY, "ELEV", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightCol, r4y + 14, Graphics.FONT_NUMBER_MILD,
            _totalAscent.toNumber().toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // === Separator ===
        var sep4Y = r4y + 50;
        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0 + pad, sep4Y, x0 + w - pad, sep4Y);

        // === ROW 5: Ride | Time ===
        var r5y = sep4Y + 6;

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftCol, r5y - 4, Graphics.FONT_XTINY, "RIDE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var hrs = _elapsedTime / 3600;
        var mins = (_elapsedTime % 3600) / 60;
        var secs = _elapsedTime % 60;
        var elapsedStr;
        if (hrs > 0) {
            elapsedStr = hrs + ":" + mins.format("%02d") + ":" + secs.format("%02d");
        } else {
            elapsedStr = mins + ":" + secs.format("%02d");
        }
        dc.drawText(leftCol, r5y + 14, Graphics.FONT_NUMBER_MILD, elapsedStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(_isDark ? 0x222244 : 0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx, r5y + 2, cx, r5y + 44);

        dc.setColor(_dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightCol, r5y - 4, Graphics.FONT_XTINY, "TIME", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var now = Toybox.System.getClockTime();
        var timeStr = now.hour.format("%02d") + ":" + now.min.format("%02d");
        dc.drawText(rightCol, r5y + 14, Graphics.FONT_NUMBER_MILD, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function valueToBarRatio(value as Float, bounds as Array<Number>?, ratios as Array<Float>?) as Float {
        if (bounds == null || bounds.size() < 2 || ratios == null) { return 0.0f; }
        var numZones = bounds.size() - 1;
        if (value <= bounds[0]) { return 0.0f; }

        for (var z = 0; z < numZones; z++) {
            var lo = bounds[z].toFloat();
            var hi = bounds[z + 1].toFloat();
            if (value <= hi || z == numZones - 1) {
                var intra = (hi > lo) ? (value - lo) / (hi - lo) : 0.0f;
                if (intra > 1.0f) { intra = 1.0f; }
                return ratios[z] + (ratios[z + 1] - ratios[z]) * intra;
            }
        }
        return 1.0f;
    }

    private function getBarY(y0 as Number, h as Number, value as Float,
        bounds as Array<Number>?, ratios as Array<Float>?) as Number {
        var fillRatio = valueToBarRatio(value, bounds, ratios);
        var valY = y0 + h - (fillRatio * h).toNumber();
        if (valY > y0 + h - 10) { valY = y0 + h - 10; }
        if (valY < y0 + 10) { valY = y0 + 10; }
        return valY;
    }

    private function drawZoneBar(
        dc as Graphics.Dc,
        x0 as Number, y0 as Number, w as Number, h as Number,
        zoneRatios as Array<Float>?,
        colors as Array<Number>, thRatio as Float, activeZone as Number
    ) as Void {
        if (zoneRatios == null || zoneRatios.size() < 2) { return; }
        var numZones = zoneRatios.size() - 1;
        var isLeft = (x0 < _width / 2);
        var narrowW = w - 7;
        var taper = 10;

        // Draw all zones
        for (var z = 0; z < numZones; z++) {
            var segY = y0 + h - (zoneRatios[z + 1] * h).toNumber();
            var segH = ((zoneRatios[z + 1] - zoneRatios[z]) * h).toNumber() + 1;
            var zColor = (z < colors.size()) ? colors[z] : 0x555555;
            dc.setColor(zColor, Graphics.COLOR_TRANSPARENT);

            if (z == activeZone) {
                // Active zone: full width, clean rectangle
                dc.fillRectangle(x0, segY, w, segH);
            } else {
                var zx = isLeft ? x0 : x0 + (w - narrowW);
                // Check if this zone borders the active zone
                if (z == activeZone - 1) {
                    // Zone below active: taper at top (widen toward active)
                    var bodyH = segH - taper;
                    if (bodyH > 0) {
                        dc.fillRectangle(zx, segY + taper, narrowW, bodyH);
                    }
                    var pts = new [4];
                    if (isLeft) {
                        pts[0] = [x0, segY];
                        pts[1] = [x0 + w - 1, segY];
                        pts[2] = [zx + narrowW - 1, segY + taper];
                        pts[3] = [zx, segY + taper];
                    } else {
                        pts[0] = [x0 + w, segY];
                        pts[1] = [x0, segY];
                        pts[2] = [zx, segY + taper];
                        pts[3] = [zx + narrowW, segY + taper];
                    }
                    dc.fillPolygon(pts);
                } else if (z == activeZone + 1) {
                    // Zone above active: taper at bottom (widen toward active)
                    var bodyH = segH - taper;
                    if (bodyH > 0) {
                        dc.fillRectangle(zx, segY, narrowW, bodyH);
                    }
                    var pts = new [4];
                    if (isLeft) {
                        pts[0] = [zx, segY + segH - taper];
                        pts[1] = [zx + narrowW - 1, segY + segH - taper];
                        pts[2] = [x0 + w - 1, segY + segH];
                        pts[3] = [x0, segY + segH];
                    } else {
                        pts[0] = [zx + narrowW, segY + segH - taper];
                        pts[1] = [zx, segY + segH - taper];
                        pts[2] = [x0, segY + segH];
                        pts[3] = [x0 + w, segY + segH];
                    }
                    dc.fillPolygon(pts);
                } else {
                    dc.fillRectangle(zx, segY, narrowW, segH);
                }
            }
        }

        // Threshold star
        if (thRatio > 0.0f && thRatio < 1.0f) {
            var thY = y0 + h - (thRatio * h).toNumber();
            var mx = isLeft ? x0 + narrowW / 2 : x0 + w - narrowW / 2;
            dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
            drawStar(dc, mx, thY, 11);
        }
    }

    // Triangle marker pointing outward (current value)
    private function drawBarTriangle(
        dc as Graphics.Dc,
        x0 as Number, y0 as Number, w as Number, h as Number,
        value as Float, bounds as Array<Number>?, ratios as Array<Float>?
    ) as Void {
        if (value <= 0.0f) { return; }
        var valY = getBarY(y0, h, value, bounds, ratios);
        var sz = 8;
        var isLeft = (x0 < _width / 2);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        var pts = new [3];
        if (isLeft) {
            pts[0] = [x0 + w, valY];
            pts[1] = [x0, valY - sz];
            pts[2] = [x0, valY + sz];
        } else {
            pts[0] = [x0, valY];
            pts[1] = [x0 + w, valY - sz];
            pts[2] = [x0 + w, valY + sz];
        }
        dc.fillPolygon(pts);
    }

    // Horizontal line marker on the bar (NP / avg HR)
    private function drawBarLine(
        dc as Graphics.Dc,
        x0 as Number, y0 as Number, w as Number, h as Number,
        value as Float, bounds as Array<Number>?, ratios as Array<Float>?
    ) as Void {
        if (value <= 0.0f) { return; }
        var valY = getBarY(y0, h, value, bounds, ratios);
        dc.setColor(_fgColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(x0, valY, x0 + w, valY);
        dc.setPenWidth(1);
    }

    // Draw a 4-pointed star
    private function drawStar(dc as Graphics.Dc, cx as Number, cy as Number, r as Number) as Void {
        var ir = r / 3;
        dc.fillPolygon(createDiamond(cx, cy - r, cx + ir, cy, cx, cy + r, cx - ir, cy));
        dc.fillPolygon(createDiamond(cx, cy - ir, cx + r, cy, cx, cy + ir, cx - r, cy));
    }

    private function createDiamond(x1 as Number, y1 as Number, x2 as Number, y2 as Number,
        x3 as Number, y3 as Number, x4 as Number, y4 as Number) as Array {
        var pts = new [4];
        pts[0] = [x1, y1];
        pts[1] = [x2, y2];
        pts[2] = [x3, y3];
        pts[3] = [x4, y4];
        return pts;
    }

    private function getZoneIndex(value as Float, bounds as Array<Number>?) as Number {
        if (bounds == null) { return 0; }
        for (var i = 0; i < bounds.size() - 1; i++) {
            if (value < bounds[i + 1]) { return i; }
        }
        return bounds.size() - 2;
    }
}
