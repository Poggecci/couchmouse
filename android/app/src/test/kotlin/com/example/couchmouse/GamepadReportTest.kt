package com.example.couchmouse

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GamepadReportTest {
    private fun u(b: Byte) = b.toInt() and 0xFF
    private fun int16(r: ByteArray, o: Int) = ((u(r[o + 1]) shl 8) or u(r[o])).toShort().toInt()

    @Test fun neutralReport() {
        val r = GamepadState.NEUTRAL.toReport()
        assertEquals(GamepadReport.SIZE, r.size)
        val expected = ByteArray(13).also { it[2] = Hat.CENTERED.toByte() }
        assertArrayEquals(expected, r)
    }

    @Test fun buttonBitsLittleEndian() {
        val s = GamepadState(buttons = GamepadButton.mask(GamepadButton.A) or GamepadButton.mask(GamepadButton.R3))
        val r = s.toReport()
        assertEquals(0x01, u(r[0]))          // A = bit 0
        assertEquals(0x40, u(r[1]))          // R3 = bit 14 -> byte1 bit 6
        assertTrue(s.isPressed(GamepadButton.A)); assertFalse(s.isPressed(GamepadButton.B))
    }

    @Test fun everyButtonHasDistinctBit() {
        val all = listOf(GamepadButton.A, GamepadButton.B, GamepadButton.X, GamepadButton.Y,
            GamepadButton.L1, GamepadButton.R1, GamepadButton.L2, GamepadButton.R2,
            GamepadButton.SELECT, GamepadButton.START, GamepadButton.MODE, GamepadButton.L3, GamepadButton.R3)
        assertEquals(all.size, all.map { GamepadButton.mask(it) }.toSet().size)
        assertTrue(all.all { it in 0..15 })
    }

    @Test fun hatAllDirections() {
        fun h(u: Boolean, d: Boolean, l: Boolean, r: Boolean) = Hat.fromDpad(u, d, l, r)
        assertEquals(Hat.CENTERED, h(false, false, false, false))
        assertEquals(Hat.UP, h(true, false, false, false))
        assertEquals(Hat.UP_RIGHT, h(true, false, false, true))
        assertEquals(Hat.RIGHT, h(false, false, false, true))
        assertEquals(Hat.DOWN_RIGHT, h(false, true, false, true))
        assertEquals(Hat.DOWN, h(false, true, false, false))
        assertEquals(Hat.DOWN_LEFT, h(false, true, true, false))
        assertEquals(Hat.LEFT, h(false, false, true, false))
        assertEquals(Hat.UP_LEFT, h(true, false, true, false))
    }

    @Test fun hatOpposingDirectionsCancel() {
        assertEquals(Hat.CENTERED, Hat.fromDpad(true, true, false, false))
        assertEquals(Hat.CENTERED, Hat.fromDpad(false, false, true, true))
        assertEquals(Hat.RIGHT, Hat.fromDpad(true, true, false, true))
        assertEquals(Hat.CENTERED, Hat.fromDpad(true, true, true, true))
    }

    @Test fun invalidHatEncodesAsCentered() {
        assertEquals(Hat.CENTERED, u(GamepadState(hat = 42).toReport()[2]))
        assertEquals(Hat.CENTERED, u(GamepadState(hat = -1).toReport()[2]))
    }

    @Test fun axesClampAndEncodeSigned() {
        val r = GamepadState(leftX = 1f, leftY = -1f, rightX = 5f, rightY = -0.5f).toReport()
        assertEquals(32767, int16(r, 3))
        assertEquals(-32767, int16(r, 5))
        assertEquals(32767, int16(r, 7))   // clamped
        assertEquals(-16383, int16(r, 9))  // -16383.5 rounds half toward +inf
    }

    @Test fun nanIsNeutral() {
        val r = GamepadState(leftX = Float.NaN, rightTrigger = Float.NaN).toReport()
        assertEquals(0, int16(r, 3)); assertEquals(0, u(r[11]))
    }

    @Test fun triggersOrderAndRange() {
        val r = GamepadState(leftTrigger = 0.5f, rightTrigger = 1.2f).toReport()
        assertEquals(255, u(r[11]))  // right trigger = Accelerator first
        assertEquals(128, u(r[12]))  // left trigger = Brake second
        assertEquals(0, u(GamepadState(leftTrigger = -1f).toReport()[12]))
    }

    @Test fun deadzone() {
        assertEquals(Pair(0f, 0f), GamepadReport.applyRadialDeadzone(0.05f, 0.05f, 0.1f))
        val (x, y) = GamepadReport.applyRadialDeadzone(1f, 0f, 0.1f)
        assertEquals(1f, x, 1e-6f); assertEquals(0f, y, 0f)
        val (hx, _) = GamepadReport.applyRadialDeadzone(0.55f, 0f, 0.1f)
        assertEquals(0.5f, hx, 1e-6f)  // (0.55-0.1)/0.9
        val (dx, dy) = GamepadReport.applyRadialDeadzone(1f, 1f, 0.1f) // corner, magnitude > 1
        assertTrue(dx <= 1f && dy <= 1f && dx > 0.7f)
        assertEquals(Pair(0f, 0f), GamepadReport.applyRadialDeadzone(Float.NaN, 0f, 0.1f))
    }

    @Test fun zeroDeadzonePassesThroughUnchanged() {
        assertEquals(Pair(1f, 1f), GamepadReport.applyRadialDeadzone(1f, 1f, 0f))
        assertEquals(Pair(0.3f, -0.2f), GamepadReport.applyRadialDeadzone(0.3f, -0.2f, 0f))
        assertEquals(Pair(1f, -1f), GamepadReport.applyRadialDeadzone(1.5f, -2f, 0f))
        assertEquals(Pair(0f, 0f), GamepadReport.applyRadialDeadzone(Float.POSITIVE_INFINITY, 0f, 0f))
    }

    @Test fun descriptorHasReportId3() {
        val d = HidDescriptors.GAMEPAD_COLLECTION
        val i = (0 until d.size - 1).first { d[it] == 0x85.toByte() }
        assertEquals(GamepadReport.REPORT_ID, d[i + 1].toInt())
    }

    @Test fun compositeDescriptorEndsWithGamepadAndHasAllReportIds() {
        val composite = HidDescriptors.COMPOSITE_DESCRIPTOR
        val gamepad = HidDescriptors.GAMEPAD_COLLECTION
        assertTrue(composite.size > gamepad.size)
        assertArrayEquals(gamepad, composite.copyOfRange(composite.size - gamepad.size, composite.size))
        val reportIds = (0 until composite.size - 1)
            .filter { composite[it] == 0x85.toByte() }
            .map { composite[it + 1].toInt() }
        assertEquals(listOf(1, 2, 3), reportIds)
    }
}
