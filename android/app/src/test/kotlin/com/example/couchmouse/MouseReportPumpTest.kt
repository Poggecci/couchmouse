package com.example.couchmouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MouseReportPumpTest {
    private data class Report(val at: Long, val buttons: Int, val dx: Int, val dy: Int, val wheel: Int)

    private val sent = mutableListOf<Report>()
    private var now = 1_000L
    private val pump = MouseReportPump(
        send = { r -> sent += Report(now, r[0].toInt(), r[1].toInt(), r[2].toInt(), r[3].toInt()); true },
        minIntervalMs = 8,
    )

    /** Drives the pump like the sender thread would, until [until]. */
    private fun runUntil(until: Long) {
        var next: Long? = pump.tick(now)
        while (next != null && next <= until) {
            now = next
            next = pump.tick(now)
        }
        now = until
    }

    @Test fun idlePumpSendsNothing() {
        assertNull(pump.tick(now))
        assertFalse(pump.move(0, 0, 0))
        assertFalse(pump.setButtons(0))
        runUntil(now + 1_000)
        assertTrue(sent.isEmpty())
    }

    @Test fun firstMotionAfterIdleGoesOutImmediately() {
        assertTrue(pump.move(3, -2, 0))
        runUntil(now)
        assertEquals(listOf(Report(1_000, 0, 3, -2, 0)), sent)
    }

    @Test fun burstOfEventsIsSummedIntoOnePacedReport() {
        pump.move(1, 0, 0)
        runUntil(now) // sends (1, 0) at t=1000
        // A frame's worth of touch events arrives at once.
        assertTrue(pump.move(2, 1, 0)) // sender went idle after the first report
        assertFalse(pump.move(2, 1, 0)) // now it is awake
        pump.move(2, 1, 0)
        runUntil(now + 100)
        assertEquals(2, sent.size)
        assertEquals(Report(1_008, 0, 6, 3, 0), sent[1])
    }

    @Test fun reportsAreNeverCloserThanTheInterval() {
        for (i in 0 until 50) {
            pump.move(1, 1, 0)
            runUntil(now + 3) // input every 3 ms, faster than the 8 ms cap
        }
        runUntil(now + 100)
        sent.zipWithNext().forEach { (a, b) -> assertTrue(b.at - a.at >= 8) }
        assertEquals(50, sent.sumOf { it.dx }) // nothing lost
        assertEquals(50, sent.sumOf { it.dy })
    }

    @Test fun motionBeyondOneReportCarriesOver() {
        pump.move(300, -200, 0)
        runUntil(now + 100)
        assertEquals(listOf(127, 127, 46), sent.map { it.dx })
        assertEquals(listOf(-127, -73, 0), sent.map { it.dy })
    }

    @Test fun clickKeepsOrderWithMotion() {
        pump.move(1, 0, 0)
        runUntil(now)
        pump.move(5, 0, 0)        // before the press
        pump.setButtons(1)
        pump.move(7, 0, 0)        // while held (a drag)
        runUntil(now + 100)
        assertEquals(
            listOf(Report(1_000, 0, 1, 0, 0), Report(1_008, 0, 5, 0, 0), Report(1_016, 1, 7, 0, 0)),
            sent,
        )
    }

    @Test fun tapBetweenReportsSendsPressAndRelease() {
        pump.move(1, 0, 0)
        runUntil(now)
        pump.setButtons(1)
        pump.setButtons(0)
        runUntil(now + 100)
        assertEquals(listOf(0, 1, 0), sent.map { it.buttons })
    }

    @Test fun unchangedButtonsSendNothingUnlessForced() {
        assertFalse(pump.setButtons(0))
        assertTrue(pump.setButtons(0, force = true))
        runUntil(now)
        assertEquals(listOf(Report(1_000, 0, 0, 0, 0)), sent)
    }

    @Test fun resetDropsPendingInput() {
        pump.move(1, 0, 0)
        runUntil(now)
        pump.setButtons(1)
        pump.move(50, 0, 0)
        pump.reset()
        runUntil(now + 100)
        assertEquals(1, sent.size)
        // After a reset, the next motion goes out at once with no buttons held.
        assertTrue(pump.move(2, 0, 0))
        runUntil(now)
        assertEquals(Report(now, 0, 2, 0, 0), sent.last())
    }

    @Test fun rateCanBeChanged() {
        pump.setMaxRateHz(60) // 16 ms
        pump.move(1, 0, 0)
        runUntil(now)
        pump.move(1, 0, 0)
        runUntil(now + 100)
        assertEquals(16L, sent[1].at - sent[0].at)
    }
}
