/**
 * Mynik — exporta o gasto diário do Google Ads para uma folha do Google Sheets.
 *
 * Instalação: Google Ads → Ferramentas → Ações em massa → Scripts → "+" →
 * cola este código, troca SPREADSHEET_URL, "Autorizar" e agenda "Diariamente".
 *
 * A folha fica com uma linha por dia × campanha × URL final:
 *   date,campaign,cost,currency,final_url
 * O Mynik lê a folha (Definições → Custos da loja → Google Ads) e reparte o
 * gasto pelos produtos cujo URL final aponta para /products/<handle>.
 * Só lê dados; não altera nada na conta de anúncios.
 */

const SPREADSHEET_URL = 'COLA_AQUI_O_URL_DA_FOLHA';
const DAYS = 60; // janela reescrita em cada execução (cobre correções tardias de custos)

function main() {
  const sheet = SpreadsheetApp.openByUrl(SPREADSHEET_URL).getSheets()[0];
  const account = AdsApp.currentAccount();
  const currency = account.getCurrencyCode();
  const tz = account.getTimeZone();

  const end = new Date();
  const start = new Date(end.getTime() - (DAYS - 1) * 24 * 3600 * 1000);
  const from = Utilities.formatDate(start, tz, 'yyyy-MM-dd');
  const to = Utilities.formatDate(end, tz, 'yyyy-MM-dd');
  const range = "WHERE segments.date BETWEEN '" + from + "' AND '" + to + "' AND metrics.cost_micros > 0";

  const totals = {}; // "data|campanha|url" → custo
  const coveredByAds = {}; // "data|campanha" → custo já atribuído a anúncios
  const add = (date, campaign, url, cost) => {
    const key = [date, campaign, url].join('|');
    totals[key] = (totals[key] || 0) + cost;
  };

  // Custo por anúncio, com o URL final (para ligar aos produtos).
  const ads = AdsApp.search(
    'SELECT segments.date, campaign.name, ad_group_ad.ad.final_urls, metrics.cost_micros FROM ad_group_ad ' + range
  );
  while (ads.hasNext()) {
    const row = ads.next();
    const cost = Number(row.metrics.costMicros) / 1e6;
    const urls = row.adGroupAd.ad.finalUrls || [];
    add(row.segments.date, row.campaign.name, urls[0] || '', cost);
    const dayKey = row.segments.date + '|' + row.campaign.name;
    coveredByAds[dayKey] = (coveredByAds[dayKey] || 0) + cost;
  }

  // O resto do custo da campanha (ex.: Performance Max, Shopping) entra sem URL.
  const campaigns = AdsApp.search(
    'SELECT segments.date, campaign.name, metrics.cost_micros FROM campaign ' + range
  );
  while (campaigns.hasNext()) {
    const row = campaigns.next();
    const cost = Number(row.metrics.costMicros) / 1e6;
    const rest = cost - (coveredByAds[row.segments.date + '|' + row.campaign.name] || 0);
    if (rest > 0.005) add(row.segments.date, row.campaign.name, '', rest);
  }

  const rows = Object.keys(totals).sort().map((key) => {
    const [date, campaign, url] = key.split('|');
    return [date, campaign, Math.round(totals[key] * 100) / 100, currency, url];
  });

  sheet.clearContents();
  sheet.getRange(1, 1, 1, 5).setValues([['date', 'campaign', 'cost', 'currency', 'final_url']]);
  if (rows.length > 0) {
    sheet.getRange(2, 1, rows.length, 5).setValues(rows);
  }
  Logger.log('Mynik: ' + rows.length + ' linhas de ' + from + ' a ' + to + '.');
}
