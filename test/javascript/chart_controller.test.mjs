import { test, describe } from "node:test"
import assert from "node:assert/strict"
import Controller from "../../app/javascript/controllers/railsui_chart_controller.js"

// The controller is only ever constructed here, never connected: everything
// below runs before Apex is involved, which is exactly where the bugs were.
const controller = () => new Controller()

describe("applyFormatters", () => {
  test("leaves responsive alone on a chart that has none", () => {
    // A sparkline never gets breakpoints. Writing the key back as undefined is
    // not the same as leaving it out — Apex finds it, walks it as a list, and
    // throws before drawing. Every sparkline rendered as an empty element with
    // nothing in the console.
    const result = controller().applyFormatters({ format: "number", yaxis: {} })

    assert.equal("responsive" in result, false)
  })

  test("plants the formatter in each breakpoint that has an axis", () => {
    // Breakpoint overrides replace the axis rather than merging into it, so an
    // unformatted mobile axis is the default unless it is planted there too.
    const result = controller().applyFormatters({
      format: "currency",
      yaxis: {},
      responsive: [{ breakpoint: 640, options: { yaxis: { tickAmount: 4 } } }]
    })

    assert.equal(typeof result.responsive[0].options.yaxis.labels.formatter, "function")
  })

  test("gives each axis of a combo its own formatter", () => {
    const result = controller().applyFormatters({
      format: "number",
      yaxis: [{ format: "short_currency" }, { format: "percentage" }]
    })

    assert.equal(result.yaxis[0].labels.formatter(52000), "$52K")
    assert.equal(result.yaxis[1].labels.formatter(4.2), "4.2%")
  })

  test("an axis with no format of its own falls back to the chart's", () => {
    const result = controller().applyFormatters({ format: "percentage", yaxis: [{}, {}] })

    assert.equal(result.yaxis[0].labels.formatter(4.2), "4.2%")
  })

  test("a horizontal bar formats the axis carrying its values", () => {
    // Values run along x on a horizontal bar. Dressing y there would format
    // the category names and leave the numbers bare.
    const result = controller().applyFormatters({
      format: "currency",
      plotOptions: { bar: { horizontal: true } },
      xaxis: {}
    })

    assert.equal(typeof result.xaxis.labels.formatter, "function")
  })

  test("leaves a time axis to format itself", () => {
    // A timeline's x values are milliseconds. A number formatter over the top
    // turns every tick into "1,786,380,000,000" where a date belongs.
    const result = controller().applyFormatters({
      format: "number",
      plotOptions: { bar: { horizontal: true } },
      xaxis: { type: "datetime" }
    })

    assert.equal(result.xaxis.labels, undefined)
  })

  test("still formats a horizontal bar that is not about time", () => {
    const result = controller().applyFormatters({
      format: "currency",
      plotOptions: { bar: { horizontal: true } },
      xaxis: {}
    })

    assert.equal(typeof result.xaxis.labels.formatter, "function")
  })
})

describe("formatterFor", () => {
  const format = (name, value, currency) => controller().formatterFor(name, currency)(value)

  test("currency", () => assert.equal(format("currency", 18450, "$"), "$18,450"))
  test("a currency other than the dollar", () => assert.equal(format("currency", 1200, "£"), "£1,200"))
  test("short currency", () => assert.equal(format("short_currency", 52000, "$"), "$52K"))
  test("percentage", () => assert.equal(format("percentage", 4.25), "4.3%"))
  test("human", () => assert.equal(format("human", 1_200_000), "1.2M"))

  test("number trims a computed float", () => {
    // A computed series arrives as 860.0000000000000 and has to read as 860.
    assert.equal(format("number", 860.0000000000000), "860")
  })

  test("number delimits", () => assert.equal(format("number", 1204), "1,204"))

  test("an unknown format asks for no formatter at all", () => {
    assert.equal(controller().formatterFor("nonsense"), null)
  })

  test("nulls pass through rather than becoming NaN", () => {
    assert.equal(format("currency", null), null)
    assert.equal(format("number", undefined), undefined)
  })
})

