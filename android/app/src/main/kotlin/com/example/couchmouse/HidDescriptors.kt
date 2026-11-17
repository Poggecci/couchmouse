package com.example.couchmouse

object HidDescriptors {
    val COMPOSITE_DESCRIPTOR = byteArrayOf(
        // KEYBOARD
        0x05.toByte(), 0x01.toByte(), // USAGE_PAGE (Generic Desktop)
        0x09.toByte(), 0x06.toByte(), // USAGE (Keyboard)
        0xa1.toByte(), 0x01.toByte(), // COLLECTION (Application)
        0x85.toByte(), 0x01.toByte(), //   REPORT_ID (1)
        
        // Modifiers (8 bits)
        0x05.toByte(), 0x07.toByte(), //   USAGE_PAGE (Keyboard/Keypad)
        0x19.toByte(), 0xe0.toByte(), //   USAGE_MINIMUM (Keyboard LeftControl)
        0x29.toByte(), 0xe7.toByte(), //   USAGE_MAXIMUM (Keyboard Right GUI)
        0x15.toByte(), 0x00.toByte(), //   LOGICAL_MINIMUM (0)
        0x25.toByte(), 0x01.toByte(), //   LOGICAL_MAXIMUM (1)
        0x75.toByte(), 0x01.toByte(), //   REPORT_SIZE (1)
        0x95.toByte(), 0x08.toByte(), //   REPORT_COUNT (8)
        0x81.toByte(), 0x02.toByte(), //   INPUT (Data,Var,Abs)
        
        // Reserved byte (1 byte constant padding)
        0x95.toByte(), 0x01.toByte(), //   REPORT_COUNT (1)
        0x75.toByte(), 0x08.toByte(), //   REPORT_SIZE (8)
        0x81.toByte(), 0x03.toByte(), //   INPUT (Cnst,Var,Abs)
        
        // Keycodes (6 bytes, 6-key rollover)
        0x95.toByte(), 0x06.toByte(), //   REPORT_COUNT (6)
        0x75.toByte(), 0x08.toByte(), //   REPORT_SIZE (8)
        0x15.toByte(), 0x00.toByte(), //   LOGICAL_MINIMUM (0)
        0x25.toByte(), 0xff.toByte(), //   LOGICAL_MAXIMUM (255)
        0x05.toByte(), 0x07.toByte(), //   USAGE_PAGE (Keyboard/Keypad)
        0x19.toByte(), 0x00.toByte(), //   USAGE_MINIMUM (Reserved)
        0x29.toByte(), 0xff.toByte(), //   USAGE_MAXIMUM (Keyboard Application)
        0x81.toByte(), 0x00.toByte(), //   INPUT (Data,Ary,Abs)
        0xc0.toByte(),                // END_COLLECTION
        
        // MOUSE
        0x05.toByte(), 0x01.toByte(), // USAGE_PAGE (Generic Desktop)
        0x09.toByte(), 0x02.toByte(), // USAGE (Mouse)
        0xa1.toByte(), 0x01.toByte(), // COLLECTION (Application)
        0x85.toByte(), 0x02.toByte(), //   REPORT_ID (2)
        0x09.toByte(), 0x01.toByte(), //   USAGE (Pointer)
        0xa1.toByte(), 0x00.toByte(), //   COLLECTION (Physical)
        
        // Buttons (3 bits)
        0x05.toByte(), 0x09.toByte(), //     USAGE_PAGE (Button)
        0x19.toByte(), 0x01.toByte(), //     USAGE_MINIMUM (Button 1)
        0x29.toByte(), 0x03.toByte(), //     USAGE_MAXIMUM (Button 3)
        0x15.toByte(), 0x00.toByte(), //     LOGICAL_MINIMUM (0)
        0x25.toByte(), 0x01.toByte(), //     LOGICAL_MAXIMUM (1)
        0x95.toByte(), 0x03.toByte(), //     REPORT_COUNT (3)
        0x75.toByte(), 0x01.toByte(), //     REPORT_SIZE (1)
        0x81.toByte(), 0x02.toByte(), //     INPUT (Data,Var,Abs)
        
        // Padding (5 bits)
        0x95.toByte(), 0x01.toByte(), //     REPORT_COUNT (1)
        0x75.toByte(), 0x05.toByte(), //     REPORT_SIZE (5)
        0x81.toByte(), 0x03.toByte(), //     INPUT (Cnst,Var,Abs)
        
        // Relative X, Y position & Wheel (8-bit signed)
        0x05.toByte(), 0x01.toByte(), //     USAGE_PAGE (Generic Desktop)
        0x09.toByte(), 0x30.toByte(), //     USAGE (X)
        0x09.toByte(), 0x31.toByte(), //     USAGE (Y)
        0x09.toByte(), 0x38.toByte(), //     USAGE (Wheel)
        0x15.toByte(), 0x81.toByte(), //     LOGICAL_MINIMUM (-127)
        0x25.toByte(), 0x7f.toByte(), //     LOGICAL_MAXIMUM (127)
        0x75.toByte(), 0x08.toByte(), //     REPORT_SIZE (8)
        0x95.toByte(), 0x03.toByte(), //     REPORT_COUNT (3)
        0x81.toByte(), 0x06.toByte(), //     INPUT (Data,Var,Rel)
        
        0xc0.toByte(),                //   END_COLLECTION
        0xc0.toByte()                 // END_COLLECTION
    )

