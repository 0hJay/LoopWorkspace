/*
 * Loop CGM Monitor - Pebble JavaScript
 * 
 * Fetches CGM data from iPhone's local HTTP server
 * Off-grid communication via Bluetooth connection
 */

var API_BASE = 'http://127.0.0.1:8080';

// Trend arrow to text mapping
var TREND_SYMBOLS = {
    '↑↑↑': 'UP_UP_UP',
    '↑↑': 'UP_UP',
    '↑': 'UP',
    '→': 'FLAT',
    '↓': 'DOWN',
    '↓↓': 'DOWN_DOWN',
    '↓↓↓': 'DOWN_DOWN_DOWN',
    '?': 'UNKNOWN'
};

function fetchCGMData() {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', API_BASE + '/api/all', true);
    xhr.timeout = 10000; // 10 second timeout
    
    xhr.onload = function() {
        if (xhr.status === 200) {
            try {
                var data = JSON.parse(xhr.responseText);
                sendDataToWatch(data);
            } catch (e) {
                console.log('JSON parse error: ' + e);
                sendErrorToWatch('Parse error');
            }
        } else {
            console.log('HTTP error: ' + xhr.status);
            sendErrorToWatch('HTTP ' + xhr.status);
        }
    };
    
    xhr.ontimeout = function() {
        console.log('Request timeout');
        sendErrorToWatch('Timeout');
    };
    
    xhr.onerror = function() {
        console.log('Request error');
        sendErrorToWatch('Connection error');
    };
    
    xhr.send();
}

function sendDataToWatch(data) {
    var message = {};
    
    // CGM data
    if (data.cgm && data.cgm.glucose !== null) {
        message.KEY_GLUCOSE = Math.round(data.cgm.glucose);
    }
    
    // Trend
    if (data.cgm && data.cgm.trend) {
        message.KEY_TREND = data.cgm.trend;
    }
    
    // IOB (convert to integer (x10) for Pebble)
    if (data.loop && data.loop.iob !== null) {
        message.KEY_IOB = Math.round(data.loop.iob * 10);
    }
    
    // Loop status
    if (data.loop) {
        message.KEY_IS_CLOSED_LOOP = data.loop.isClosedLoop ? 1 : 0;
    }
    
    // COB
    if (data.loop && data.loop.cob !== null) {
        message.KEY_COB = Math.round(data.loop.cob);
    }
    
    // Battery
    if (data.pump && data.pump.battery !== null) {
        message.KEY_BATTERY = Math.round(data.pump.battery);
    }
    
    // Send to watch
    Pebble.sendAppMessage(message, 
        function() {
            console.log('Data sent to watch');
        },
        function(e) {
            console.log('Error sending to watch: ' + JSON.stringify(e));
        }
    );
}

function sendErrorToWatch(errorMsg) {
    // Send empty data to show error state on watch
    Pebble.sendAppMessage({
        KEY_GLUCOSE: -1  // Negative indicates error
    });
}

// Listen for watch app to request data
Pebble.addEventListener('appmessage', function(e) {
    console.log('Watch requested data');
    fetchCGMData();
});

// Listen for when watchface is shown
Pebble.addEventListener('ready', function(e) {
    console.log('PebbleKit JS ready');
    // Fetch initial data
    fetchCGMData();
});

// Auto-refresh every 5 minutes
setInterval(function() {
    console.log('Auto-refreshing data');
    fetchCGMData();
}, 5 * 60 * 1000);