describe("humanFormat", () => {
  const human = (value) => controller().humanFormat(value)

  test("zero", () => assert.equal(human(0), "0"))
  test("under a thousand", () => assert.equal(human(860), "860"))
  test("drops a decimal that says nothing", () => assert.equal(human(2000), "2K"))
  test("keeps one that does", () => assert.equal(human(2400), "2.4K"))
  test("negatives keep their sign", () => assert.equal(human(-1500), "-1.5K"))
})

describe("formatRow", () => {
  test("a row's own formatter wins", () => {
    // A currency row and a percentage row in one tooltip cannot share a
    // formatter without one of them reading in the wrong units.
    const own = (value) => `${value}%`
    assert.equal(controller().formatRow({ value: 4.2, format: own }, () => "wrong"), "4.2%")
  })

  test("falls back to the chart's", () => {
    assert.equal(controller().formatRow({ value: 7, format: null }, (v) => `$${v}`), "$7")
  })

  test("no formatter anywhere leaves the value alone", () => {
    assert.equal(controller().formatRow({ value: 7 }, null), 7)
  })
})

describe("escape", () => {
  test("series names and category labels are application data", () => {
    assert.equal(
      controller().escape('<img src=x onerror="alert(1)">'),
      "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;"
    )
  })

  test("null becomes empty rather than the word null", () => {
    assert.equal(controller().escape(null), "")
  })
})

describe("applyTooltip on sparklines", () => {
  const render = (options, payload) => controller().applyTooltip(options).tooltip.custom(payload)

  test("the hovered point carries a label and value", () => {
    const html = render(
      { format: "number", chart: { sparkline: { enabled: true } } },
      {
        series: [[18, 22, 19]],
        seriesIndex: 0,
        dataPointIndex: 1,
        w: { globals: { labels: ["Mon", "Tue", "Wed"], colors: ["#6366f1"], seriesNames: ["Page views"] } }
      }
    )

    assert.match(html, /Tue/)
    assert.match(html, /Page views/)
    assert.match(html, /22/)
  })
})

