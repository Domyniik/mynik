import SwiftUI
import WidgetKit

@main
struct MynikWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MonthBalanceWidget()
        UpcomingBillsWidget()
        BillDueLiveActivity()
    }
}
