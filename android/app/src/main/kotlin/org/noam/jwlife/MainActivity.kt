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

// Cette classe étend AudioServiceActivity mais ajoute la gestion des fichiers
class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "org.noam.jwlife.filehandler"
    private var pendingFilePath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingFile" -> {
                    val resultMap = if (pendingFilePath != null) {
                        // Vérifier si c'est une URL ou un chemin de fichier
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ========== OPTIMISATIONS CLAVIER MIUI/HyperOS ==========

        // 1. Forcer le mode adjustPan pour éviter les reconstructions
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN or
                    WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN
        )

        // 2. Forcer l'accélération matérielle
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )

        // 3. Désactiver les animations de transition du clavier (spécifique MIUI)
        try {
            window.attributes = window.attributes.apply {
                // Réduire la durée des animations de la fenêtre
                windowAnimations = android.R.style.Animation
            }
        } catch (e: Exception) {
            println("Impossible de modifier les animations: ${e.message}")
        }

        // ========== FIN OPTIMISATIONS ==========

        println("=== MainActivity onCreate ===")
        handleIncomingFile(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        println("=== MainActivity onNewIntent ===")
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
                    // Vérifier si c'est un lien web JW.org
                    if (isJwOrgUrl(uri)) {
                        handleJwOrgUrl(uri)
                    } else {
                        // C'est un fichier local
                        processUri(uri)
                    }
                }
            }
            Intent.ACTION_SEND -> {
                // Gérer les deux cas : texte partagé et fichier partagé
                when (intent.type) {
                    "text/plain" -> {
                        // Lien ou texte partagé
                        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                        println("ACTION_SEND avec texte: $sharedText")
                        if (!sharedText.isNullOrEmpty()) {
                            handleSharedText(sharedText)
                        }
                    }
                    else -> {
                        // Fichier partagé
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
            // Vérifier si c'est une URL
            if (sharedText.startsWith("http://") || sharedText.startsWith("https://")) {
                val uri = Uri.parse(sharedText)

                // Vérifier si c'est un lien JW.org
                if (isJwOrgUrl(uri)) {
                    handleJwOrgUrl(uri)
                } else {
                    // Autre lien web
                    handleGenericUrl(uri)
                }
            } else {
                // Texte simple (pas une URL)
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
            // Envoyer l'URL générique à Flutter
            methodChannel?.let { channel ->
                println("Envoi de l'URL générique vers Flutter")
                channel.invokeMethod("onUrlReceived", mapOf("url" to uri.toString()))
            } ?: run {
                println("Flutter pas encore prêt, stockage de l'URL en pending")
                pendingFilePath = uri.toString()
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
            // Envoyer le texte à Flutter
            methodChannel?.let { channel ->
                println("Envoi du texte vers Flutter")
                channel.invokeMethod("onTextReceived", mapOf("text" to text))
            } ?: run {
                println("Flutter pas encore prêt, stockage du texte en pending")
                pendingFilePath = text // Réutiliser ce champ pour le texte
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
            // Envoyer l'URL à Flutter
            methodChannel?.let { channel ->
                println("Envoi de l'URL vers Flutter")
                channel.invokeMethod("onUrlReceived", mapOf("url" to uri.toString()))
            } ?: run {
                println("Flutter pas encore prêt, stockage de l'URL en pending")
                pendingFilePath = uri.toString() // On réutilise ce champ pour l'URL
            }
        } catch (e: Exception) {
            println("Erreur lors du traitement de l'URL JW.org: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun processUri(uri: Uri) {
        try {
            println("Traitement de l'URI: $uri")
            val filePath = copyUriToInternalStorage(uri)
            if (filePath != null) {
                println("Fichier copié vers: $filePath")

                methodChannel?.let { channel ->
                    println("Envoi vers Flutter via MethodChannel")
                    channel.invokeMethod("onFileReceived", mapOf("filePath" to filePath))
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

    private fun copyUriToInternalStorage(uri: Uri): String? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val fileName = getFileName(uri) ?: "imported_file_${System.currentTimeMillis()}"
                println("Nom du fichier détecté: $fileName")

                val internalFile = File(filesDir, fileName)
                val outputStream = FileOutputStream(internalFile)

                val bytesTransferred = inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()

                println("Fichier copié: ${internalFile.absolutePath} ($bytesTransferred bytes)")
                internalFile.absolutePath
            } else {
                println("Erreur: InputStream null")
                null
            }
        } catch (e: Exception) {
            println("Erreur copyUriToInternalStorage: ${e.message}")
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
                        // Essayer plusieurs colonnes possibles
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