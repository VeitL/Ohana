import Foundation

// OHANA_UI_TEST_COMMENT_DECOY must not count as executable source.
/* settings-debug-block-comment-decoy */
#if DEBUG
let debugLaunchMarker = ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TESTS")
let debugMenuIdentifier = "settings-debug-coconuts"

func setDeveloperOverrideBalance() {}

    #if INTERNAL_BUILD
    let nestedDebugMarker = "OHANA_UI_TEST_NESTED"
    #endif
#endif

#if DEBUG && INTERNAL_BUILD
let conjunctiveDebugMarker = "OHANA_UI_TEST_CONJUNCTIVE"
#endif

let productionValue = "release-safe"