describe("applyTooltip on range bars", () => {
  const start = Date.UTC(2026, 7, 10, 9, 0)
  const finish = Date.UTC(2026, 7, 10, 11, 30)
  const options = {
    chart: { type: "rangeBar" },
    colors: ["#047857", "#b91c1c", "#d97706"],
    plotOptions: { bar: { distributed: true, horizontal: true } },
    series: [{ name: "Timeline", data: [
      { x: "web", y: [start, start + 1_200_000] },
      { x: "api", y: [start + 600_000, start + 2_400_000] },
      { x: "worker", y: [start, finish] }
    ] }],
    xaxis: { type: "datetime" }
  }

  const render = (pointIndex) => controller().applyTooltip(options).tooltip.custom({
    series: [[start + 1_200_000, start + 2_400_000, finish]],
    seriesIndex: 0,
    dataPointIndex: pointIndex,
    w: {
      config: { series: options.series },
      globals: { labels: ["web", "api", "worker"], colors: options.colors, seriesNames: ["Timeline"] }
    }
  })

  test("the hovered bar carries its own label, color, and range", () => {
    const html = render(2)

    assert.match(html, /worker/)
    assert.match(html, /#d97706/)
    assert.match(html, /Aug 10/)
    assert.match(html, /9:00 AM - 11:30 AM/)
    assert.doesNotMatch(html, /1,786,361,400,000/)
  })

  test("the color follows the hovered distributed bar", () => {
    const html = render(1)

    assert.match(html, /api/)
    assert.match(html, /#b91c1c/)
    assert.doesNotMatch(html, /#047857/)
  })
})

describe("applyTooltip on labelled point charts", () => {
  const options = {
    chart: { type: "treemap" },
    format: "short_currency",
    colors: ["#312e81", "#4338ca", "#6366f1"],
    plotOptions: { treemap: { distributed: true, enableShades: false } },
    series: [{ name: "Spend", data: [
      { x: "Salaries", y: 128_400 },
      { x: "Infrastructure", y: 74_000 },
      { x: "Tooling", y: 31_000 }
    ] }]
  }

  const render = (pointIndex) => controller().applyTooltip(options).tooltip.custom({
    series: [[128_400, 74_000, 31_000]],
    seriesIndex: 0,
    dataPointIndex: pointIndex,
    w: {
      config: { series: options.series },
      globals: { labels: [], colors: options.colors, seriesNames: ["Spend"] }
    }
  })

  test("the hovered rectangle carries its own label, color, and value", () => {
    const html = render(0)

    assert.match(html, /Salaries/)
    assert.match(html, /Spend/)
    assert.match(html, /\$128\.4K/)
    assert.match(html, /#312e81/)
  })

  test("the color follows the hovered rectangle", () => {
    const html = render(2)

    assert.match(html, /Tooling/)
    assert.match(html, /#6366f1/)
    assert.doesNotMatch(html, /#312e81/)
  })
})

describe("resolveCssVariable", () => {
  const withComputed = (value) => {
    const instance = controller()
    instance.element = {}
    globalThis.getComputedStyle = () => ({ getPropertyValue: () => value })
    return instance
  }

  test("takes the computed value when the page defines one", () => {
    assert.equal(withComputed("#ff0000").resolveCssVariable("var(--rui-chart-primary, #6366f1)"), "#ff0000")
  })

  test("falls back to the literal when it does not", () => {
    assert.equal(withComputed("").resolveCssVariable("var(--rui-chart-primary, #6366f1)"), "#6366f1")
  })

  test("leaves a plain colour untouched", () => {
    assert.equal(withComputed("").resolveCssVariable("#0ea5e9"), "#0ea5e9")
  })
})

describe("applyTooltip on circular charts", () => {
  // A pie, donut or polar area hands the custom tooltip a flat array of
  // numbers and names the hovered slice with seriesIndex. Indexing it the
  // cartesian way produced undefined for every value; rows without a value
  // are dropped, so the tooltip rendered as an empty box with no heading.
  const pie = (overrides = {}) => ({
    series: [8200, 14800, 9000],
    seriesIndex: 2,
    dataPointIndex: -1,
    w: { globals: { labels: ["Starter", "Pro", "Enterprise"], colors: ["#6366f1", "#ea580c", "#db2777"], seriesNames: [] } },
    ...overrides
  })

  const render = (options, payload) => controller().applyTooltip(options).tooltip.custom(payload)

  test("the hovered slice carries its name and its value", () => {
    const html = render({ format: "short_currency" }, pie())

    assert.match(html, /Enterprise/)
    assert.match(html, /\$9K/)
  })

  test("the value is not dropped as undefined", () => {
    const html = render({ format: "number" }, pie())

    assert.match(html, /<tr>/, "expected a row rather than an empty table")
    assert.doesNotMatch(html, /undefined/)
  })

  test("the slice's own colour keys the row", () => {
    const html = render({ format: "number" }, pie({ seriesIndex: 1 }))

    assert.match(html, /#ea580c/)
    assert.match(html, /Pro/)
  })

  test("a cartesian chart still reads one array per series", () => {
    const html = render({ format: "number" }, {
      series: [[1, 2], [3, 4]],
      seriesIndex: 0,
      dataPointIndex: 1,
      w: { globals: { labels: ["Jan", "Feb"], colors: ["#111", "#222"], seriesNames: ["A", "B"] } }
    })

    assert.match(html, /Feb/)
    assert.match(html, /A/)
    assert.match(html, /B/)
  })
})
