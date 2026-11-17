package com.example.couchmouse

import android.view.KeyEvent
import android.view.MotionEvent
import kotlin.math.max

/**
 * Per-controller axis facts, read once from the device's motion ranges.
 *
 * Android normalises most controllers so the right stick is AXIS_Z/AXIS_RZ,
 * but some report it on AXIS_RX/AXIS_RY instead. Analog triggers arrive on
 * AXIS_LTRIGGER/AXIS_RTRIGGER or AXIS_BRAKE/AXIS_GAS depending on the
 * device's key layout file, so both are read.
 */
data class GamepadAxisLayout(
    val rightStickXAxis: Int = MotionEvent.AXIS_Z,
    val rightStickYAxis: Int = MotionEvent.AXIS_RZ,
    val hasAnalogLeftTrigger: Boolean = true,
    val hasAnalogRightTrigger: Boolean = true,
    /** Hardware noise band reported by the device (InputDevice.MotionRange.flat), 0..1. */
    val leftStickFlat: Float = 0f,
    val rightStickFlat: Float = 0f,
) {
    companion object {
        val DEFAULT = GamepadAxisLayout()

        fun from(hasAxis: (Int) -> Boolean, flat: (Int) -> Float): GamepadAxisLayout {
            val useRxRy = !(hasAxis(MotionEvent.AXIS_Z) && hasAxis(MotionEvent.AXIS_RZ)) &&
                hasAxis(MotionEvent.AXIS_RX) && hasAxis(MotionEvent.AXIS_RY)
            val rx = if (useRxRy) MotionEvent.AXIS_RX else MotionEvent.AXIS_Z
            val ry = if (useRxRy) MotionEvent.AXIS_RY else MotionEvent.AXIS_RZ
            return GamepadAxisLayout(
                rightStickXAxis = rx,
                rightStickYAxis = ry,
                hasAnalogLeftTrigger = hasAxis(MotionEvent.AXIS_LTRIGGER) || hasAxis(MotionEvent.AXIS_BRAKE),
                hasAnalogRightTrigger = hasAxis(MotionEvent.AXIS_RTRIGGER) || hasAxis(MotionEvent.AXIS_GAS),
                leftStickFlat = max(flat(MotionEvent.AXIS_X), flat(MotionEvent.AXIS_Y)).coerceIn(0f, 0.5f),
                rightStickFlat = max(flat(rx), flat(ry)).coerceIn(0f, 0.5f),
            )
        }
    }
}

/**
 * Turns Android controller key and motion input into a [GamepadState].
 *
 * Holds no Android objects: callers pass keycodes and an axis-reader
 * function, which keeps this unit-testable on the JVM. Not thread-safe;
 * call it from the main thread only.
 */
class GamepadInputMapper {
    private var buttons = 0
    private var dpadKeys = 0
    private var hatX = 0f
    private var hatY = 0f
    private var leftX = 0f
    private var leftY = 0f
    private var rightX = 0f
    private var rightY = 0f
    private var analogLeftTrigger = 0f
    private var analogRightTrigger = 0f
    private var layout = GamepadAxisLayout.DEFAULT

    var state: GamepadState = GamepadState.NEUTRAL
        private set

    /** True for keys this mapper turns into gamepad input (buttons and D-pad). */
    fun handles(keyCode: Int): Boolean = keyCode in BUTTONS || keyCode in DPAD

    /**
     * Applies a key press or release. Returns true if the key belongs to the
     * gamepad (whether or not the state changed), false if it should be left
     * to the system (Back, Volume, …).
     */
    fun onKey(keyCode: Int, pressed: Boolean, deviceLayout: GamepadAxisLayout = layout): Boolean {
        layout = deviceLayout
        val button = BUTTONS[keyCode]
        val dpadBit = DPAD[keyCode]
        when {
            button != null -> buttons = buttons.withBit(GamepadButton.mask(button), pressed)
            dpadBit != null -> dpadKeys = dpadKeys.withBit(dpadBit, pressed)
            else -> return false
        }
        rebuild()
        return true
    }

    /** Applies the latest sample of a joystick MotionEvent. */
    fun onMotion(deviceLayout: GamepadAxisLayout, axis: (Int) -> Float) {
        layout = deviceLayout
        leftX = axis(MotionEvent.AXIS_X)
        leftY = axis(MotionEvent.AXIS_Y)
        rightX = axis(deviceLayout.rightStickXAxis)
        rightY = axis(deviceLayout.rightStickYAxis)
        hatX = axis(MotionEvent.AXIS_HAT_X)
        hatY = axis(MotionEvent.AXIS_HAT_Y)
        analogLeftTrigger = maxOf(axis(MotionEvent.AXIS_LTRIGGER), axis(MotionEvent.AXIS_BRAKE))
        analogRightTrigger = maxOf(axis(MotionEvent.AXIS_RTRIGGER), axis(MotionEvent.AXIS_GAS))
        rebuild()
    }

