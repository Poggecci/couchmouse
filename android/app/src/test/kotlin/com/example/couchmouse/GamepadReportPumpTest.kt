package com.example.couchmouse

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GamepadReportPumpTest {
    private val sent = mutableListOf<ByteArray>()
    private var sendSucceeds = true
    private val pump = GamepadReportPump(send = { sent += it; sendSucceeds })

    private val pressedA = GamepadState(buttons = GamepadButton.mask(GamepadButton.A))
    private val neutral = GamepadState.NEUTRAL.toReport()

    @Test fun idlePumpSendsNothing() {
        assertFalse(pump.tick())
        assertFalse(pump.setStreaming(false))
        assertTrue(sent.isEmpty())
    }

    @Test fun streamingResendsUnchangedStateEveryTick() {
        assertTrue(pump.setStreaming(true))
        pump.update(pressedA)
        repeat(5) { assertTrue(pump.tick()) }
        assertEquals(5, sent.size)
        sent.forEach { assertArrayEquals(pressedA.toReport(), it) }
    }

    @Test fun updatesAppearOnTheNextTick() {
        pump.setStreaming(true)
        pump.tick()
        pump.update(pressedA)
        pump.tick()
        assertArrayEquals(neutral, sent[0])
        assertArrayEquals(pressedA.toReport(), sent[1])
    }

    @Test fun droppedReportIsRepairedByTheNextTick() {
        pump.setStreaming(true)
        pump.update(pressedA)
        sendSucceeds = false // e.g. HID_ERR_CONGESTED / no host
        assertTrue(pump.tick())
        sendSucceeds = true
        assertTrue(pump.tick())
        assertArrayEquals(pressedA.toReport(), sent.last())
    }

    @Test fun onlyTheLatestStateIsSentPerTick() {
        pump.setStreaming(true)
        pump.update(pressedA)
        pump.update(GamepadState(leftX = 1f))
        pump.update(GamepadState(leftX = -1f))
        pump.tick()
        assertEquals(1, sent.size)
        assertArrayEquals(GamepadState(leftX = -1f).toReport(), sent[0])
    }

    @Test fun stoppingFlushesNeutralReportsThenStops() {
        pump.setStreaming(true)
        pump.update(pressedA)
        pump.tick()
        assertTrue(pump.setStreaming(false))
        assertFalse(pump.isStreaming)
        assertTrue(pump.tick())
        assertTrue(pump.tick())
        assertFalse(pump.tick()) // third (last) neutral flush
        assertFalse(pump.tick()) // nothing more
        assertEquals(4, sent.size)
        sent.drop(1).forEach { assertArrayEquals(neutral, it) }
        assertArrayEquals(neutral, pump.currentReport())
    }

    @Test fun stoppingTwiceDoesNotFlushAgain() {
        pump.setStreaming(true)
        pump.setStreaming(false)
        repeat(3) { pump.tick() }
        sent.clear()
        assertFalse(pump.setStreaming(false))
        assertFalse(pump.tick())
        assertTrue(sent.isEmpty())
    }

    @Test fun restartingCancelsThePendingFlush() {
        pump.setStreaming(true)
        pump.setStreaming(false)
        pump.setStreaming(true)
        pump.update(pressedA)
        pump.tick()
        assertArrayEquals(pressedA.toReport(), sent.single())
        assertTrue(pump.isStreaming)
    }

    @Test fun currentReportAnswersGetReport() {
        pump.update(pressedA)
        assertArrayEquals(pressedA.toReport(), pump.currentReport())
    }

    @Test fun rateIsAtLeast60Hz() {
        assertTrue(1000.0 / GamepadReportPump.INTERVAL_MS >= 60.0)
    }
}
