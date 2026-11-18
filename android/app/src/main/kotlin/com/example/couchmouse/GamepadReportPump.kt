package com.example.couchmouse

import kotlin.collections.ArrayDeque

/**
 * Decides when to send gamepad reports to the host.
 *
 * Constraints (from AOSP's HID Device stack and hardware testing):
 * - `BluetoothHidDevice.sendReport` returns true even when the stack later
 *   drops the report because the L2CAP channel is congested
 *   (`hidd_conn_send_data` → HID_ERR_CONGESTED, ignored by
 *   `bta_hd_send_report_act`). There is no feedback about drops or the
 *   link's real capacity.
 * - With no traffic for ~1 s the link enters sniff subrating (up to 225 ms
 *   latency), so some traffic is needed to keep it responsive.
 * - Sending faster than the link drains (a fixed 125 Hz stream was tried)
 *   fills the queue: every new input waits behind stale reports, and quick
 *   inputs are dropped while the channel is congested.
 *
 * Policy:
 * - **Changed state** is sent as soon as possible, but no more often than
 *   once per [minIntervalMs] (the report-rate cap).
 * - Button and D-pad transitions are sent in input order, including taps
 *   between reports. Sticks and analog triggers use the latest sample.
 * - **Unchanged state** is re-sent every [keepAliveMs]: keeps the link awake
 *   and repairs any silently dropped report.
 * - Stopping resets to neutral and sends [neutralFlushReports] neutral
 *   reports, so a release survives a drop or two.
 *
 * Threading: [update] may be called from any thread (input events arrive on
 * the main thread). [setStreaming], [tick] and [setMaxRateHz] must be called
 * from a single thread (the sender thread), which owns scheduling.
 */
class GamepadReportPump(
    private val send: (ByteArray) -> Boolean,
    minIntervalMs: Long = DEFAULT_MIN_INTERVAL_MS,
    val keepAliveMs: Long = KEEP_ALIVE_MS,
    private val neutralFlushReports: Int = 3,
) {
    private val lock = Any()
    private data class DigitalState(val buttons: Int, val hat: Int)
    private val pendingTransitions = ArrayDeque<DigitalState>()
    private var state = GamepadState.NEUTRAL
    private var lastSent: GamepadState? = null // null: host needs the full state
    private var lastSentAt = Long.MIN_VALUE / 2       // any report (keepalive pacing)
    private var lastChangeSentAt = Long.MIN_VALUE / 2 // reports carrying a change (rate cap)
    private var streaming = false
    private var neutralRemaining = 0

    @Volatile
    var minIntervalMs: Long = minIntervalMs.coerceAtLeast(1)
        private set

    fun setMaxRateHz(hz: Int) {
        minIntervalMs = (1000L / hz.coerceIn(MIN_RATE_HZ, MAX_RATE_HZ)).coerceAtLeast(1)
    }

    /**
     * Stores the latest controller state. Returns true if this turned an
     * up-to-date host into an out-of-date one, i.e. the caller should wake
     * the sender so the change goes out promptly. Cheap enough to call for
     * every input event.
     */
    fun update(newState: GamepadState): Boolean = synchronized(lock) {
        val wasDirty = isDirty()
        if (streaming && (newState.buttons != state.buttons || newState.hat != state.hat)) {
            // Under sustained overload, keep recent transitions and converge to live input.
            if (pendingTransitions.size == MAX_PENDING_TRANSITIONS) pendingTransitions.removeFirst()
            pendingTransitions.addLast(DigitalState(newState.buttons, newState.hat))
        }
        state = newState
        streaming && !wasDirty && isDirty()
    }

    /** Drops pending input when its physical source or forwarding session goes away. */
    fun resetInput(newState: GamepadState = GamepadState.NEUTRAL): Boolean = synchronized(lock) {
        pendingTransitions.clear()
        state = newState
        streaming && isDirty()
    }

    /** Actual current state as a report, e.g. to answer a host GET_REPORT. */
    fun currentReport(): ByteArray = synchronized(lock) { state }.toReport()

    val isStreaming: Boolean get() = synchronized(lock) { streaming }

    /**
     * Starts or stops streaming. Stopping resets to neutral and queues
     * neutral flush reports. Returns true if the caller should run [tick].
     */
    fun setStreaming(enabled: Boolean): Boolean = synchronized(lock) {
        if (enabled) {
            if (!streaming) lastSent = null // a new stream starts with the full state
            streaming = true
            neutralRemaining = 0
        } else if (streaming) {
            streaming = false
            state = GamepadState.NEUTRAL
            pendingTransitions.clear()
            neutralRemaining = neutralFlushReports
        }
        streaming || neutralRemaining > 0
    }

    /**
     * Sends a report if one is due at [now] (ms, monotonic). Returns the time
     * at which [tick] should run next, or null when there's nothing to do
     * until [setStreaming] or a changed [update].
     */
    fun tick(now: Long): Long? {
        val report: ByteArray
        synchronized(lock) {
            if (!streaming && neutralRemaining == 0) return null
            val due = nextDueAt()
            if (now < due) return due
            val carriesChange = !streaming || isDirty()
            val outgoing = if (streaming) {
                val transition = pendingTransitions.removeFirstOrNull()
                if (transition == null) state else state.copy(
                    buttons = transition.buttons,
                    hat = transition.hat,
                )
            } else {
                neutralRemaining--
                GamepadState.NEUTRAL
            }
            report = outgoing.toReport()
            lastSent = outgoing
            lastSentAt = now
            if (carriesChange) lastChangeSentAt = now
        }
        // Result ignored on purpose: drops are silent anyway, and the
        // keepalive (or next change) re-sends the full state.
        send(report)
        return synchronized(lock) {
            if (!streaming && neutralRemaining == 0) null else nextDueAt()
        }
    }

    /**
     * Compares encoded reports, not floats: stick noise below the report's
     * resolution (or -0.0 vs 0.0) is not a change worth sending.
     */
    private fun isDirty(): Boolean {
        if (pendingTransitions.isNotEmpty()) return true
        val sent = lastSent ?: return true
        return !sent.toReport().contentEquals(state.toReport())
    }

    /**
     * The rate cap only spaces change reports from each other: a keepalive
     * followed straight away by a change is a burst of two, which the link
     * absorbs, whereas delaying the change would add latency to the first
     * input after an idle period. Sustained motion has no keepalives, so its
     * rate stays capped at [minIntervalMs].
     */
    private fun nextDueAt(): Long = when {
        !streaming -> lastChangeSentAt + minIntervalMs // neutral flush, rate-capped
        isDirty() -> lastChangeSentAt + minIntervalMs
        else -> lastSentAt + keepAliveMs
    }

    companion object {
        const val DEFAULT_RATE_HZ = 125
        const val DEFAULT_MIN_INTERVAL_MS = 1000L / DEFAULT_RATE_HZ // 8 ms
        const val KEEP_ALIVE_MS = 50L // 20 Hz when idle; the link sleeps after ~1 s of silence
        const val MIN_RATE_HZ = 10
        const val MAX_RATE_HZ = 250
        private const val MAX_PENDING_TRANSITIONS = 32
    }
}
