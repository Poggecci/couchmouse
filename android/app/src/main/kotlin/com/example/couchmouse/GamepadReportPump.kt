package com.example.couchmouse

/**
 * Streams the full gamepad state to the host at a fixed rate instead of only
 * when it changes.
 *
 * Why: Android's HID Device stack silently drops a report when the L2CAP
 * channel is congested (`hidd_conn_send_data` returns HID_ERR_CONGESTED and
 * `bta_hd_send_report_act` ignores it), and `BluetoothHidDevice.sendReport`
 * still returns true. With send-on-change, a dropped button press/release
 * was never re-sent. Every report carries the complete state, so resending
 * it each tick repairs any drop on the next tick. Constant traffic also
 * keeps the link out of sniff subrating, which the HID Device power profile
 * enters after ~1 s idle (up to 225 ms latency).
 *
 * Threading: [update] may be called from any thread (the main thread, for
 * input events). [setStreaming] and [tick] must be called from one thread
 * only (the sender thread), which also owns the scheduling.
 */
class GamepadReportPump(
    private val send: (ByteArray) -> Boolean,
    /** Neutral reports sent after streaming stops, so a release survives a drop or two. */
    private val neutralFlushReports: Int = 3,
) {
    private val lock = Any()
    private var state = GamepadState.NEUTRAL
    private var streaming = false
    private var neutralRemaining = 0

    /** Latest controller state; picked up by the next [tick]. */
    fun update(newState: GamepadState) {
        synchronized(lock) { state = newState }
    }

    /** Current state as a report, e.g. to answer a host GET_REPORT. */
    fun currentReport(): ByteArray = synchronized(lock) { state }.toReport()

    /**
     * Starts or stops streaming. Stopping resets the state to neutral and
     * queues [neutralFlushReports] neutral reports. Returns true if the
     * pump now needs ticks (the caller should make sure they're scheduled).
     */
    fun setStreaming(enabled: Boolean): Boolean = synchronized(lock) {
        if (enabled) {
            streaming = true
            neutralRemaining = 0
        } else if (streaming) {
            streaming = false
            state = GamepadState.NEUTRAL
            neutralRemaining = neutralFlushReports
        }
        needsTicks()
    }

    /** Sends one report. Returns true if another tick should be scheduled. */
    fun tick(): Boolean {
        val report = synchronized(lock) {
            when {
                streaming -> state.toReport()
                neutralRemaining > 0 -> {
                    neutralRemaining--
                    GamepadState.NEUTRAL.toReport()
                }
                else -> return false
            }
        }
        // The result is deliberately ignored: a failed or silently dropped
        // report is corrected by the next tick, which carries the full state.
        send(report)
        return synchronized(lock) { needsTicks() }
    }

    val isStreaming: Boolean get() = synchronized(lock) { streaming }

    private fun needsTicks() = streaming || neutralRemaining > 0

    companion object {
        /** 125 Hz: the standard USB HID full-speed polling rate. */
        const val INTERVAL_MS = 8L
    }
}
