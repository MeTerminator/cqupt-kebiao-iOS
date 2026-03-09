package top.met6.cquptschedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.os.Bundle
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

                    // 2. 时间计算逻辑 (完美复刻你的 Swift 逻辑)
                    val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                    val firstMonday = format.parse(week1MondayStr.substring(0, 10))
                    val cal = Calendar.getInstance()
                    val nowMillis = cal.timeInMillis

                    // 计算当前周和天
                    val diffDays = ((nowMillis - firstMonday.time) / (1000 * 60 * 60 * 24)).toInt()
                    val currentWeek = (diffDays / 7) + 1
                    var currentDay = cal.get(Calendar.DAY_OF_WEEK) - 1
                    if (currentDay == 0) currentDay = 7 // 星期天修正为7

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

                    // 提取今天的有效课程
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

                    // 提取明天的课程 (如果今天没课了，就显示明天的)
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

                    // 按开始时间排序
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

                    val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)

                    // 设置一个阈值，例如 200dp，小于该宽度则隐藏下一节课
                    val isSmall = minWidth < 200

                    if (isSmall) {
                        // 隐藏下一节课的整体容器 (你需要给右侧容器一个 ID)
                        views.setViewVisibility(R.id.layout_next_course, android.view.View.GONE)
                        // 隐藏分隔线
                        views.setViewVisibility(R.id.divider_line, android.view.View.GONE)
                    } else {
                        views.setViewVisibility(R.id.layout_next_course, android.view.View.VISIBLE)
                        views.setViewVisibility(R.id.divider_line, android.view.View.VISIBLE)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                // 解析失败或无数据的默认状态已在 XML 中定义
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
        // 当尺寸改变时，立即调用 onUpdate 重新绘制
        val widgetData = context.getSharedPreferences("你的存储名称", Context.MODE_PRIVATE)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun timeToMin(time: String): Int {
        val parts = time.split(":")
        if (parts.size != 2) return 0
        return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
    }
}
