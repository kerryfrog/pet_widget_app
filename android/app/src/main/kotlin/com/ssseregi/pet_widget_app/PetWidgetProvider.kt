package com.ssseregi.pet_widget_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                // 1. Flutter에서 보낸 'pet_emoji' 글자를 가져옵니다. (없으면 기본값 🐣)
                val petEmoji = widgetData.getString("pet_emoji", "🐣")
                
                // 2. 위젯의 TextView(widget_emoji_text)에 이 글자를 넣습니다.
                setTextViewText(R.id.widget_emoji_text, petEmoji)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}