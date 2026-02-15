package com.ssseregi.pet_widget_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class PetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("petwidget://yard")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                val petValue = widgetData.getString("pet_emoji", null)
                val petMessage = widgetData.getString("pet_message", null)

                if (petMessage != null && petMessage.isNotEmpty()) {
                    setViewVisibility(R.id.message_bubble_layout, android.view.View.VISIBLE)
                    setTextViewText(R.id.widget_message_text, petMessage)
                } else {
                    setViewVisibility(R.id.message_bubble_layout, android.view.View.GONE)
                }

                val cleanPetValue = petValue?.split("/")?.lastOrNull() ?: petValue

                val imageResId = when (cleanPetValue) {
                    "cat" -> R.drawable.cat
                    "dog_1" -> R.drawable.dog_1
                    "dog_4" -> R.drawable.dog_4
                    "frog" -> R.drawable.frog
                    "hamster" -> R.drawable.hamster
                    "horse_1" -> R.drawable.horse_1
                    "parrot_1" -> R.drawable.parrot_1
                    "parrot_2" -> R.drawable.parrot_2
                    "rabbit" -> R.drawable.rabbit
                    "rhino" -> R.drawable.rhino
                    else -> 0
                }

                if (imageResId != 0) {
                    // 이미지를 보여주고 텍스트를 숨깁니다.
                    setViewVisibility(R.id.widget_pet_image, android.view.View.VISIBLE)
                    setImageViewResource(R.id.widget_pet_image, imageResId)
                    setViewVisibility(R.id.widget_emoji_text, android.view.View.GONE)
                } else if (!petValue.isNullOrEmpty()) {
                    // 이미지가 없을 경우 텍스트(이모지)를 보여줍니다.
                    setViewVisibility(R.id.widget_pet_image, android.view.View.GONE)
                    setViewVisibility(R.id.widget_emoji_text, android.view.View.VISIBLE)
                    setTextViewText(R.id.widget_emoji_text, petValue)
                } else {
                    // 펫 정보가 없을 경우 모두 숨깁니다.
                    setViewVisibility(R.id.widget_pet_image, android.view.View.GONE)
                    setViewVisibility(R.id.widget_emoji_text, android.view.View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
