package top.met6.cquptschedule

import java.text.SimpleDateFormat
import java.util.*
import org.json.JSONObject

// 课程实例模型
data class Course(
        val name: String,
        val location: String,
        val teacher: String?,
        val startTime: String,
        val endTime: String,
        val sortKey: Int
)

// 最终展示模型
data class ScheduleInfo(
        val dateStr: String,
        val weekStr: String,
        val currentCourse: Course?,
        val nextCourse: Course?
)

object ScheduleDataProcessor {

    fun process(jsonString: String?): ScheduleInfo? {
        if (jsonString.isNullOrBlank()) return null
        return try {
            val jsonObj = JSONObject(jsonString)
            val instances = jsonObj.getJSONArray("instances")
            val week1MondayStr = jsonObj.getString("week_1_monday")

            val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val firstMonday = format.parse(week1MondayStr.substring(0, 10))!!
            val cal = Calendar.getInstance()

            // 计算当前周
            val diffDays = ((cal.timeInMillis - firstMonday.time) / (1000 * 60 * 60 * 24)).toInt()
            val currentWeek = (diffDays / 7) + 1

            // 计算星期几
            var currentDay = cal.get(Calendar.DAY_OF_WEEK) - 1
            if (currentDay <= 0) currentDay = 7

            val dayNames = arrayOf("", "一", "二", "三", "四", "五", "六", "日")
            val dateHeader =
                    "${SimpleDateFormat("MM/dd", Locale.getDefault()).format(cal.time)} 星期${dayNames[currentDay]}"

            val currentMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            val courseList = mutableListOf<Course>()

            for (i in 0 until instances.length()) {
                val c = instances.getJSONObject(i)
                // 筛选逻辑：只保留当前周和当天的课程，或者未来的课程
                // 注意：这里为了简化，我们仅筛选今日剩余课程和明日课程
                val cWeek = c.getInt("week")
                val cDay = c.getInt("day")
                val startTimeStr = c.getString("start_time")
                val endTimeStr = c.getString("end_time")

                if (cWeek == currentWeek && cDay == currentDay) {
                    if (timeToMin(endTimeStr) > currentMinutes) {
                        courseList.add(mapToCourse(c))
                    }
                }
            }

            courseList.sortBy { it.sortKey }

            ScheduleInfo(
                    dateStr = dateHeader,
                    weekStr = "第 $currentWeek 周",
                    currentCourse = courseList.getOrNull(0),
                    nextCourse = courseList.getOrNull(1)
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun mapToCourse(c: JSONObject): Course {
        val startTime = c.getString("start_time")
        return Course(
                name = c.getString("course"),
                location = c.getString("location"),
                teacher = c.optString("teacher", "未知"),
                startTime = startTime,
                endTime = c.getString("end_time"),
                sortKey = timeToMin(startTime)
        )
    }

    private fun timeToMin(t: String): Int =
            try {
                t.split(":").let { it[0].toInt() * 60 + it[1].toInt() }
            } catch (e: Exception) {
                0
            }
}