    /** Forgets all held input, e.g. when gamepad mode is turned off. */
    fun reset() {
        buttons = 0
        dpadKeys = 0
        hatX = 0f; hatY = 0f
        leftX = 0f; leftY = 0f
        rightX = 0f; rightY = 0f
        analogLeftTrigger = 0f; analogRightTrigger = 0f
        state = GamepadState.NEUTRAL
    }

    private fun rebuild() {
        val (lx, ly) = GamepadReport.applyRadialDeadzone(leftX, leftY, layout.leftStickFlat)
        val (rx, ry) = GamepadReport.applyRadialDeadzone(rightX, rightY, layout.rightStickFlat)

        val l2Held = buttons and GamepadButton.mask(GamepadButton.L2) != 0
        val r2Held = buttons and GamepadButton.mask(GamepadButton.R2) != 0
        // Controllers without analog triggers only send L2/R2 keys: report full pull.
        val lt = if (layout.hasAnalogLeftTrigger) analogLeftTrigger.finiteOr0() else if (l2Held) 1f else 0f
        val rt = if (layout.hasAnalogRightTrigger) analogRightTrigger.finiteOr0() else if (r2Held) 1f else 0f

        // Controllers with analog triggers often send no L2/R2 keys: derive them,
        // so hosts that only read buttons still see the triggers.
        var reportButtons = buttons
        if (lt > TRIGGER_BUTTON_THRESHOLD) reportButtons = reportButtons or GamepadButton.mask(GamepadButton.L2)
        if (rt > TRIGGER_BUTTON_THRESHOLD) reportButtons = reportButtons or GamepadButton.mask(GamepadButton.R2)

        val up = dpadKeys and DPAD_UP != 0 || hatY.finiteOr0() < -HAT_THRESHOLD
        val down = dpadKeys and DPAD_DOWN != 0 || hatY.finiteOr0() > HAT_THRESHOLD
        val left = dpadKeys and DPAD_LEFT != 0 || hatX.finiteOr0() < -HAT_THRESHOLD
        val right = dpadKeys and DPAD_RIGHT != 0 || hatX.finiteOr0() > HAT_THRESHOLD

        state = GamepadState(
            buttons = reportButtons,
            hat = Hat.fromDpad(up, down, left, right),
            leftX = lx, leftY = ly,
            rightX = rx, rightY = ry,
            leftTrigger = lt, rightTrigger = rt,
        )
    }

    private fun Int.withBit(bit: Int, set: Boolean) = if (set) this or bit else this and bit.inv()
    private fun Float.finiteOr0() = if (isFinite()) this else 0f

    companion object {
        const val TRIGGER_BUTTON_THRESHOLD = 0.5f
        const val HAT_THRESHOLD = 0.5f

        private const val DPAD_UP = 1
        private const val DPAD_DOWN = 2
        private const val DPAD_LEFT = 4
        private const val DPAD_RIGHT = 8

        private val BUTTONS: Map<Int, Int> = mapOf(
            KeyEvent.KEYCODE_BUTTON_A to GamepadButton.A,
            KeyEvent.KEYCODE_BUTTON_B to GamepadButton.B,
            KeyEvent.KEYCODE_BUTTON_C to GamepadButton.C,
            KeyEvent.KEYCODE_BUTTON_X to GamepadButton.X,
            KeyEvent.KEYCODE_BUTTON_Y to GamepadButton.Y,
            KeyEvent.KEYCODE_BUTTON_Z to GamepadButton.Z,
            KeyEvent.KEYCODE_BUTTON_L1 to GamepadButton.L1,
            KeyEvent.KEYCODE_BUTTON_R1 to GamepadButton.R1,
            KeyEvent.KEYCODE_BUTTON_L2 to GamepadButton.L2,
            KeyEvent.KEYCODE_BUTTON_R2 to GamepadButton.R2,
            KeyEvent.KEYCODE_BUTTON_SELECT to GamepadButton.SELECT,
            KeyEvent.KEYCODE_BUTTON_START to GamepadButton.START,
            KeyEvent.KEYCODE_BUTTON_MODE to GamepadButton.MODE,
            KeyEvent.KEYCODE_BUTTON_THUMBL to GamepadButton.L3,
            KeyEvent.KEYCODE_BUTTON_THUMBR to GamepadButton.R3,
        )

        private val DPAD: Map<Int, Int> = mapOf(
            KeyEvent.KEYCODE_DPAD_UP to DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN to DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT to DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT to DPAD_RIGHT,
        )
    }
}
