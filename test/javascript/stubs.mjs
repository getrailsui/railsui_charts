// Stands in for the two packages the controllers import, so they can be loaded
// in plain Node with nothing installed.
//
// This is why there is no package.json, no node_modules, and no test runner
// dependency in this gem: `node --test` is enough, and the only thing missing
// was a way to satisfy two bare imports. Node's own module hooks do that in
// twenty lines.
//
// Neither stub pretends to be the real thing. Stimulus is needed only as a
// class to extend, and ApexCharts only so the import resolves — every test
// here exercises logic that runs before a chart is drawn.
import { registerHooks } from "node:module"

const STUBS = {
  "@hotwired/stimulus": `
    export class Controller {
      constructor(element) { this.element = element }
      dispatch() {}
    }
  `,
  apexcharts: "export default class ApexCharts {}"
}

registerHooks({
  resolve(specifier, context, next) {
    if (specifier in STUBS) return { url: `stub:${specifier}`, shortCircuit: true }
    return next(specifier, context)
  },

  load(url, context, next) {
    if (url.startsWith("stub:")) {
      return { format: "module", source: STUBS[url.slice(5)], shortCircuit: true }
    }
    return next(url, context)
  }
})
