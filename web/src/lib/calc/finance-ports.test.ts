// Os mesmos casos dos testes Swift (CSVImportTests, CategorizationTests,
// ReceiptScannerTests): a tradução tem de dar o mesmo resultado que o iPhone.
import { describe, expect, test } from "vitest";
import { MerchantRules, merchantKey } from "./categorize";
import { duplicateKey, parseBankAmount, parseBankCSV, parseCSV } from "./csv";
import { monthlyCost, nextDueDate } from "./finance";
import { dateIn, parseReceipt, total } from "./receipt";

describe("CSV", () => {
  test("campos entre aspas e separador", () => {
    expect(parseCSV('a;"b; c";"diz ""olá"""\n1;2;3\n\n')).toEqual([["a", "b; c", 'diz "olá"'], ["1", "2", "3"]]);
  });

  test.each([
    ["1.234,56", 1234.56], ["-12,30", -12.3], ["1,234.56", 1234.56], ["-12.30", -12.3],
    ["12,30 €", 12.3], ["(5,00)", -5], ["1.000.000", 1000000], ["abc", null],
  ])("valor %s", (text, expected) => {
    expect(parseBankAmount(text)).toBe(expected);
  });

  test("extrato português com linhas de título", () => {
    const csv = [
      "Extrato de conta à ordem;;;",
      "Data movimento;Data valor;Descrição;Valor;Saldo",
      "01/11/2026;01/11/2026;TRF SALARIO;1.850,00;2.310,45",
      '03/11/2026;03/11/2026;"MERCADONA; VALENCIA";-62,40;2.248,05',
      "linha estragada;;;;",
    ].join("\n");
    const result = parseBankCSV(csv);
    expect(result.rows).toHaveLength(2);
    expect(result.skippedLines).toBe(1);
    expect(result.rows[0]).toEqual({ date: new Date(2026, 10, 1), title: "TRF SALARIO", signedAmount: 1850 });
    expect(result.rows[1].title).toBe("MERCADONA; VALENCIA");
    expect(result.rows[1].signedAmount).toBe(-62.4);
  });

  test("débito e crédito em colunas separadas (espanhol)", () => {
    const result = parseBankCSV("Fecha;Concepto;Cargo;Abono\n2026-11-04;Bizum Ana;;25,00\n2026-11-05;Amazon;19,99;\n");
    expect(result.rows.map((r) => r.signedAmount)).toEqual([25, -19.99]);
    expect(result.rows[0].date).toEqual(new Date(2026, 10, 4));
  });

  test("inglês e sem colunas", () => {
    expect(parseBankCSV("Date,Description,Amount\n19/11/2026,Coffee,-2.50\n").rows[0].signedAmount).toBe(-2.5);
    expect(() => parseBankCSV("a;b\n1;2")).toThrow();
  });

  test("duplicados: mesmo dia, valor e descrição (sem acentos nem maiúsculas)", () => {
    expect(duplicateKey(new Date(2026, 10, 3, 9), -62.4, "Mercadona Valência")).toBe(duplicateKey(new Date(2026, 10, 3, 20), -62.4, "MERCADONA VALENCIA"));
    expect(duplicateKey(new Date(2026, 10, 4), -62.4, "x")).not.toBe(duplicateKey(new Date(2026, 10, 3), -62.4, "x"));
  });
});

describe("categorias por regras", () => {
  const names = ["Alimentação", "Casa", "Transporte", "Carro", "Saúde", "Lazer", "Compras", "Assinaturas", "Outros"];
  test.each([
    ["MERCADONA VALENCIA 1234", "Alimentação"], ["Compra Lidl Madrid", "Alimentação"], ["REPSOL E.S. 4521", "Carro"],
    ["Uber *Trip", "Transporte"], ["Uber Eats pedido", "Alimentação"], ["NETFLIX.COM", "Assinaturas"],
    ["Amazon Prime", "Assinaturas"], ["AMAZON EU SARL", "Compras"], ["Farmácia Central", "Saúde"],
    ["Iberdrola factura", "Casa"], ["Cinesa Proyecciones", "Lazer"],
  ])("%s → %s", (title, expected) => {
    expect(new MerchantRules().suggest(title, names)).toEqual({ categoryName: expected, source: "rules" });
  });

  test("palavras curtas só contam inteiras", () => {
    expect(new MerchantRules().suggest("Dia %", names)?.categoryName).toBe("Alimentação");
    expect(new MerchantRules().suggest("Diario de Noticias", names)).toBeNull();
  });

  test("o histórico ganha às regras e o mais recente ganha", () => {
    const rules = new MerchantRules([
      { title: "Mercadona", categoryName: "Casa", date: "2026-01-01T00:00:00Z" },
      { title: "Mercadona", categoryName: "Lazer", date: "2026-01-01T00:01:00Z" },
    ]);
    expect(rules.suggest("MERCADONA", names)).toEqual({ categoryName: "Lazer", source: "history" });
    expect(merchantKey("Compra Apple Pay Zara 33")).toBe("zara");
  });

  test("categoria do utilizador pelo nome", () => {
    expect(new MerchantRules().suggest("Repsol", ["Alimentação"])).toBeNull();
    expect(new MerchantRules().suggest("Mensalidade ginásio", ["Ginásio"])?.categoryName).toBe("Ginásio");
    expect(new MerchantRules().suggest("  ", names)).toBeNull();
  });
});

describe("faturas", () => {
  test("talão de supermercado espanhol", () => {
    const result = parseReceipt([
      "MERCADONA, S.A.", "C/ Gran Vía 12, Madrid", "CIF A-46103834", "FACTURA SIMPLIFICADA 2311-014-123456",
      "Fecha: 14/11/2026 18:42", "LECHE ENTERA 6X1L     5,34", "PAN BARRA             0,65",
      "BASE IMPONIBLE       21,00", "IVA 10%               2,10", "TOTAL (€)            23,10", "TARJETA BANCARIA     23,10",
    ]);
    expect(result.merchant).toBe("Mercadona, S.A.");
    expect(result.amount).toBe(23.1);
    expect(result.currencyCode).toBe("EUR");
    expect(result.date).toEqual(new Date(2026, 10, 14, 12));
  });

  test("totais", () => {
    expect(total(["Restaurante O Tasco", "Total a pagar", "1.234,56 €", "Obrigado"])).toBe(1234.56);
    expect(total(["Subtotal 10,00", "Total 12,10", "Entregado 20,00", "Cambio 7,90"])).toBe(12.1);
    expect(total(["Café 1,20", "Tosta 3,50"])).toBe(3.5);
    expect(total(["Sem valores"])).toBeNull();
  });

  test("datas inválidas", () => {
    expect(dateIn("31/02/2026")).toBeNull();
    expect(dateIn("Tel 91/234/5678")).toBeNull();
  });
});

describe("contas a pagar", () => {
  test("custo mensal e próximo vencimento", () => {
    expect(monthlyCost({ amount: 12, currency_code: "EUR", recurrence: "weekly" }, 6)).toBe(52);
    expect(monthlyCost({ amount: 120, currency_code: "EUR", recurrence: "yearly" }, 6)).toBe(10);
    expect(monthlyCost({ amount: 60, currency_code: "BRL", recurrence: "monthly" }, 6)).toBe(10);
    expect(nextDueDate(new Date(2026, 0, 31, 9).toISOString(), "none")).toBeNull();
    expect(new Date(nextDueDate(new Date(2026, 10, 21, 9).toISOString(), "monthly")!).getMonth()).toBe(11);
  });
});