    /**
     * Generic HID gamepad (Report ID 3, 13-byte payload). The payload layout is
     * produced by [GamepadReport.encode]; keep the two in sync.
     */
    val GAMEPAD_COLLECTION = byteArrayOf(
        0x05.toByte(), 0x01.toByte(), // USAGE_PAGE (Generic Desktop)
        0x09.toByte(), 0x05.toByte(), // USAGE (Game Pad)
        0xa1.toByte(), 0x01.toByte(), // COLLECTION (Application)
        0x85.toByte(), 0x03.toByte(), //   REPORT_ID (3)

        // Buttons 1-16 (2 bytes)
        0x05.toByte(), 0x09.toByte(), //   USAGE_PAGE (Button)
        0x19.toByte(), 0x01.toByte(), //   USAGE_MINIMUM (Button 1)
        0x29.toByte(), 0x10.toByte(), //   USAGE_MAXIMUM (Button 16)
        0x15.toByte(), 0x00.toByte(), //   LOGICAL_MINIMUM (0)
        0x25.toByte(), 0x01.toByte(), //   LOGICAL_MAXIMUM (1)
        0x75.toByte(), 0x01.toByte(), //   REPORT_SIZE (1)
        0x95.toByte(), 0x10.toByte(), //   REPORT_COUNT (16)
        0x81.toByte(), 0x02.toByte(), //   INPUT (Data,Var,Abs)

        // Hat switch (4 bits, 8 = null/centred) + 4 bits padding
        0x05.toByte(), 0x01.toByte(), //   USAGE_PAGE (Generic Desktop)
        0x09.toByte(), 0x39.toByte(), //   USAGE (Hat switch)
        0x15.toByte(), 0x00.toByte(), //   LOGICAL_MINIMUM (0)
        0x25.toByte(), 0x07.toByte(), //   LOGICAL_MAXIMUM (7)
        0x35.toByte(), 0x00.toByte(), //   PHYSICAL_MINIMUM (0)
        0x46.toByte(), 0x3b.toByte(), 0x01.toByte(), // PHYSICAL_MAXIMUM (315)
        0x65.toByte(), 0x14.toByte(), //   UNIT (Eng Rot: Degrees)
        0x75.toByte(), 0x04.toByte(), //   REPORT_SIZE (4)
        0x95.toByte(), 0x01.toByte(), //   REPORT_COUNT (1)
        0x81.toByte(), 0x42.toByte(), //   INPUT (Data,Var,Abs,Null)
        0x65.toByte(), 0x00.toByte(), //   UNIT (None)
        0x45.toByte(), 0x00.toByte(), //   PHYSICAL_MAXIMUM (0) -> physical = logical
        0x75.toByte(), 0x04.toByte(), //   REPORT_SIZE (4)
        0x95.toByte(), 0x01.toByte(), //   REPORT_COUNT (1)
        0x81.toByte(), 0x03.toByte(), //   INPUT (Cnst,Var,Abs)

        // Sticks: left X/Y, right Z/Rz (int16, 8 bytes)
        0x09.toByte(), 0x30.toByte(), //   USAGE (X)
        0x09.toByte(), 0x31.toByte(), //   USAGE (Y)
        0x09.toByte(), 0x32.toByte(), //   USAGE (Z)
        0x09.toByte(), 0x35.toByte(), //   USAGE (Rz)
        0x16.toByte(), 0x01.toByte(), 0x80.toByte(), // LOGICAL_MINIMUM (-32767)
        0x26.toByte(), 0xff.toByte(), 0x7f.toByte(), // LOGICAL_MAXIMUM (32767)
        0x75.toByte(), 0x10.toByte(), //   REPORT_SIZE (16)
        0x95.toByte(), 0x04.toByte(), //   REPORT_COUNT (4)
        0x81.toByte(), 0x02.toByte(), //   INPUT (Data,Var,Abs)

        // Triggers: right = Accelerator, left = Brake (uint8, 2 bytes)
        0x05.toByte(), 0x02.toByte(), //   USAGE_PAGE (Simulation Controls)
        0x09.toByte(), 0xc4.toByte(), //   USAGE (Accelerator)
        0x09.toByte(), 0xc5.toByte(), //   USAGE (Brake)
        0x15.toByte(), 0x00.toByte(), //   LOGICAL_MINIMUM (0)
        0x26.toByte(), 0xff.toByte(), 0x00.toByte(), // LOGICAL_MAXIMUM (255)
        0x75.toByte(), 0x08.toByte(), //   REPORT_SIZE (8)
        0x95.toByte(), 0x02.toByte(), //   REPORT_COUNT (2)
        0x81.toByte(), 0x02.toByte(), //   INPUT (Data,Var,Abs)
        0xc0.toByte()                 // END_COLLECTION
    )
}
