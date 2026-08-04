package com.trackr.app

import android.app.Notification
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/** Stores only visible, bank-like messaging notifications for Trackr to review. */
class TrackrNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val supportedPackages = setOf(
            "com.truecaller",
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging"
        )
        if (sbn.packageName !in supportedPackages) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val conversation = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?.toString().orEmpty()
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.joinToString(" ").orEmpty()
        val messageRows = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            ?.mapNotNull { (it as? Bundle)?.getCharSequence("text")?.toString() }
            ?.joinToString(" ").orEmpty()
        // Different Android messaging styles place sender and bank details in
        // different extras. Combine visible text only; never access chat data.
        val content = "$title $conversation $text $lines $messageRows".trim()
        if (!looksLikeBankTransaction(content)) return

        val preferences = getSharedPreferences("trackr_business_notifications", MODE_PRIVATE)
        val rows = JSONArray(preferences.getString("items", "[]") ?: "[]")
        val key = "${sbn.postTime}|${sbn.packageName}|$content"
        for (index in 0 until rows.length()) {
            if (rows.getJSONObject(index).optString("key") == key) return
        }
        rows.put(JSONObject().apply {
            put("key", key)
            put("sender", if (title.isNotBlank()) title else conversation)
            put("body", content)
            put("timestamp", sbn.postTime)
        })
        val kept = JSONArray()
        for (index in maxOf(0, rows.length() - 50) until rows.length()) kept.put(rows.get(index))
        preferences.edit().putString("items", kept.toString()).apply()
    }

    private fun looksLikeBankTransaction(value: String): Boolean {
        val lower = value.lowercase()
        val bank = listOf(
            "bank", "sbi", "sbin", "statebank", "pnb", "bankbaroda", "canara",
            "canbk", "unionbank", "indianbank", "idib", "iob", "centralbank",
            "bankindia", "hdfc", "icici", "axis", "kotak", "idfc", "idfcfb",
            "idfcfirst", "indusind", "yesbank", "federal", "rbl", "bandhan",
            "aubank", "equitas", "ujjivan", "southindian", "karnataka", "kvb",
            "cityunion", "dcbbank", "tmb", "nainital", "saraswat", "hsbc",
            "standardchartered", "deutsche", "dbs", "citi"
        )
            .any(lower::contains)
        val amount = Regex("(?:₹|inr|rs\\.?)\\s*[0-9]", RegexOption.IGNORE_CASE).containsMatchIn(value)
        val movement = listOf(
            "debited", "debit", "credited", "credit", "deducted", "deposited",
            "received", "refund", "reversed", "transfer", "transferred", "sent",
            "paid", "upi", " dr", " cr"
        )
            .any(lower::contains)
        return bank && amount && movement
    }
}
