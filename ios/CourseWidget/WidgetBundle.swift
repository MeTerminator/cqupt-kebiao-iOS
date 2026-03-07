import WidgetKit
import SwiftUI

@main
struct CquptScheduleWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpcomingCourseWidget()
        TodayCourseWidget()
    }
}
