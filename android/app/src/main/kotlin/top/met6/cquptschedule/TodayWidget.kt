package top.met6.cquptschedule

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider

class TodayWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = prefs.getString("full_schedule_json", null)
        val data = ScheduleDataProcessor.process(jsonString)

        provideContent {
            GlanceTheme {
                LazyColumn(
                        modifier =
                                GlanceModifier.fillMaxSize()
                                        .background(GlanceTheme.colors.surface)
                                        .cornerRadius(16.dp)
                                        .padding(8.dp)
                ) {
                    if (data == null || data.courses.isEmpty()) {
                        item { Text("近期无课程", modifier = GlanceModifier.padding(16.dp)) }
                    } else {
                        // 1. 今日部分
                        item {
                            HeaderView(data.todayDateStr, data.todayCourseCount, data.todayWeekInfo)
                            // 给 Header 和第一节课之间添加间隙
                            Spacer(modifier = GlanceModifier.height(8.dp))
                        }

                        items(data.todayCourseCount) { index ->
                            // 移除了原来的 if (index > 0) Spacer 判断，直接由 CourseRow 负责间隙
                            CourseRow(data.courses[index])
                        }

                        // 2. 明日部分
                        if (data.tomorrowCourseCount > 0) {
                            item {
                                Spacer(modifier = GlanceModifier.height(12.dp)) // 明日Header前的间距
                                HeaderView(
                                        data.tomorrowDateStr,
                                        data.tomorrowCourseCount,
                                        data.tomorrowWeekInfo
                                )
                                // 给 Header 和明日第一节课之间添加间隙
                                Spacer(modifier = GlanceModifier.height(8.dp))
                            }

                            items(data.tomorrowCourseCount) { index ->
                                val actualIndex = data.todayCourseCount + index
                                CourseRow(data.courses[actualIndex])
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeaderView(dateStr: String, count: Int, weekInfo: String) {
    Row(modifier = GlanceModifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp)) {
        Text(
                "$dateStr · $count 节课",
                style = TextStyle(fontSize = 12.sp, color = GlanceTheme.colors.onSurfaceVariant)
        )
        Spacer(modifier = GlanceModifier.defaultWeight())
        Text(
                weekInfo,
                style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color(0xFF007AFF)))
        )
    }
}

@Composable
private fun CourseRow(course: Course) {
    Box(modifier = GlanceModifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Row(
                modifier =
                        GlanceModifier.fillMaxWidth()
                                .background(GlanceTheme.colors.secondaryContainer)
                                .cornerRadius(10.dp)
                                .padding(horizontal = 10.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                    modifier =
                            GlanceModifier.width(4.dp)
                                    .height(34.dp)
                                    .background(ColorProvider(getColorForCourse(course.name)))
                                    .cornerRadius(2.dp),
                    content = {
                        Spacer(modifier = GlanceModifier.fillMaxSize())
                    }
            )

            Column(modifier = GlanceModifier.padding(start = 8.dp).defaultWeight()) {
                Text(
                        course.name,
                        style = TextStyle(fontSize = 14.sp, color = GlanceTheme.colors.onSurface),
                        maxLines = 1
                )
                Text(
                        "${course.location}  ${course.teacher ?: ""}",
                        style =
                                TextStyle(
                                        fontSize = 14.sp,
                                        color = GlanceTheme.colors.onSurfaceVariant
                                ),
                        maxLines = 1
                )
            }

            Column(horizontalAlignment = Alignment.End) {
                Text(
                        course.startTime,
                        style = TextStyle(fontSize = 13.sp, color = GlanceTheme.colors.onSurface)
                )
                Text(
                        course.endTime,
                        style = TextStyle(fontSize = 13.sp, color = GlanceTheme.colors.onSurface)
                )
            }
        }
    }
}

private fun getColorForCourse(name: String): Color {
    val colors =
            listOf(
                    Color(0xFFFF9500),
                    Color(0xFF007AFF),
                    Color(0xFF34C759),
                    Color(0xFFAF52DE),
                    Color(0xFFFF2D55),
                    Color(0xFFFF3B30),
                    Color(0xFF5AC8FA)
            )
    return colors[Math.abs(name.hashCode()) % colors.size]
}
