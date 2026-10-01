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
        private const val SMS_CHANNEL = "com.expenseapp.expense_app/sms"
        private const val NOTIFICATION_CHANNEL_ID = "pending_imports"
        private const val NOTIFICATION_PERMISSION_REQ_CODE = 101
        private const val SMS_PERMISSION_REQ_CODE = 102

        @Volatile
        private var instance: MainActivity? = null

        private fun isLikelyBankTransaction(body: String): Boolean {
            val lower = body.lowercase()
            val hasAction = lower.contains("debited") || lower.contains("credited") ||
                lower.contains("spent") || lower.contains("paid") ||
                lower.contains("sent") || lower.contains("withdrawn") ||
                lower.contains("transferred") || lower.contains("purchase") ||
                lower.contains("received") || lower.contains("deposited") ||
                lower.contains("refund") || lower.contains("cashback") ||
                lower.contains("deducted") || lower.contains("charged")
            val hasAmount = lower.contains("rs") || lower.contains("inr") ||
                lower.contains("₹") || lower.contains("usd") || lower.contains("eur")
            val isOtp = lower.contains("otp") || lower.contains("verification code") ||
                lower.contains("secret code") || lower.contains("one time password") ||
                lower.contains("do not share")

            return hasAction && hasAmount && !isOtp
        }

        private fun triggerBackgroundNotification(context: Context, title: String, body: String) {
            try {
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "VIEW_PENDING_IMPORT"
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("pending_import_id", "inbox")
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    1003,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setDefaults(NotificationCompat.DEFAULT_ALL)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)

                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                ) {
                    NotificationManagerCompat.from(context).notify(1003, builder.build())
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun handleIncomingSms(context: Context, sender: String, body: String, timestamp: Long) {
            val current = instance
            if (current != null && current.isFlutterReady) {
                current.mainHandler.post {
                    val map = hashMapOf<String, Any>(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to timestamp
                    )
                    current.smsMethodChannel?.invokeMethod("onSmsReceived", map)
                }
            } else {
                try {
                    val prefs = context.getSharedPreferences("scanex_pending_sms", Context.MODE_PRIVATE)
                    val existing = prefs.getStringSet("pending_sms_json", mutableSetOf()) ?: mutableSetOf()
                    val newSet = HashSet(existing)
                    val itemJson = org.json.JSONObject().apply {
                        put("sender", sender)
                        put("body", body)
                        put("timestamp", timestamp)
                    }.toString()
                    newSet.add(itemJson)
                    prefs.edit().putStringSet("pending_sms_json", newSet).apply()

                    if (isLikelyBankTransaction(body)) {
                        triggerBackgroundNotification(
                            context,
                            "Bank Transaction Detected",
                            "New alert from $sender. Tap to review in SXAN Inbox."
                        )
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    private val ioExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var isCopyingSharedImages = false
    private var pendingInitialResult: MethodChannel.Result? = null

    private var shareMethodChannel: MethodChannel? = null
    private var notificationMethodChannel: MethodChannel? = null
    private var smsMethodChannel: MethodChannel? = null

    private var pendingSharedPaths: ArrayList<String>? = null
    private var launchNotificationPayload: String? = null

    private var isFlutterReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        createNotificationChannel()
        handleIncomingIntent(intent, isFromNewIntent = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, isFromNewIntent = true)
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
        }
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

        // Setup SMS Channel
        smsMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkSmsPermission" -> {
                        val hasRead = ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                        val hasReceive = ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                        result.success(hasRead && hasReceive)
                    }
                    "requestSmsPermission" -> {
                        requestSmsPermissions()
                        result.success(true)
                    }
                    "getRecentSms" -> {
                        val limit = call.argument<Int>("limit") ?: 500
                        ioExecutor.execute {
                            val smsList = fetchRecentSms(limit)
                            mainHandler.post {
                                result.success(smsList)
                            }
                        }
                    }
                    "getPendingSmsFromBackground" -> {
                        val list = popPendingSmsFromBackground()
                        result.success(list)
                    }
                    "setSmsDetectionEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        val prefs = getSharedPreferences("scanex_sms_config", Context.MODE_PRIVATE)
                        prefs.edit().putBoolean("is_sms_detection_enabled", enabled).apply()
                        result.success(true)
                    }
                    "isSmsDetectionEnabled" -> {
                        val prefs = getSharedPreferences("scanex_sms_config", Context.MODE_PRIVATE)
                        result.success(prefs.getBoolean("is_sms_detection_enabled", true))
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            val intent = Intent().apply {
                                action = android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent().apply {
                                    action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                    data = Uri.fromParts("package", packageName, null)
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
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
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
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

    private fun requestSmsPermissions() {
        val permissions = arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS)
        requestPermissions(permissions, SMS_PERMISSION_REQ_CODE)
    }

    private fun fetchRecentSms(limit: Int): ArrayList<HashMap<String, Any>> {
        val results = ArrayList<HashMap<String, Any>>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            return results
        }
        try {
            val uri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("_id", "address", "body", "date")
            val sortOrder = if (limit > 0) "date DESC LIMIT $limit" else "date DESC LIMIT 2500"
            val cursor = contentResolver.query(uri, projection, null, null, sortOrder)
            cursor?.use {
                val idIndex = it.getColumnIndexOrThrow("_id")
                val addressIndex = it.getColumnIndexOrThrow("address")
                val bodyIndex = it.getColumnIndexOrThrow("body")
                val dateIndex = it.getColumnIndexOrThrow("date")

                while (it.moveToNext()) {
                    val map = HashMap<String, Any>()
                    map["id"] = it.getString(idIndex) ?: ""
                    map["address"] = it.getString(addressIndex) ?: ""
                    map["body"] = it.getString(bodyIndex) ?: ""
                    map["date"] = it.getLong(dateIndex)
                    results.add(map)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error fetching recent SMS: ${e.message}", e)
        }
        return results
    }

    private fun popPendingSmsFromBackground(): ArrayList<HashMap<String, Any>> {
        val results = ArrayList<HashMap<String, Any>>()
        try {
            val prefs = getSharedPreferences("scanex_pending_sms", Context.MODE_PRIVATE)
            val stored = prefs.getStringSet("pending_sms_json", null)
            if (!stored.isNullOrEmpty()) {
                for (itemStr in stored) {
                    val json = org.json.JSONObject(itemStr)
                    val map = HashMap<String, Any>()
                    map["sender"] = json.optString("sender", "")
                    map["body"] = json.optString("body", "")
                    map["timestamp"] = json.optLong("timestamp", System.currentTimeMillis())
                    results.add(map)
                }
                prefs.edit().remove("pending_sms_json").apply()
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error popping pending background SMS: ${e.message}", e)
        }
        return results
    }
}
