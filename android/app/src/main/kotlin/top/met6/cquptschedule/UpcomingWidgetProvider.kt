package top.met6.cquptschedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.*
import org.json.JSONObject

class UpcomingWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming)

            try {
                // 1. 获取 Flutter 传过来的 JSON
                val jsonString = widgetData.getString("full_schedule_json", null)
                if (jsonString != null) {
                    val jsonObj = JSONObject(jsonString)
                    val instances = jsonObj.getJSONArray("instances")
                    val week1MondayStr = jsonObj.getString("week_1_monday")

                    // 2. 时间计算逻辑
                    val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                    val firstMonday = format.parse(week1MondayStr.substring(0, 10))
                    val cal = Calendar.getInstance()
                    val nowMillis = cal.timeInMillis

                    // 计算当前周和天
                    val diffDays =
                            ((nowMillis - (firstMonday?.time ?: 0)) / (1000 * 60 * 60 * 24)).toInt()
                    val currentWeek = (diffDays / 7) + 1
                    var currentDay = cal.get(Calendar.DAY_OF_WEEK) - 1
                    if (currentDay == 0) currentDay = 7

                    val currentMinutes =
                            cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

                    // 格式化今日日期
                    val displayFormat = SimpleDateFormat("MM/dd", Locale.getDefault())
                    val dayNames = arrayOf("", "一", "二", "三", "四", "五", "六", "日")
                    views.setTextViewText(
                            R.id.tv_date,
                            "${displayFormat.format(cal.time)} 星期${dayNames[currentDay]}"
                    )
                    views.setTextViewText(R.id.tv_week, "第 $currentWeek 周")

                    // 3. 过滤并排序课程
                    val validCourses = mutableListOf<JSONObject>()
                    for (i in 0 until instances.length()) {
                        val course = instances.getJSONObject(i)
                        val week = course.getInt("week")
                        val day = course.getInt("day")
                        val endTime = course.getString("end_time")

                        if (week == currentWeek &&
                                        day == currentDay &&
                                        timeToMin(endTime) > currentMinutes
                        ) {
                            validCourses.add(course)
                        }
                    }

                    val tomorrowDay = if (currentDay == 7) 1 else currentDay + 1
                    val tomorrowWeek = if (currentDay == 7) currentWeek + 1 else currentWeek
                    for (i in 0 until instances.length()) {
                        val course = instances.getJSONObject(i)
                        if (course.getInt("week") == tomorrowWeek &&
                                        course.getInt("day") == tomorrowDay
                        ) {
                            validCourses.add(course)
                        }
                    }

                    validCourses.sortBy { timeToMin(it.getString("start_time")) }

                    // 4. 绑定数据到 UI
                    if (validCourses.isNotEmpty()) {
                        val current = validCourses[0]
                        views.setTextViewText(R.id.tv_current_name, current.getString("course"))
                        views.setTextViewText(
                                R.id.tv_current_loc,
                                "${current.getString("location")} ${current.optString("teacher", "")}"
                        )
                        views.setTextViewText(
                                R.id.tv_current_time,
                                "${current.getString("start_time")} - ${current.getString("end_time")}"
                        )

                        if (validCourses.size > 1) {
                            val next = validCourses[1]
                            views.setTextViewText(R.id.tv_next_name, next.getString("course"))
                            views.setTextViewText(
                                    R.id.tv_next_loc,
                                    "${next.getString("location")} ${next.optString("teacher", "")}"
                            )
                            views.setTextViewText(
                                    R.id.tv_next_time,
                                    "${next.getString("start_time")} - ${next.getString("end_time")}"
                            )
                        }
                    }

                    // 5. 尺寸感知逻辑
                    val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                    val isSmall = minWidth < 200

                    views.setViewVisibility(
                            R.id.layout_next_course,
                            if (isSmall) android.view.View.GONE else android.view.View.VISIBLE
                    )
                    views.setViewVisibility(
                            R.id.divider_line,
                            if (isSmall) android.view.View.GONE else android.view.View.VISIBLE
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            newOptions: Bundle
    ) {
        // 使用 HomeWidgetPlugin.getData 获取数据，确保与 Flutter 端同步
        val widgetData = HomeWidgetPlugin.getData(context)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun timeToMin(time: String): Int {
        val parts = time.split(":")
        if (parts.size != 2) return 0
        return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
    }
}
