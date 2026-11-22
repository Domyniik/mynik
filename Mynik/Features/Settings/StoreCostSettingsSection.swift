import SwiftUI

/// Custos usados no lucro real da loja.
struct StoreCostSettingsSection: View {
    @AppStorage(SettingsKey.storeFeePercent) private var feePercent = StoreCostSettings.defaultFeePercent
    @AppStorage(SettingsKey.storeFeeFixed) private var feeFixed = StoreCostSettings.defaultFeeFixed
    @AppStorage(SettingsKey.storeShippingCost) private var shippingCost = StoreCostSettings.defaultShippingCost
    @AppStorage(SettingsKey.storeMonthlyAds) private var monthlyAds = 0.0
    @AppStorage(SettingsKey.storeProfitToFinance) private var profitToFinance = true

    var body: some View {
        Section {
            amountField("Taxa de pagamento (%)", value: $feePercent, format: .number.precision(.fractionLength(0...2)).locale(.app))
            amountField("Taxa fixa por pedido", value: $feeFixed, format: .currency(code: Currency.defaultCode).locale(.app))
            amountField("Envio por pedido", value: $shippingCost, format: .currency(code: Currency.defaultCode).locale(.app))
            amountField("Outros anúncios / mês", value: $monthlyAds, format: .currency(code: Currency.defaultCode).locale(.app))
            Toggle("Lançar o lucro mensal nas Finanças", isOn: $profitToFinance)
        } header: {
            ListSectionHeader("Custos da loja", systemImage: "creditcard", color: .pink)
        } footer: {
            Text("Entram no lucro real junto com o custo de cada produto. “Outros anúncios” é o que não vem do Google Ads (Meta, TikTok...). O lucro de cada mês entra nas Finanças como receita da categoria Loja (só com a loja real ligada).")
        }

        GoogleAdsSettingsSection()
    }

    private func amountField<F: ParseableFormatStyle>(
        _ title: String,
        value: Binding<Double>,
        format: F
    ) -> some View where F.FormatInput == Double, F.FormatOutput == String {
        LabeledContent(title) {
            TextField(title, value: value, format: format)
                .multilineTextAlignment(.trailing)
                .labelsHidden()
                .keyboardType(.decimalPad)
                .frame(maxWidth: 120)
        }
    }
}
