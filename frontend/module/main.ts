import { Injector, NgModule } from "@angular/core";
import { Application } from "@hotwired/stimulus";
import { OpenProjectStimulusApplication } from "core-stimulus/openproject-stimulus-application";
import { OpSharedModule } from "core-app/shared/shared.module";
import { registerCustomElement } from "core-app/shared/helpers/angular/custom-elements.helper";
import SharepointTestController from "./sharepoint-test.controller";
import { SpSiteCardsComponent } from "./sp-site-cards/sp-site-cards.component";

declare global {
  interface Window { Stimulus: Application }
}

// preregisterDynamic adds to the dynamicImports Map for future Turbo navigations.
OpenProjectStimulusApplication.preregisterDynamic(
  "sharepoint-test",
  () => import("./sharepoint-test.controller"),
);

// Fix: Angular bootstraps inside an async initializeLocale().then() callback,
// so by the time this code runs, Stimulus has already scanned the DOM and
// attempted (and failed) to load "sharepoint-test" via the dynamic fallback.
// Calling window.Stimulus.register() directly causes Stimulus to connect the
// controller to any elements with data-controller="sharepoint-test" already
// present in the DOM, resolving the race condition without touching core files.
// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
if (typeof window.Stimulus !== "undefined") {
  window.Stimulus.register("sharepoint-test", SharepointTestController);
}

// @NgModule is required — LinkedPluginsModule imports this as an Angular module.
@NgModule({
  imports: [OpSharedModule],
  declarations: [SpSiteCardsComponent],
  exports: [SpSiteCardsComponent],
})
export class PluginModule {
  constructor(injector: Injector) {
    // Register <sp-site-cards> as a custom element so it can be used
    // directly in ERB templates without Angular routing.
    registerCustomElement("sp-site-cards", SpSiteCardsComponent, { injector });
  }
}
