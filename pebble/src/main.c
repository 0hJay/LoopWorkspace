/*
 * Loop CGM Monitor - Pebble Watch App
 * 
 * Displays blood glucose, trend, IOB, and loop status
 * Fetches data from iPhone via local HTTP server
 * Off-grid communication via Bluetooth
 */

#include <pebble.h>

// UI Elements
static Window *s_main_window;
static TextLayer *s_glucose_layer;
static TextLayer *s_trend_layer;
static TextLayer *s_iob_layer;
static TextLayer *s_status_layer;
static TextLayer *s_time_layer;
static TextLayer *s_loading_layer;

// Data
static char glucose_buffer[16];
static char trend_buffer[8];
static char iob_buffer[24];
static char status_buffer[32];
static char time_buffer[8];

// AppMessage keys
#define KEY_GLUCOSE 0
#define KEY_TREND 1
#define KEY_IOB 2
#define KEY_IS_CLOSED_LOOP 3
#define KEY_COB 4
#define KEY_BATTERY 5

// Refresh interval: 5 minutes
#define REFRESH_INTERVAL_MS (5 * 60 * 1000)

// Alert thresholds (mg/dL)
#define LOW_THRESHOLD 70
#define HIGH_THRESHOLD 180

static void request_data(void) {
    // Send message to phone to fetch data
    DictionaryIterator *iter;
    if (app_message_outbox_begin(&iter) == APP_MSG_OK) {
        dict_write_uint8(iter, 0, 0);
        app_message_outbox_send();
    }
}

static void update_time(void) {
    time_t temp = time(NULL);
    struct tm *tick_time = localtime(&temp);
    strftime(time_buffer, sizeof(time_buffer), "%H:%M", tick_time);
    text_layer_set_text(s_time_layer, time_buffer);
}

static void check_alerts(int glucose) {
    static time_t last_alert = 0;
    time_t now = time(NULL);
    
    // Only alert once every 15 minutes
    if (now - last_alert < 15 * 60) return;
    
    if (glucose > 0 && glucose < LOW_THRESHOLD) {
        vibes_double_pulse();
        last_alert = now;
    } else if (glucose > HIGH_THRESHOLD) {
        vibes_short_pulse();
        last_alert = now;
    }
}

static void inbox_received_callback(DictionaryIterator *iterator, void *context) {
    // Hide loading text
    layer_set_hidden(text_layer_get_layer(s_loading_layer), true);
    
    // Glucose
    Tuple *glucose_tuple = dict_find(iterator, KEY_GLUCOSE);
    if (glucose_tuple) {
        int glucose = (int)glucose_tuple->value->int32;
        snprintf(glucose_buffer, sizeof(glucose_buffer), "%d", glucose);
        text_layer_set_text(s_glucose_layer, glucose_buffer);
        
        // Check for alerts
        check_alerts(glucose);
        
        // Color based on range (Basalt+ only)
        #ifdef PBL_COLOR
        if (glucose < LOW_THRESHOLD) {
            text_layer_set_text_color(s_glucose_layer, GColorRed);
        } else if (glucose > HIGH_THRESHOLD) {
            text_layer_set_text_color(s_glucose_layer, GColorOrange);
        } else {
            text_layer_set_text_color(s_glucose_layer, GColorGreen);
        }
        #endif
    }
    
    // Trend
    Tuple *trend_tuple = dict_find(iterator, KEY_TREND);
    if (trend_tuple) {
        snprintf(trend_buffer, sizeof(trend_buffer), "%s", trend_tuple->value->cstring);
        text_layer_set_text(s_trend_layer, trend_buffer);
    }
    
    // IOB
    Tuple *iob_tuple = dict_find(iterator, KEY_IOB);
    if (iob_tuple) {
        int iob = (int)iob_tuple->value->int32;
        snprintf(iob_buffer, sizeof(iob_buffer), "IOB: %d.%dU", iob / 10, abs(iob % 10));
        text_layer_set_text(s_iob_layer, iob_buffer);
    }
    
    // Loop status
    Tuple *loop_tuple = dict_find(iterator, KEY_IS_CLOSED_LOOP);
    if (loop_tuple) {
        bool is_closed = loop_tuple->value->int32 > 0;
        snprintf(status_buffer, sizeof(status_buffer), "%s", is_closed ? "Loop: ON" : "Loop: OFF");
        text_layer_set_text(s_status_layer, status_buffer);
        
        #ifdef PBL_COLOR
        text_layer_set_text_color(s_status_layer, is_closed ? GColorGreen : GColorRed);
        #endif
    }
    
    update_time();
}

static void inbox_dropped_callback(AppMessageResult reason, void *context) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "Message dropped: %d", reason);
}

static void outbox_failed_callback(DictionaryIterator *iterator, AppMessageResult reason, void *context) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "Outbox send failed: %d", reason);
}

static void outbox_sent_callback(DictionaryIterator *iterator, void *context) {
    APP_LOG(APP_LOG_LEVEL_DEBUG, "Outbox send success");
}

