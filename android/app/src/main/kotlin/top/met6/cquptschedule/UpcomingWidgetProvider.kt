package top.met6.cquptschedule

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider

class UpcomingWidget : GlanceAppWidget() {

    private val colorYellow = ColorProvider(Color(0xFFFFD60A))
    private val colorOrange = ColorProvider(Color(0xFFFF9F0A))
    private val colorSecondary = ColorProvider(Color(0xFF8E8E93))

    override val sizeMode =
            SizeMode.Responsive(setOf(DpSize(140.dp, 80.dp), DpSize(280.dp, 80.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = prefs.getString("full_schedule_json", null)
        val scheduleData = ScheduleDataProcessor.process(jsonString)

        provideContent { GlanceTheme { WidgetContent(scheduleData, LocalSize.current) } }
    }

    @Composable
    private fun WidgetContent(data: ScheduleInfo?, size: DpSize) {
        val isSmall = size.width < 220.dp

        Column(
                modifier =
                        GlanceModifier.fillMaxWidth()
                                .wrapContentHeight()
                                .padding(horizontal = 6.dp, vertical = 4.dp)
                                .background(GlanceTheme.colors.surface)
                                .cornerRadius(16.dp)
                                .padding(8.dp)
        ) {
            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                Text(
                        data?.dateStr ?: "--/--",
                        style = TextStyle(fontSize = 13.sp, color = GlanceTheme.colors.onSurface)
                )
                Spacer(modifier = GlanceModifier.defaultWeight())
                if (!isSmall) {
                    Text(
                            data?.weekStr ?: "",
                            style =
                                    TextStyle(
                                            fontSize = 13.sp,
                                            color = GlanceTheme.colors.onSurface
                                    )
                    )
                }
            }

            Spacer(modifier = GlanceModifier.height(2.dp))

            if (data == null) {
                Text(
                        "暂无课程数据",
                        style = TextStyle(fontSize = 14.sp, color = GlanceTheme.colors.onSurface)
                )
            } else {
                if (isSmall) SmallLayout(data) else MediumLayout(data)
            }
        }
    }

    @Composable
    private fun MediumLayout(data: ScheduleInfo) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Text("当前", style = TextStyle(fontSize = 13.sp, color = colorSecondary))
                CourseBlockView(data.currentCourse, colorYellow)
            }

            Column(modifier = GlanceModifier.defaultWeight()) {
                Text("接下来", style = TextStyle(fontSize = 13.sp, color = colorSecondary))
                CourseBlockView(data.nextCourse, colorOrange)
            }
        }
    }

    @Composable
    private fun SmallLayout(data: ScheduleInfo) {
        Column(modifier = GlanceModifier.fillMaxWidth()) {
            if (data.currentCourse != null) {
                CourseBlockView(data.currentCourse, colorYellow)
                if (data.nextCourse != null) {
                    Row(
                            modifier = GlanceModifier.padding(top = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(modifier = GlanceModifier.size(3.dp, 20.dp).background(colorOrange)) {
                            Spacer(modifier = GlanceModifier.fillMaxSize())
                        }
                        Text(
                                data.nextCourse.name,
                                style =
                                        TextStyle(
                                                fontSize = 16.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = GlanceTheme.colors.onSurface
                                        ),
                                maxLines = 1,
                                modifier = GlanceModifier.padding(start = 6.dp)
                        )
                    }
                }
            } else {
                Text("今日已无课程", style = TextStyle(fontSize = 14.sp, color = colorSecondary))
            }
        }
    }

    @Composable
    private fun CourseBlockView(course: Course?, barColor: ColorProvider) {
        Row(modifier = GlanceModifier.padding(vertical = 4.dp)) {
            // 使用 barColor 传入的 ColorProvider
            Box(modifier = GlanceModifier.width(4.dp).height(60.dp).background(barColor)) {
                Spacer(modifier = GlanceModifier.fillMaxSize())
            }
            Column(modifier = GlanceModifier.padding(start = 8.dp)) {
                if (course == null) {
                    Text("无", style = TextStyle(fontSize = 14.sp, color = colorSecondary))
                } else {
                    Text(
                            course.name,
                            style =
                                    TextStyle(
                                            fontSize = 16.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = GlanceTheme.colors.onSurface
                                    ),
                            maxLines = 1
                    )
                    Text(
                            "${course.location}  ${course.teacher ?: "未知"}",
                            style =
                                    TextStyle(
                                            fontSize = 13.sp,
                                            color = GlanceTheme.colors.onSurface
                                    ),
                            maxLines = 1
                    )
                    Text(
                            "${course.startTime} - ${course.endTime}",
                            style =
                                    TextStyle(
                                            fontSize = 13.sp,
                                            color = GlanceTheme.colors.onSurface
                                    )
                    )
                }
            }
        }
    }
}
