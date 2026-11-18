package com.example.couchmouse

import android.view.KeyEvent
import android.view.MotionEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Only Android *constants* are used here; Kotlin inlines them, so these run
// as plain JVM tests (no Robolectric, no "Method ... not mocked").
class GamepadInputMapperTest {
    private val mapper = GamepadInputMapper()

    private fun axes(vararg values: Pair<Int, Float>): (Int) -> Float {
        val map = values.toMap()
        return { map[it] ?: 0f }
    }

    @Test fun faceButtonsMapToLinuxGamepadOrder() {
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_A, true)
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_Y, true)
        assertTrue(mapper.state.isPressed(GamepadButton.A))
        assertTrue(mapper.state.isPressed(GamepadButton.Y))
        assertEquals(GamepadButton.mask(GamepadButton.A) or GamepadButton.mask(GamepadButton.Y), mapper.state.buttons)
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_A, false)
        assertFalse(mapper.state.isPressed(GamepadButton.A))
        assertTrue(mapper.state.isPressed(GamepadButton.Y))
    }

    @Test fun allControllerButtonsAreHandled() {
        val codes = listOf(
            KeyEvent.KEYCODE_BUTTON_A, KeyEvent.KEYCODE_BUTTON_B, KeyEvent.KEYCODE_BUTTON_X,
            KeyEvent.KEYCODE_BUTTON_Y, KeyEvent.KEYCODE_BUTTON_L1, KeyEvent.KEYCODE_BUTTON_R1,
            KeyEvent.KEYCODE_BUTTON_L2, KeyEvent.KEYCODE_BUTTON_R2, KeyEvent.KEYCODE_BUTTON_SELECT,
            KeyEvent.KEYCODE_BUTTON_START, KeyEvent.KEYCODE_BUTTON_MODE,
            KeyEvent.KEYCODE_BUTTON_THUMBL, KeyEvent.KEYCODE_BUTTON_THUMBR,
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT,
        )
        codes.forEach { assertTrue("keycode $it", mapper.handles(it)) }
    }

    @Test fun systemKeysAreNotHandled() {
        listOf(KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_HOME, KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_POWER, KeyEvent.KEYCODE_A,
            KeyEvent.KEYCODE_DPAD_CENTER).forEach {
            assertFalse("keycode $it", mapper.handles(it))
            assertFalse(mapper.onKey(it, true))
        }
        assertEquals(GamepadState.NEUTRAL, mapper.state)
    }

    @Test fun dpadKeysProduceHat() {
        mapper.onKey(KeyEvent.KEYCODE_DPAD_UP, true)
        mapper.onKey(KeyEvent.KEYCODE_DPAD_RIGHT, true)
        assertEquals(Hat.UP_RIGHT, mapper.state.hat)
        mapper.onKey(KeyEvent.KEYCODE_DPAD_UP, false)
        assertEquals(Hat.RIGHT, mapper.state.hat)
        mapper.onKey(KeyEvent.KEYCODE_DPAD_RIGHT, false)
        assertEquals(Hat.CENTERED, mapper.state.hat)
    }

    @Test fun hatAxesProduceHat() {
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_HAT_X to -1f, MotionEvent.AXIS_HAT_Y to 1f))
        assertEquals(Hat.DOWN_LEFT, mapper.state.hat)
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes())
        assertEquals(Hat.CENTERED, mapper.state.hat)
    }

    @Test fun sticksUseLayoutAxes() {
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(
            MotionEvent.AXIS_X to 0.5f, MotionEvent.AXIS_Y to -0.25f,
            MotionEvent.AXIS_Z to 1f, MotionEvent.AXIS_RZ to -1f,
            MotionEvent.AXIS_RX to 0.9f, // ignored with the default (Z/RZ) layout
        ))
        assertEquals(0.5f, mapper.state.leftX, 1e-6f)
        assertEquals(-0.25f, mapper.state.leftY, 1e-6f)
        assertEquals(1f, mapper.state.rightX, 1e-6f)
        assertEquals(-1f, mapper.state.rightY, 1e-6f)

        val rxLayout = GamepadAxisLayout(rightStickXAxis = MotionEvent.AXIS_RX, rightStickYAxis = MotionEvent.AXIS_RY)
        mapper.onMotion(rxLayout, axes(MotionEvent.AXIS_RX to 0.3f, MotionEvent.AXIS_RY to 0.4f))
        assertEquals(0.3f, mapper.state.rightX, 1e-6f)
        assertEquals(0.4f, mapper.state.rightY, 1e-6f)
    }

    @Test fun deviceFlatIsAppliedAsDeadzone() {
        val layout = GamepadAxisLayout(leftStickFlat = 0.1f)
        mapper.onMotion(layout, axes(MotionEvent.AXIS_X to 0.08f))
        assertEquals(0f, mapper.state.leftX, 0f)
        mapper.onMotion(layout, axes(MotionEvent.AXIS_X to 1f))
        assertEquals(1f, mapper.state.leftX, 1e-6f)
    }

    @Test fun triggersReadEitherAxisPair() {
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_BRAKE to 0.4f, MotionEvent.AXIS_RTRIGGER to 0.2f))
        assertEquals(0.4f, mapper.state.leftTrigger, 1e-6f)
        assertEquals(0.2f, mapper.state.rightTrigger, 1e-6f)
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_LTRIGGER to 0.7f, MotionEvent.AXIS_GAS to 0.9f))
        assertEquals(0.7f, mapper.state.leftTrigger, 1e-6f)
        assertEquals(0.9f, mapper.state.rightTrigger, 1e-6f)
    }

    @Test fun analogTriggerPastThresholdAlsoPressesDigitalButton() {
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_LTRIGGER to 0.3f))
        assertFalse(mapper.state.isPressed(GamepadButton.L2))
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_LTRIGGER to 0.8f))
        assertTrue(mapper.state.isPressed(GamepadButton.L2))
    }

    @Test fun digitalOnlyTriggersReportFullPull() {
        val digital = GamepadAxisLayout(hasAnalogLeftTrigger = false, hasAnalogRightTrigger = false)
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_R2, true, digital)
        assertEquals(1f, mapper.state.rightTrigger, 0f)
        assertTrue(mapper.state.isPressed(GamepadButton.R2))
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_R2, false, digital)
        assertEquals(0f, mapper.state.rightTrigger, 0f)
        assertFalse(mapper.state.isPressed(GamepadButton.R2))
    }

    @Test fun motionDoesNotClearHeldButtons() {
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_B, true)
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_X to 1f))
        assertTrue(mapper.state.isPressed(GamepadButton.B))
        assertEquals(1f, mapper.state.leftX, 1e-6f)
    }

    @Test fun nanAxesAreTreatedAsNeutral() {
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_X to Float.NaN, MotionEvent.AXIS_HAT_X to Float.NaN,
            MotionEvent.AXIS_LTRIGGER to Float.NaN))
        assertEquals(GamepadState.NEUTRAL, mapper.state)
    }

    @Test fun resetReleasesEverything() {
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_A, true)
        mapper.onKey(KeyEvent.KEYCODE_DPAD_UP, true)
        mapper.onMotion(GamepadAxisLayout.DEFAULT, axes(MotionEvent.AXIS_X to 1f, MotionEvent.AXIS_GAS to 1f))
        mapper.reset()
        assertEquals(GamepadState.NEUTRAL, mapper.state)
        // A later unrelated event must not resurrect old input.
        mapper.onKey(KeyEvent.KEYCODE_BUTTON_X, true)
        assertEquals(GamepadButton.mask(GamepadButton.X), mapper.state.buttons)
        assertEquals(Hat.CENTERED, mapper.state.hat)
    }

    @Test fun layoutFromDevicePrefersZRzAndDetectsTriggers() {
        val zrz = setOf(MotionEvent.AXIS_X, MotionEvent.AXIS_Y, MotionEvent.AXIS_Z, MotionEvent.AXIS_RZ,
            MotionEvent.AXIS_RX, MotionEvent.AXIS_RY, MotionEvent.AXIS_BRAKE)
        val a = GamepadAxisLayout.from({ it in zrz }, { 0.02f })
        assertEquals(MotionEvent.AXIS_Z, a.rightStickXAxis)
        assertEquals(MotionEvent.AXIS_RZ, a.rightStickYAxis)
        assertTrue(a.hasAnalogLeftTrigger)
        assertFalse(a.hasAnalogRightTrigger)
        assertEquals(0.02f, a.leftStickFlat, 0f)

        val rxry = setOf(MotionEvent.AXIS_X, MotionEvent.AXIS_Y, MotionEvent.AXIS_RX, MotionEvent.AXIS_RY)
        val b = GamepadAxisLayout.from({ it in rxry }, { if (it == MotionEvent.AXIS_RX) 0.9f else 0f })
        assertEquals(MotionEvent.AXIS_RX, b.rightStickXAxis)
        assertEquals(MotionEvent.AXIS_RY, b.rightStickYAxis)
        assertEquals(0.5f, b.rightStickFlat, 0f) // absurd flat values are capped
    }
}
