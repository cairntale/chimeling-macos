enum ClerkPublishableKey {
    static var current: String {
        #if DEBUG
        "pk_test_cmlnaHQtcm9kZW50LTE2LmNsZXJrLmFjY291bnRzLmRldiQ"
        #else
        "pk_live_Y2xlcmsuY2hpbWVsaW5nLmFwcCQ"
        #endif
    }
}
