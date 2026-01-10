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
                
                val petValue = widgetData.getString("pet_emoji", null)
                
                val imageResId = when (petValue) {
                    "cat" -> R.drawable.cat
                    "hamster" -> R.drawable.hamster
                    "rabbit" -> R.drawable.rabbit
                    "frog" -> R.drawable.frog
                    else -> 0
                }

                if (imageResId != 0) {
                    // 이미지를 보여주고 텍스트를 숨깁니다.
                    setViewVisibility(R.id.widget_emoji_text, android.view.View.GONE)
                    setViewVisibility(R.id.widget_pet_image, android.view.View.VISIBLE)
                    setImageViewResource(R.id.widget_pet_image, imageResId)
                } else {
                    // 텍스트를 보여주고 이미지를 숨깁니다.
                    setViewVisibility(R.id.widget_emoji_text, android.view.View.VISIBLE)
                    setViewVisibility(R.id.widget_pet_image, android.view.View.GONE)
                    setTextViewText(R.id.widget_emoji_text, petValue ?: "❓")
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}