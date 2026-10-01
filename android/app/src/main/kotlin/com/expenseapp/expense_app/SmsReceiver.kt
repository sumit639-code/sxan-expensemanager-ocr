package com.expenseapp.expense_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            try {
                // Check if background SMS detection is enabled by the user in Settings
                val configPrefs = context.getSharedPreferences("scanex_sms_config", Context.MODE_PRIVATE)
                val isDetectionEnabled = configPrefs.getBoolean("is_sms_detection_enabled", true)
                if (!isDetectionEnabled) {
                    Log.d(TAG, "Bank SMS auto-detection is disabled in Settings; ignoring broadcast.")
                    return
                }

                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages.isNullOrEmpty()) return

                // Group multi-part SMS by originating address
                val messagesBySender = HashMap<String, StringBuilder>()
                var latestTimestamp = System.currentTimeMillis()

                for (msg in messages) {
                    val address = msg.displayOriginatingAddress ?: msg.originatingAddress ?: "Unknown"
                    val body = msg.displayMessageBody ?: msg.messageBody ?: ""
                    latestTimestamp = msg.timestampMillis

                    val builder = messagesBySender.getOrPut(address) { StringBuilder() }
                    builder.append(body)
                }

                for ((sender, bodyBuilder) in messagesBySender) {
                    val fullBody = bodyBuilder.toString()
                    Log.d(TAG, "SMS received from: $sender (length: ${fullBody.length})")
                    MainActivity.handleIncomingSms(context, sender, fullBody, latestTimestamp)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing incoming SMS: ${e.message}", e)
            }
        }
    }
}
