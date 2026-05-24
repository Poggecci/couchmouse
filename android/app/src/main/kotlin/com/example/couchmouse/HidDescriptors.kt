package com.example.couchmouse

object HidDescriptors {
    val MOUSE_DESCRIPTOR = byteArrayOf(
        0x05.toByte(), 0x01.toByte(), // USAGE_PAGE (Generic Desktop)
        0x09.toByte(), 0x02.toByte(), // USAGE (Mouse)
        0xa1.toByte(), 0x01.toByte(), // COLLECTION (Application)
        0x09.toByte(), 0x01.toByte(), //   USAGE (Pointer)
        0xa1.toByte(), 0x00.toByte(), //   COLLECTION (Physical)
        
        // Bytes 0: Button States (Bit 0 = Left, Bit 1 = Right, Bit 2 = Middle)
        0x05.toByte(), 0x09.toByte(), //     USAGE_PAGE (Button)
        0x19.toByte(), 0x01.toByte(), //     USAGE_MINIMUM (Button 1)
        0x29.toByte(), 0x03.toByte(), //     USAGE_MAXIMUM (Button 3)
        0x15.toByte(), 0x00.toByte(), //     LOGICAL_MINIMUM (0)
        0x25.toByte(), 0x01.toByte(), //     LOGICAL_MAXIMUM (1)
        0x95.toByte(), 0x03.toByte(), //     REPORT_COUNT (3)
        0x75.toByte(), 0x01.toByte(), //     REPORT_SIZE (1)
        0x81.toByte(), 0x02.toByte(), //     INPUT (Data,Var,Abs)
        
        // 5-bit Padding to complete Byte 0
        0x95.toByte(), 0x01.toByte(), //     REPORT_COUNT (1)
        0x75.toByte(), 0x05.toByte(), //     REPORT_SIZE (5)
        0x81.toByte(), 0x03.toByte(), //     INPUT (Cnst,Var,Abs)
        
        // Bytes 1, 2, 3: Relative Axis Movements (X, Y, Scroll Wheel)
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
}
