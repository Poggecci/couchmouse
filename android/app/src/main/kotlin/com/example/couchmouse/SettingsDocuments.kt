package com.example.couchmouse

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

internal class SettingsDocuments(private val activity: Activity) {
    private data class Request(val result: MethodChannel.Result, val contents: String?)

    private var pending: Request? = null

    @Suppress("DEPRECATION")
    fun open(result: MethodChannel.Result, contents: String? = null) {
        if (pending != null) {
            result.error("BUSY", "A settings file is already open.", null)
            return
        }

        pending = Request(result, contents)
        val action = if (contents == null) Intent.ACTION_OPEN_DOCUMENT else Intent.ACTION_CREATE_DOCUMENT
        val intent = Intent(action).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            if (contents != null) putExtra(Intent.EXTRA_TITLE, "couchmouse-settings.json")
        }
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (error: RuntimeException) {
            pending = null
            result.error("PICKER_FAILED", "Could not open the Android file picker.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        val request = pending ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            request.result.success(null)
            return
        }

        Thread {
            val response = runCatching {
                val resolver = activity.contentResolver
                val contents = request.contents
                if (contents == null) {
                    val input = resolver.openInputStream(uri) ?: throw IOException("Cannot open backup")
                    input.bufferedReader().use { reader ->
                        val buffer = CharArray(4096)
                        val text = StringBuilder()
                        while (true) {
                            val count = reader.read(buffer)
                            if (count == -1) break
                            if (text.length + count > MAX_BACKUP_LENGTH) {
                                throw IOException("Settings backup is too large")
                            }
                            text.append(buffer, 0, count)
                        }
                        text.toString()
                    }
                } else {
                    val output = resolver.openOutputStream(uri) ?: throw IOException("Cannot save backup")
                    output.bufferedWriter().use { it.write(contents) }
                    true
                }
            }
            activity.runOnUiThread {
                if (pending !== request) return@runOnUiThread
                pending = null
                response.fold(
                    onSuccess = { request.result.success(it) },
                    onFailure = {
                        val message = if (request.contents == null) {
                            "Could not read the settings backup."
                        } else {
                            "Could not save the settings backup."
                        }
                        request.result.error("BACKUP_FAILED", message, null)
                    }
                )
            }
        }.start()
    }

    fun close() {
        val request = pending
        pending = null
        request?.result?.success(null)
    }

    private companion object {
        const val REQUEST_CODE = 4387
        const val MAX_BACKUP_LENGTH = 1024 * 1024
    }
}
