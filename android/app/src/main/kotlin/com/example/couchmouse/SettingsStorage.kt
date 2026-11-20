package com.example.couchmouse

import android.content.Context
import androidx.datastore.core.Serializer
import androidx.datastore.dataStore
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

// DataStore values must be immutable. Keep the byte array private and copy it
// at the channel boundary; Dart owns the protobuf schema and its validation.
private class SettingsPayload(bytes: ByteArray) {
    private val contents = bytes.copyOf()

    fun toByteArray(): ByteArray = contents.copyOf()
    fun writeTo(output: OutputStream) = output.write(contents)
}

private object SettingsSerializer : Serializer<SettingsPayload> {
    override val defaultValue = SettingsPayload(byteArrayOf())

    override suspend fun readFrom(input: InputStream): SettingsPayload =
        SettingsPayload(input.readBytes())

    override suspend fun writeTo(t: SettingsPayload, output: OutputStream) =
        t.writeTo(output)
}

private val Context.settingsDataStore by dataStore(
    fileName = "couchmouse-settings.pb",
    serializer = SettingsSerializer,
)

internal class SettingsStorage {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun read(context: Context, result: MethodChannel.Result) {
        scope.launch {
            try {
                result.success(context.settingsDataStore.data.first().toByteArray())
            } catch (error: IOException) {
                result.error("SETTINGS_READ_FAILED", "Could not read settings.", null)
            }
        }
    }

    fun write(context: Context, bytes: ByteArray, result: MethodChannel.Result) {
        val payload = SettingsPayload(bytes)
        scope.launch {
            try {
                context.settingsDataStore.updateData { payload }
                result.success(null)
            } catch (error: IOException) {
                result.error("SETTINGS_WRITE_FAILED", "Could not save settings.", null)
            }
        }
    }

    fun close() = scope.cancel()
}
