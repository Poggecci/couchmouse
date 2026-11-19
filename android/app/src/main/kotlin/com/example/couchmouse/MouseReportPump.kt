package com.example.couchmouse

import kotlin.collections.ArrayDeque

/**
 * Paces mouse reports (Report ID 2) like a real mouse: motion is summed and
 * sent at most once per [minIntervalMs], instead of one report per touch
 * event.
 *
 * Touch events reach Flutter in per-frame batches, and sending one report per
 * event put bursts on the link followed by gaps. Here, each report carries
 * all the motion since the previous one, so reports leave at a steady
 * cadence however the input arrives.
 *
 * Policy:
 * - **Motion** (x, y, wheel) is summed. A pending change is sent as soon as
 *   possible, but no sooner than [minIntervalMs] after the previous report.
 *   Motion beyond a report's ±127 range carries into the next report.
 * - **Button changes** keep their order: motion that arrived before a change
 *   goes out with the old buttons, then the change, then later motion. A
 *   click that is pressed and released between two reports still sends both.
 * - **Idle** sends nothing. The link keep-alive in MainActivity covers that.
 *
 * Threading: [move], [setButtons] and [reset] may be called from any thread.
 * [tick] and [setMaxRateHz] must be called from a single thread (the sender
 * thread), which owns scheduling.
 */
class MouseReportPump(
    private val send: (ByteArray) -> Boolean,
    minIntervalMs: Long = DEFAULT_MIN_INTERVAL_MS,
) {
    /** Motion that goes out with one button state. */
    private class Segment(val buttons: Int, var dx: Int = 0, var dy: Int = 0, var wheel: Int = 0) {
        var mustSend = false // a button change (or forced report) not yet sent
        val hasMotion get() = dx != 0 || dy != 0 || wheel != 0
    }

    private val lock = Any()
    private val segments = ArrayDeque<Segment>()
    private var buttons = 0
    private var lastSentAt = Long.MIN_VALUE / 2

    @Volatile
    var minIntervalMs: Long = minIntervalMs.coerceAtLeast(1)
        private set

    fun setMaxRateHz(hz: Int) {
        minIntervalMs = (1000L / hz.coerceIn(MIN_RATE_HZ, MAX_RATE_HZ)).coerceAtLeast(1)
    }

    /**
     * Adds relative motion. Returns true if the sender was idle and should be
     * woken so the motion goes out promptly.
     */
    fun move(dx: Int, dy: Int, wheel: Int): Boolean = synchronized(lock) {
        if (dx == 0 && dy == 0 && wheel == 0) return false
        val wasIdle = segments.isEmpty()
        val seg = segments.lastOrNull() ?: Segment(buttons).also { segments.addLast(it) }
        seg.dx = (seg.dx + dx).coerceIn(-MAX_PENDING, MAX_PENDING)
        seg.dy = (seg.dy + dy).coerceIn(-MAX_PENDING, MAX_PENDING)
        seg.wheel = (seg.wheel + wheel).coerceIn(-MAX_PENDING, MAX_PENDING)
        wasIdle
    }

    /**
     * Changes the held buttons. [force] sends a report even if nothing
     * changed, e.g. to make sure the host has released everything. Returns
     * true if the sender should be woken.
     */
    fun setButtons(newButtons: Int, force: Boolean = false): Boolean = synchronized(lock) {
        if (newButtons == buttons && !force) return false
        val wasIdle = segments.isEmpty()
        if (segments.size == MAX_SEGMENTS) segments.removeFirst() // overload: keep recent changes
        buttons = newButtons
        segments.addLast(Segment(newButtons).apply { mustSend = true })
        wasIdle
    }

    /** Drops pending motion and button changes, e.g. when the host session ends. */
    fun reset() = synchronized(lock) {
        segments.clear()
        buttons = 0
        lastSentAt = Long.MIN_VALUE / 2
    }

    /**
     * Sends a report if one is due at [now] (ms, monotonic). Returns the time
     * at which [tick] should run next, or null when nothing is pending.
     */
    fun tick(now: Long): Long? {
        val report: ByteArray
        synchronized(lock) {
            val seg = segments.firstOrNull() ?: return null
            val due = lastSentAt + minIntervalMs
            if (now < due) return due
            val dx = seg.dx.coerceIn(-127, 127)
            val dy = seg.dy.coerceIn(-127, 127)
            val wheel = seg.wheel.coerceIn(-127, 127)
            seg.dx -= dx
            seg.dy -= dy
            seg.wheel -= wheel
            seg.mustSend = false
            // A segment stays while it has motion left, or while it's the newest
            // one (later motion joins it with the current buttons).
            if (!seg.hasMotion && segments.size > 1) segments.removeFirst()
            else if (!seg.hasMotion) segments.clear()
            report = byteArrayOf(seg.buttons.toByte(), dx.toByte(), dy.toByte(), wheel.toByte())
            lastSentAt = now
        }
        // Result ignored on purpose: drops are silent anyway (see GamepadReportPump).
        send(report)
        return synchronized(lock) {
            if (segments.isEmpty()) null else lastSentAt + minIntervalMs
        }
    }

    companion object {
        const val DEFAULT_RATE_HZ = 125
        const val DEFAULT_MIN_INTERVAL_MS = 1000L / DEFAULT_RATE_HZ // 8 ms
        const val MIN_RATE_HZ = 30
        const val MAX_RATE_HZ = 250
        private const val MAX_SEGMENTS = 32
        // Caps motion owed to the host, so a stalled link can't build up a long fling.
        private const val MAX_PENDING = 127 * 8
    }
}
