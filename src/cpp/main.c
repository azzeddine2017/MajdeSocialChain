/* main.c — Ring app entry point for the Android WebView example. */

#include "ring.h"
#include "ringappcode.h"

/* ------------------------------------------------------------------ */
/* App entry point — called by the backend's worker thread             */
/* ------------------------------------------------------------------ */

/* Creates the Ring state and runs the embedded bytecode. Returns only
 * when the Ring program exits (i.e. webview_run() returns and main()
 * finishes). The backend captures the live RingState itself inside
 * ring_webview_create() via RING_API_STATE, so no state is passed back. */
void ring_app_main(void) {
	RingState *pRingState = ring_state_new();
	if (!pRingState) {
		return;
	}
	pRingState->lRun = 1;
	ringappcode_run(pRingState);
	ring_state_delete(pRingState);
}
