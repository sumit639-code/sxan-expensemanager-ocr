package com.expenseapp.expense_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.webkit.MimeTypeMap
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHARE_CHANNEL = "com.expenseapp.expense_app/share_target"
        private const val NOTIFICATION_CHANNEL = "com.expenseapp.expense_app/notifications"
        private const val NOTIFICATION_CHANNEL_ID = "pending_imports"
        private const val NOTIFICATION_PERMISSION_REQ_CODE = 101
    }

    private val ioExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var isCopyingSharedImages = false
    private var pendingInitialResult: MethodChannel.Result? = null

    private var shareMethodChannel: MethodChannel? = null
    private var notificationMethodChannel: MethodChannel? = null

    private var pendingSharedPaths: ArrayList<String>? = null
    private var launchNotificationPayload: String? = null

    private var isFlutterReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        handleIncomingIntent(intent, isFromNewIntent = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, isFromNewIntent = true)
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup Share Target Channel
        shareMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedImages" -> {
                        isFlutterReady = true
                        if (isCopyingSharedImages) {
                            pendingInitialResult = result
                        } else {
                            val paths = pendingSharedPaths?.let { ArrayList(it) }
                            pendingSharedPaths = null
                            result.success(paths)
                        }
                    }
                    "clearInitialSharedImages" -> {
                        pendingSharedPaths = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Setup Notification Channel
        notificationMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> {
                        val id = call.argument<Int>("id") ?: 1001
                        val title = call.argument<String>("title") ?: "Expense Import Ready"
                        val body = call.argument<String>("body") ?: "Review your pending transaction"
                        val payload = call.argument<String>("payload")

                        val shown = triggerLocalNotification(id, title, body, payload)
                        result.success(shown)
                    }
                    "getLaunchPayload" -> {
                        val payload = launchNotificationPayload
                        result.success(payload)
                    }
                    "clearLaunchPayload" -> {
                        launchNotificationPayload = null
                        result.success(true)
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermissionIfNeeded()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // If there was a launch payload from tapping notification, notify engine
        launchNotificationPayload?.let { payload ->
            notificationMethodChannel?.invokeMethod("onNotificationTapped", payload)
        }
    }

    private fun handleIncomingIntent(incomingIntent: Intent?, isFromNewIntent: Boolean) {
        if (incomingIntent == null) return

        // 1. Check if launched or resumed from Notification tap
        if (incomingIntent.hasExtra("pending_import_id")) {
            val payload = incomingIntent.getStringExtra("pending_import_id")
            if (!payload.isNullOrEmpty()) {
                launchNotificationPayload = payload
                notificationMethodChannel?.invokeMethod("onNotificationTapped", payload)
            }
        }

        // 2. Check for Share Intents
        val action = incomingIntent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return
        }

        val urisToProcess = ArrayList<Uri>()

        // 2a. Check clipData first (modern Android galleries place all multi-selected images here)
        try {
            val clipData = incomingIntent.clipData
            if (clipData != null) {
                for (i in 0 until clipData.itemCount) {
                    val item = clipData.getItemAt(i)
                    val uri = item?.uri
                    if (uri != null && !urisToProcess.contains(uri)) {
                        urisToProcess.add(uri)
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error reading clipData: ${e.message}", e)
        }

        // 2b. Safely extract EXTRA_STREAM without unsafe casting (handles Uri, List<Uri>, List<String>, Array<*>, or String)
        try {
            val rawExtra = incomingIntent.extras?.get(Intent.EXTRA_STREAM)
            when (rawExtra) {
                is Uri -> {
                    if (!urisToProcess.contains(rawExtra)) {
                        urisToProcess.add(rawExtra)
                    }
                }
                is Iterable<*> -> {
                    for (item in rawExtra) {
                        when (item) {
                            is Uri -> if (!urisToProcess.contains(item)) urisToProcess.add(item)
                            is CharSequence -> {
                                val u = try { Uri.parse(item.toString()) } catch (e: Exception) { null }
                                if (u != null && !urisToProcess.contains(u)) urisToProcess.add(u)
                            }
                        }
                    }
                }
                is Array<*> -> {
                    for (item in rawExtra) {
                        when (item) {
                            is Uri -> if (!urisToProcess.contains(item)) urisToProcess.add(item)
                            is CharSequence -> {
                                val u = try { Uri.parse(item.toString()) } catch (e: Exception) { null }
                                if (u != null && !urisToProcess.contains(u)) urisToProcess.add(u)
                            }
                        }
                    }
                }
                is CharSequence -> {
                    val u = try { Uri.parse(rawExtra.toString()) } catch (e: Exception) { null }
                    if (u != null && !urisToProcess.contains(u)) urisToProcess.add(u)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error reading EXTRA_STREAM: ${e.message}", e)
        }

        // 2c. Check intent data URI
        try {
            val dataUri = incomingIntent.data
            if (dataUri != null && !urisToProcess.contains(dataUri)) {
                urisToProcess.add(dataUri)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error reading intent data: ${e.message}", e)
        }

        if (urisToProcess.isNotEmpty()) {
            isCopyingSharedImages = true
            ioExecutor.execute {
                val copiedPaths = ArrayList<String>()
                for ((index, uri) in urisToProcess.withIndex()) {
                    val path = copyUriToInternalCache(uri, index)
                    if (path != null) {
                        copiedPaths.add(path)
                    }
                }
                mainHandler.post {
                    isCopyingSharedImages = false
                    if (copiedPaths.isNotEmpty()) {
                        if (pendingInitialResult != null) {
                            // Cold start: Flutter called getInitialSharedImages while copying was active
                            pendingInitialResult?.success(copiedPaths)
                            pendingInitialResult = null
                            pendingSharedPaths = null
                        } else if (!isFlutterReady && !isFromNewIntent) {
                            // Cold start: Copy completed before Flutter called getInitialSharedImages.
                            // Store in pendingSharedPaths so Flutter's initial call consumes it once.
                            pendingSharedPaths = ArrayList(copiedPaths)
                        } else {
                            // Runtime / warm intent: Flutter engine is already running, dispatch via method channel
                            pendingSharedPaths = null
                            shareMethodChannel?.invokeMethod("onSharedImagesReceived", copiedPaths)
                        }
                    } else {
                        pendingInitialResult?.success(null)
                        pendingInitialResult = null
                    }
                }
            }
        }
    }

    private fun copyUriToInternalCache(uri: Uri, index: Int = 0): String? {
        return try {
            val contentResolver = applicationContext.contentResolver
            val mimeType = contentResolver.getType(uri) ?: "image/jpeg"
            val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: "jpg"

            val shareDir = File(applicationContext.cacheDir, "shared_images").apply {
                if (!exists()) mkdirs()
            }

            val outputFile = File(shareDir, "shared_${System.currentTimeMillis()}_${index}_${UUID.randomUUID()}.$extension")
            val inputStream: InputStream? = if (uri.scheme == "file") {
                val filePath = uri.path
                if (filePath != null && File(filePath).canRead()) {
                    File(filePath).inputStream()
                } else {
                    contentResolver.openInputStream(uri)
                }
            } else {
                contentResolver.openInputStream(uri)
            }

            inputStream?.use { input ->
                FileOutputStream(outputFile).use { outputStream ->
                    input.copyTo(outputStream)
                }
            }

            outputFile.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to copy shared uri $uri at index $index: ${e.message}", e)
            null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Expense Imports"
            val descriptionText = "Notifications when shared payment screenshots are processed"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                setShowBadge(true)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun triggerLocalNotification(id: Int, title: String, body: String, payload: String?): Boolean {
        return try {
            val intent = Intent(this, MainActivity::class.java).apply {
                action = "VIEW_PENDING_IMPORT"
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("pending_import_id", payload)
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            ) {
                NotificationManagerCompat.from(this).notify(id, builder.build())
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQ_CODE)
            }
        }
    }
}
