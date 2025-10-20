package org.noam.jwlife

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "org.noam.jwlife.filehandler"
    private var pendingFilePath: String? = null
    private var methodChannel: MethodChannel? = null

    // Flag pour tracker le dernier fichier/URL traité
    private var lastProcessedUri: String? = null
    private var isFileProcessedAndSent = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingFile" -> {
                    val resultMap = if (pendingFilePath != null) {
                        if (pendingFilePath!!.startsWith("http")) {
                            mapOf("url" to pendingFilePath)
                        } else {
                            mapOf("filePath" to pendingFilePath)
                        }
                    } else {
                        null
                    }
                    result.success(resultMap)
                    pendingFilePath = null
                }
                "fileProcessed" -> {
                    println("Flutter a confirmé le traitement du fichier")
                    isFileProcessedAndSent = false
                    lastProcessedUri = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ========== OPTIMISATIONS CLAVIER MIUI/HyperOS ==========
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN or
                    WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN
        )

        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )

        try {
            window.attributes = window.attributes.apply {
                windowAnimations = android.R.style.Animation
            }
        } catch (e: Exception) {
            println("Impossible de modifier les animations: ${e.message}")
        }
        // ========== FIN OPTIMISATIONS ==========

        println("=== MainActivity onCreate ===")
        isFileProcessedAndSent = false
        lastProcessedUri = null
        handleIncomingFile(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        println("=== MainActivity onNewIntent ===")

        if (intent.action == null) {
            println("onNewIntent sans action, on ignore")
            return
        }

        isFileProcessedAndSent = false
        handleIncomingFile(intent)
    }

    private fun handleIncomingFile(intent: Intent?) {
        println("=== HANDLING INCOMING INTENT ===")
        println("Intent action: ${intent?.action}")
        println("Intent data: ${intent?.data}")
        println("Intent type: ${intent?.type}")

        when (intent?.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data
                println("ACTION_VIEW avec URI: $uri")
                if (uri != null) {
                    if (isJwOrgUrl(uri)) {
                        handleJwOrgUrl(uri)
                    } else {
                        processUri(uri)
                    }
                }
            }
            Intent.ACTION_SEND -> {
                when (intent.type) {
                    "text/plain" -> {
                        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                        println("ACTION_SEND avec texte: $sharedText")
                        if (!sharedText.isNullOrEmpty()) {
                            handleSharedText(sharedText)
                        }
                    }
                    else -> {
                        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                        println("ACTION_SEND avec URI: $uri")
                        if (uri != null) {
                            processUri(uri)
                        }
                    }
                }
            }
        }
    }

    private fun handleSharedText(sharedText: String) {
        println("=== HANDLING SHARED TEXT ===")
        println("Texte partagé: $sharedText")

        try {
            if (sharedText.startsWith("http://") || sharedText.startsWith("https://")) {
                val uri = Uri.parse(sharedText)

                if (isJwOrgUrl(uri)) {
                    handleJwOrgUrl(uri)
                } else {
                    handleGenericUrl(uri)
                }
            } else {
                handlePlainText(sharedText)
            }
        } catch (e: Exception) {
            println("Erreur lors du traitement du texte partagé: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun handleGenericUrl(uri: Uri) {
        println("=== HANDLING GENERIC URL ===")
        println("URL: $uri")

        try {
            val urlString = uri.toString()
            lastProcessedUri = urlString

            methodChannel?.let { channel ->
                println("Envoi de l'URL générique vers Flutter")
                channel.invokeMethod("onUrlReceived", mapOf("url" to urlString))
                isFileProcessedAndSent = true
            } ?: run {
                println("Flutter pas encore prêt, stockage de l'URL en pending")
                pendingFilePath = urlString
            }
        } catch (e: Exception) {
            println("Erreur lors du traitement de l'URL générique: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun handlePlainText(text: String) {
        println("=== HANDLING PLAIN TEXT ===")
        println("Texte: $text")

        try {
            lastProcessedUri = text

            methodChannel?.let { channel ->
                println("Envoi du texte vers Flutter")
                channel.invokeMethod("onTextReceived", mapOf("text" to text))
                isFileProcessedAndSent = true
            } ?: run {
                println("Flutter pas encore prêt, stockage du texte en pending")
                pendingFilePath = text
            }
        } catch (e: Exception) {
            println("Erreur lors du traitement du texte: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun isJwOrgUrl(uri: Uri): Boolean {
        val host = uri.host?.lowercase()
        return host == "jw.org" || host == "www.jw.org" || host == "wol.jw.org"
    }

    private fun handleJwOrgUrl(uri: Uri) {
        println("=== HANDLING JW.ORG URL ===")
        println("URL: $uri")

        try {
            val urlString = uri.toString()
            lastProcessedUri = urlString

            methodChannel?.let { channel ->
                println("Envoi de l'URL vers Flutter")
                channel.invokeMethod("onUrlReceived", mapOf("url" to urlString))
                isFileProcessedAndSent = true
            } ?: run {
                println("Flutter pas encore prêt, stockage de l'URL en pending")
                pendingFilePath = urlString
            }
        } catch (e: Exception) {
            println("Erreur lors du traitement de l'URL JW.org: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun processUri(uri: Uri) {
        try {
            println("Traitement de l'URI: $uri")
            lastProcessedUri = uri.toString()

            val filePath = copyUriToAppCache(uri)
            if (filePath != null) {
                println("Fichier copié vers: $filePath")

                methodChannel?.let { channel ->
                    println("Envoi vers Flutter via MethodChannel")
                    channel.invokeMethod("onFileReceived", mapOf("filePath" to filePath))
                    isFileProcessedAndSent = true
                } ?: run {
                    println("Flutter pas encore prêt, stockage en pending")
                    pendingFilePath = filePath
                }
            } else {
                println("Erreur: impossible de copier le fichier")
            }
        } catch (e: Exception) {
            println("Erreur lors du traitement de l'URI: ${e.message}")
            e.printStackTrace()
        }
    }

    // 🔄 Nouvelle version : copie dans app_cache (dans cacheDir)
    private fun copyUriToAppCache(uri: Uri): String? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val fileName = getFileName(uri) ?: "imported_file_${System.currentTimeMillis()}"
                println("Nom du fichier détecté: $fileName")

                // ✅ Utiliser /data/user/0/org.noam.jwlife/app_cache/
                val appCacheDir = File(cacheDir.parentFile, "app_cache")
                if (!appCacheDir.exists()) appCacheDir.mkdirs()

                val cacheFile = File(appCacheDir, fileName)
                val outputStream = FileOutputStream(cacheFile)

                val bytesTransferred = inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()

                println("Fichier copié dans app_cache: ${cacheFile.absolutePath} ($bytesTransferred bytes)")
                cacheFile.absolutePath
            } else {
                println("Erreur: InputStream null")
                null
            }
        } catch (e: Exception) {
            println("Erreur copyUriToAppCache: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    private fun getFileName(uri: Uri): String? {
        println("getFileName pour URI: $uri (scheme: ${uri.scheme})")

        return when (uri.scheme) {
            "file" -> {
                val fileName = File(uri.path ?: "").name
                println("Fichier local détecté: $fileName")
                fileName
            }
            "content" -> {
                val cursor = contentResolver.query(uri, null, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val columnNames = arrayOf("_display_name", "_data", "title")
                        var fileName: String? = null

                        for (columnName in columnNames) {
                            val columnIndex = it.getColumnIndex(columnName)
                            if (columnIndex != -1) {
                                val value = it.getString(columnIndex)
                                if (!value.isNullOrEmpty()) {
                                    fileName = if (columnName == "_data") {
                                        File(value).name
                                    } else {
                                        value
                                    }
                                    break
                                }
                            }
                        }

                        println("Nom de fichier depuis content resolver: $fileName")
                        fileName
                    } else {
                        println("Cursor vide")
                        null
                    }
                }
            }
            else -> {
                println("Scheme non supporté: ${uri.scheme}")
                null
            }
        }
    }
}