static void tick_handler(struct tm *tick_time, TimeUnits units_changed) {
    update_time();
    
    // Request data every 5 minutes
    if (tick_time->tm_min % 5 == 0) {
        request_data();
    }
}

static void main_window_load(Window *window) {
    Layer *window_layer = window_get_root_layer(window);
    GRect bounds = layer_get_bounds(window_layer);
    
    // Time layer (top)
    s_time_layer = text_layer_create(GRect(0, 0, bounds.size.w, 24));
    text_layer_set_font(s_time_layer, fonts_get_system_font(FONT_KEY_GOTHIC_18_BOLD));
    text_layer_set_text_alignment(s_time_layer, GTextAlignmentCenter);
    text_layer_set_background_color(s_time_layer, GColorClear);
    layer_add_child(window_layer, text_layer_get_layer(s_time_layer));
    
    // Glucose layer (large, center-top)
    s_glucose_layer = text_layer_create(GRect(0, 28, bounds.size.w, 40));
    text_layer_set_font(s_glucose_layer, fonts_get_system_font(FONT_KEY_BITHAM_30_BLACK));
    text_layer_set_text_alignment(s_glucose_layer, GTextAlignmentCenter);
    text_layer_set_background_color(s_glucose_layer, GColorClear);
    text_layer_set_text(s_glucose_layer, "---");
    layer_add_child(window_layer, text_layer_get_layer(s_glucose_layer));
    
    // Trend layer (below glucose)
    s_trend_layer = text_layer_create(GRect(0, 72, bounds.size.w, 30));
    text_layer_set_font(s_trend_layer, fonts_get_system_font(FONT_KEY_GOTHIC_24_BOLD));
    text_layer_set_text_alignment(s_trend_layer, GTextAlignmentCenter);
    text_layer_set_background_color(s_trend_layer, GColorClear);
    text_layer_set_text(s_trend_layer, "");
    layer_add_child(window_layer, text_layer_get_layer(s_trend_layer));
    
    // IOB layer
    s_iob_layer = text_layer_create(GRect(0, 108, bounds.size.w, 24));
    text_layer_set_font(s_iob_layer, fonts_get_system_font(FONT_KEY_GOTHIC_18));
    text_layer_set_text_alignment(s_iob_layer, GTextAlignmentCenter);
    text_layer_set_background_color(s_iob_layer, GColorClear);
    text_layer_set_text(s_iob_layer, "IOB: --");
    layer_add_child(window_layer, text_layer_get_layer(s_iob_layer));
    
    // Loop status layer
    s_status_layer = text_layer_create(GRect(0, 136, bounds.size.w, 24));
    text_layer_set_font(s_status_layer, fonts_get_system_font(FONT_KEY_GOTHIC_18_BOLD));
    text_layer_set_text_alignment(s_status_layer, GTextAlignmentCenter);
    text_layer_set_background_color(s_status_layer, GColorClear);
    text_layer_set_text(s_status_layer, "Loop: --");
    layer_add_child(window_layer, text_layer_get_layer(s_status_layer));
    
    // Loading layer
    s_loading_layer = text_layer_create(GRect(0, 60, bounds.size.w, 30));
    text_layer_set_font(s_loading_layer, fonts_get_system_font(FONT_KEY_GOTHIC_18));
    text_layer_set_text_alignment(s_loading_layer, GTextAlignmentCenter);
    text_layer_set_background_color(s_loading_layer, GColorClear);
    text_layer_set_text(s_loading_layer, "Loading...");
    layer_add_child(window_layer, text_layer_get_layer(s_loading_layer));
}

static void main_window_unload(Window *window) {
    text_layer_destroy(s_glucose_layer);
    text_layer_destroy(s_trend_layer);
    text_layer_destroy(s_iob_layer);
    text_layer_destroy(s_status_layer);
    text_layer_destroy(s_time_layer);
    text_layer_destroy(s_loading_layer);
}

static void init(void) {
    // Register callbacks
    app_message_register_inbox_received(inbox_received_callback);
    app_message_register_inbox_dropped(inbox_dropped_callback);
    app_message_register_outbox_failed(outbox_failed_callback);
    app_message_register_outbox_sent(outbox_sent_callback);
    
    // Open app message
    app_message_open(128, 64);
    
    // Create main window
    s_main_window = window_create();
    window_set_background_color(s_main_window, GColorBlack);
    window_set_window_handlers(s_main_window, (WindowHandlers) {
        .load = main_window_load,
        .unload = main_window_unload
    });
    window_stack_push(s_main_window, true);
    
    // Register tick handler
    tick_timer_service_subscribe(MINUTE_UNIT, tick_handler);
    
    // Initial data request
    request_data();
    update_time();
}

static void deinit(void) {
    window_destroy(s_main_window);
}

int main(void) {
    init();
    app_event_loop();
    deinit();
}
