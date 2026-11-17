package com.example.couchmouse

import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Bit indices into the 16-bit button field of the gamepad report (Report ID 3).
 *
 * The order mirrors Linux `BTN_GAMEPAD` and Android's `Generic.kl`
 * (HID button N maps to `BTN_GAMEPAD + N - 1`), so Linux and Android hosts
 * label the buttons correctly without any extra mapping. Slots 2 (C) and
 * 5 (Z) exist in that convention but are not present on modern pads.
 */
object GamepadButton {
    const val A = 0       // South
    const val B = 1       // East
    const val C = 2       // unused
    const val X = 3       // North
    const val Y = 4       // West
    const val Z = 5       // unused
    const val L1 = 6
    const val R1 = 7
    const val L2 = 8      // digital trigger click
    const val R2 = 9      // digital trigger click
    const val SELECT = 10
    const val START = 11
    const val MODE = 12   // Home / Guide
    const val L3 = 13
    const val R3 = 14

    fun mask(button: Int): Int = 1 shl button
}

/** HID hat switch values: 0 = up, then clockwise in 45° steps; 8 = centred (null). */
object Hat {
    const val UP = 0
    const val UP_RIGHT = 1
    const val RIGHT = 2
    const val DOWN_RIGHT = 3
    const val DOWN = 4
    const val DOWN_LEFT = 5
    const val LEFT = 6
    const val UP_LEFT = 7
    const val CENTERED = 8

    /** Converts D-pad direction flags to a hat value. Opposing directions cancel out. */
    fun fromDpad(up: Boolean, down: Boolean, left: Boolean, right: Boolean): Int {
        val vertical = (if (up) -1 else 0) + (if (down) 1 else 0)
        val horizontal = (if (left) -1 else 0) + (if (right) 1 else 0)
        return when {
            vertical < 0 && horizontal == 0 -> UP
            vertical < 0 && horizontal > 0 -> UP_RIGHT
            vertical == 0 && horizontal > 0 -> RIGHT
            vertical > 0 && horizontal > 0 -> DOWN_RIGHT
            vertical > 0 && horizontal == 0 -> DOWN
            vertical > 0 && horizontal < 0 -> DOWN_LEFT
            vertical == 0 && horizontal < 0 -> LEFT
            vertical < 0 && horizontal < 0 -> UP_LEFT
            else -> CENTERED
        }
    }
}

/**
 * Snapshot of everything the gamepad report carries.
 *
 * Stick axes are in -1..1 (positive X = right, positive Y = down, matching
 * both Android `MotionEvent` and HID conventions). Triggers are in 0..1.
 */
data class GamepadState(
    val buttons: Int = 0,
    val hat: Int = Hat.CENTERED,
    val leftX: Float = 0f,
    val leftY: Float = 0f,
    val rightX: Float = 0f,
    val rightY: Float = 0f,
    val leftTrigger: Float = 0f,
    val rightTrigger: Float = 0f,
) {
    fun isPressed(button: Int): Boolean = buttons and GamepadButton.mask(button) != 0

    fun toReport(): ByteArray = GamepadReport.encode(this)

    companion object {
        val NEUTRAL = GamepadState()
    }
}

/**
 * Encoder for the 13-byte gamepad input report (without the report ID byte,
 * which `BluetoothHidDevice.sendReport` prepends). Layout must stay in sync
 * with [HidDescriptors.GAMEPAD_COLLECTION]:
 *
 * | Bytes | Field                                   |
 * |-------|-----------------------------------------|
 * | 0-1   | 16 buttons, little-endian bitfield      |
 * | 2     | hat (low nibble), 4 bits padding        |
 * | 3-4   | left stick X  (int16 LE)                |
 * | 5-6   | left stick Y  (int16 LE)                |
 * | 7-8   | right stick X (usage Z, int16 LE)       |
 * | 9-10  | right stick Y (usage Rz, int16 LE)      |
 * | 11    | right trigger (Accelerator, uint8)      |
 * | 12    | left trigger  (Brake, uint8)            |
 */
object GamepadReport {
    const val REPORT_ID = 3
    const val SIZE = 13
    const val AXIS_MAX = 32767

    fun encode(state: GamepadState): ByteArray {
        val out = ByteArray(SIZE)
        out[0] = (state.buttons and 0xFF).toByte()
        out[1] = ((state.buttons shr 8) and 0xFF).toByte()
        val hat = if (state.hat in Hat.UP..Hat.UP_LEFT) state.hat else Hat.CENTERED
        out[2] = hat.toByte()
        putInt16(out, 3, axisToInt16(state.leftX))
        putInt16(out, 5, axisToInt16(state.leftY))
        putInt16(out, 7, axisToInt16(state.rightX))
        putInt16(out, 9, axisToInt16(state.rightY))
        out[11] = triggerToUint8(state.rightTrigger).toByte()
        out[12] = triggerToUint8(state.leftTrigger).toByte()
        return out
    }

    /** Maps -1..1 to -32767..32767; NaN is treated as centred. */
    fun axisToInt16(value: Float): Int {
        if (value.isNaN()) return 0
        return (value.coerceIn(-1f, 1f) * AXIS_MAX).roundToInt()
    }

    /** Maps 0..1 to 0..255; NaN is treated as released. */
    fun triggerToUint8(value: Float): Int {
        if (value.isNaN()) return 0
        return (value.coerceIn(0f, 1f) * 255f).roundToInt()
    }

    /**
     * Radial deadzone: inputs inside [deadzone] snap to centre and the
     * remaining range is rescaled so full deflection still reaches 1.0.
     * The vector is never pulled onto the unit circle, so with a zero
     * deadzone the input passes through unchanged (square-gate corners such
     * as (1, 1) stay (1, 1)); components are only clamped to -1..1.
     */
    fun applyRadialDeadzone(x: Float, y: Float, deadzone: Float): Pair<Float, Float> {
        if (!x.isFinite() || !y.isFinite()) return 0f to 0f
        val dz = deadzone.coerceIn(0f, 0.99f)
        if (dz == 0f) return x.coerceIn(-1f, 1f) to y.coerceIn(-1f, 1f)
        val magnitude = sqrt(x * x + y * y)
        if (magnitude <= dz) return 0f to 0f
        val scale = ((magnitude - dz) / (1f - dz)) / magnitude
        return (x * scale).coerceIn(-1f, 1f) to (y * scale).coerceIn(-1f, 1f)
    }

    private fun putInt16(out: ByteArray, offset: Int, value: Int) {
        out[offset] = (value and 0xFF).toByte()
        out[offset + 1] = ((value shr 8) and 0xFF).toByte()
    }
}
