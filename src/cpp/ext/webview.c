/* WebView backend extension entry.
 *
 * The vendored backend (src/cpp/webview) registers its webview_* functions
 * via RING_LIBINIT (i.e. ringlib_init). This wrapper exposes it under the
 * ext/ convention so the generated ext.c can call ring_webview().
 */

#include "ring.h"

extern void ringlib_init(RingState *pRingState);

void ring_webview(RingState *pRingState) {
	ringlib_init(pRingState);
}
