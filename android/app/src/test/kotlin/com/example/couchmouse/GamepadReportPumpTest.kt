package com.example.couchmouse

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GamepadReportPumpTest {
    private val sent = mutableListOf<Pair<Long, GamepadState>>()
    private var now = 1_000L
    private val pump = GamepadReportPump(
        send = { bytes -> sent += now to decode(bytes); true },
        minIntervalMs = 16,
        keepAliveMs = 50,
    )

    private val a = GamepadButton.mask(GamepadButton.A)
    private val b = GamepadButton.mask(GamepadButton.B)

    /** Minimal decoder for buttons/hat/leftX, enough to assert on. */
    private fun decode(r: ByteArray): GamepadState {
        fun u(i: Int) = r[i].toInt() and 0xFF
        val lx = ((u(4) shl 8) or u(3)).toShort() / 32767f
        return GamepadState(buttons = u(0) or (u(1) shl 8), hat = u(2), leftX = lx)
    }

    /** Drives the pump like the sender thread would, until [until]. */
    private fun runUntil(until: Long) {
        var next: Long? = pump.tick(now)
        while (next != null && next <= until) {
            now = next
            next = pump.tick(now)
        }
        now = until
    }

    private fun start() {
        assertTrue(pump.setStreaming(true))
        runUntil(now) // initial full-state report
    }

    @Test fun idlePumpDoesNothing() {
        assertNull(pump.tick(now))
        assertFalse(pump.setStreaming(false))
        assertFalse(pump.update(GamepadState(buttons = a))) // not streaming: no wake
        assertTrue(sent.isEmpty())
    }

    @Test fun streamStartsWithFullStateImmediately() {
        pump.update(GamepadState(buttons = a))
        start()
        assertEquals(1, sent.size)
        assertEquals(a, sent[0].second.buttons)
    }

    @Test fun idleStreamOnlySendsKeepAlives() {
        start()
        runUntil(now + 1_000)
        // 1 initial + 20 keepalives at 50 ms: never more than the keepalive rate.
        assertEquals(21, sent.size)
        sent.zipWithNext().forEach { (x, y) -> assertEquals(50L, y.first - x.first) }
    }

    @Test fun changeAfterIdleGoesOutImmediately() {
        start()
        runUntil(now + 500) // long idle
        val before = sent.size
        val pressAt = now + 7 // between keepalives
        now = pressAt
        assertTrue(pump.update(GamepadState(buttons = a))) // asks to wake the sender
        pump.tick(now) // the woken sender thread
        assertEquals(before + 1, sent.size)
        assertEquals(pressAt, sent.last().first)
        assertEquals(a, sent.last().second.buttons)
    }

    @Test fun continuousChangesAreCappedToTheRate() {
        start()
        val t0 = now
        // Stick moving every 1 ms for 200 ms (e.g. a 1000 Hz controller).
        for (i in 1..200) {
            now = t0 + i
            if (pump.update(GamepadState(leftX = (i % 100) / 100f))) pump.tick(now)
            runUntil(now)
        }
        val inWindow = sent.filter { it.first > t0 }
        assertTrue("sent ${inWindow.size}", inWindow.size <= 200 / 16 + 1)
        inWindow.zipWithNext().forEach { (x, y) -> assertTrue(y.first - x.first >= 16) }
        // ...and the latest state is what got sent, not a backlog.
        runUntil(now + 16)
        assertEquals(0f, sent.last().second.leftX, 0.001f) // state at i = 200
    }

    @Test fun tapShorterThanTheIntervalIsNotLost() {
        start()
        runUntil(now + 5) // just sent recently -> rate cap applies
        pump.update(GamepadState(buttons = a))
        now += 3
        pump.update(GamepadState.NEUTRAL) // released before the next report
        runUntil(now + 40)
        val buttons = sent.drop(1).map { it.second.buttons }
        assertEquals(a, buttons[0])      // press delivered
        assertEquals(0, buttons[1])      // then the release
    }

    @Test fun dpadTapIsNotLost() {
        start()
        pump.update(GamepadState(hat = Hat.LEFT))
        pump.update(GamepadState(hat = Hat.CENTERED))
        runUntil(now + 40)
        val hats = sent.drop(1).map { it.second.hat }
        assertEquals(Hat.LEFT, hats[0])
        assertEquals(Hat.CENTERED, hats[1])
    }

    @Test fun consecutiveButtonTapsStaySeparate() {
        start()
        val before = sent.size
        pump.update(GamepadState(buttons = a))
        pump.update(GamepadState.NEUTRAL)
        pump.update(GamepadState(buttons = b))
        pump.update(GamepadState.NEUTRAL)
        runUntil(now + 64)
        assertEquals(listOf(a, 0, b, 0), sent.drop(before).map { it.second.buttons })
    }

    @Test fun consecutiveDpadTapsStayInOrder() {
        start()
        val before = sent.size
        pump.update(GamepadState(hat = Hat.LEFT))
        pump.update(GamepadState.NEUTRAL)
        pump.update(GamepadState(hat = Hat.RIGHT))
        pump.update(GamepadState.NEUTRAL)
        runUntil(now + 64)
        assertEquals(
            listOf(Hat.LEFT, Hat.CENTERED, Hat.RIGHT, Hat.CENTERED),
            sent.drop(before).map { it.second.hat },
        )
    }

    @Test fun inputRemovalReleasesHeldStateAndDiscardsQueuedTaps() {
        start()
        pump.update(GamepadState(buttons = a, leftX = 1f))
        runUntil(now + 16)
        assertEquals(a, sent.last().second.buttons)
        assertEquals(1f, sent.last().second.leftX, 0f)
        pump.update(GamepadState(buttons = a or b, leftX = 1f))
        val before = sent.size
        assertTrue(pump.resetInput())
        runUntil(now + 100)
        assertTrue(sent.size > before)
        assertTrue(sent.drop(before).all { it.second == GamepadState.NEUTRAL })
    }

    @Test fun heldButtonIsNotReLatchedAfterRelease() {
        start()
        pump.update(GamepadState(buttons = a))
        runUntil(now + 20)
        pump.update(GamepadState.NEUTRAL)
        runUntil(now + 200)
        // After the release report, every later report stays released.
        val afterRelease = sent.dropWhile { it.second.buttons == a || it.first == sent[0].first }
        assertTrue(afterRelease.isNotEmpty())
        afterRelease.forEach { assertEquals(0, it.second.buttons) }
    }

    @Test fun otherButtonsKeepTheirRealState() {
        start()
        pump.update(GamepadState(buttons = b))
        runUntil(now + 20) // B held and sent
        pump.update(GamepadState(buttons = a or b))
        pump.update(GamepadState(buttons = b)) // tap A while holding B
        runUntil(now + 40)
        val tail = sent.takeLast(2).map { it.second.buttons }
        assertEquals(listOf(a or b, b), tail)
    }

    @Test fun subResolutionNoiseIsNotAChange() {
        start()
        pump.update(GamepadState(leftX = 0.5f))
        runUntil(now + 20)
        val count = sent.size
        assertFalse(pump.update(GamepadState(leftX = 0.5f + 1e-7f)))
        runUntil(sent.last().first + 49) // just before the next keepalive
        assertEquals(count, sent.size)
    }

    @Test fun stoppingFlushesNeutralReportsThenGoesQuiet() {
        start()
        pump.update(GamepadState(buttons = a, leftX = 1f))
        runUntil(now + 20)
        assertTrue(pump.setStreaming(false))
        val before = sent.size
        runUntil(now + 1_000)
        val flushed = sent.drop(before)
        assertEquals(3, flushed.size)
        flushed.forEach { assertEquals(GamepadState.NEUTRAL, it.second) }
        assertNull(pump.tick(now))
        assertArrayEquals(GamepadState.NEUTRAL.toReport(), pump.currentReport())
    }

    @Test fun restartSendsFullStateAgain() {
        start()
        pump.setStreaming(false)
        runUntil(now + 100)
        pump.update(GamepadState(buttons = a))
        val before = sent.size
        start()
        assertEquals(before + 1, sent.size)
        assertEquals(a, sent.last().second.buttons)
    }

    @Test fun rateSetting() {
        pump.setMaxRateHz(30)
        assertEquals(33L, pump.minIntervalMs)
        pump.setMaxRateHz(125)
        assertEquals(8L, pump.minIntervalMs)
        pump.setMaxRateHz(100_000)
        assertEquals(1000L / GamepadReportPump.MAX_RATE_HZ, pump.minIntervalMs)
        pump.setMaxRateHz(0)
        assertEquals(1000L / GamepadReportPump.MIN_RATE_HZ, pump.minIntervalMs)
        assertTrue(1000.0 / GamepadReportPump.DEFAULT_MIN_INTERVAL_MS >= 60.0)
        assertTrue(GamepadReportPump.KEEP_ALIVE_MS < 1_000) // link sleeps after ~1 s silence
    }
}
