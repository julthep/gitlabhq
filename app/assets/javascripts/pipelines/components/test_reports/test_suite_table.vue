<script>
import { mapGetters } from 'vuex';
import { GlModalDirective, GlTooltipDirective, GlFriendlyWrap, GlIcon, GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import TestCaseDetails from './test_case_details.vue';

export default {
  name: 'TestsSuiteTable',
  components: {
    GlIcon,
    GlFriendlyWrap,
    GlButton,
    TestCaseDetails,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModalDirective,
  },
  props: {
    heading: {
      type: String,
      required: false,
      default: __('Tests'),
    },
  },
  computed: {
    ...mapGetters(['getSuiteTests']),
    hasSuites() {
      return this.getSuiteTests.length > 0;
    },
  },
  wrapSymbols: ['::', '#', '.', '_', '-', '/', '\\'],
};
</script>

<template>
  <div>
    <div class="row gl-mt-3">
      <div class="col-12">
        <h4>{{ heading }}</h4>
      </div>
    </div>

    <div v-if="hasSuites" class="test-reports-table gl-mb-3 js-test-cases-table">
      <div role="row" class="gl-responsive-table-row table-row-header font-weight-bold fgray">
        <div role="rowheader" class="table-section section-20">
          {{ __('Suite') }}
        </div>
        <div role="rowheader" class="table-section section-40">
          {{ __('Name') }}
        </div>
        <div role="rowheader" class="table-section section-10">
          {{ __('Filename') }}
        </div>
        <div role="rowheader" class="table-section section-10 text-center">
          {{ __('Status') }}
        </div>
        <div role="rowheader" class="table-section section-10">
          {{ __('Duration') }}
        </div>
        <div role="rowheader" class="table-section section-10">
          {{ __('Details'), }}
        </div>
      </div>

      <div
        v-for="(testCase, index) in getSuiteTests"
        :key="index"
        class="gl-responsive-table-row rounded align-items-md-start mt-xs-3 js-case-row"
      >
        <div class="table-section section-20 section-wrap">
          <div role="rowheader" class="table-mobile-header">{{ __('Suite') }}</div>
          <div class="table-mobile-content gl-md-pr-2 gl-overflow-wrap-break">
            <gl-friendly-wrap :symbols="$options.wrapSymbols" :text="testCase.classname" />
          </div>
        </div>

        <div class="table-section section-40 section-wrap">
          <div role="rowheader" class="table-mobile-header">{{ __('Name') }}</div>
          <div class="table-mobile-content gl-md-pr-2 gl-overflow-wrap-break">
            <gl-friendly-wrap :symbols="$options.wrapSymbols" :text="testCase.name" />
          </div>
        </div>

        <div class="table-section section-10 section-wrap">
          <div role="rowheader" class="table-mobile-header">{{ __('Filename') }}</div>
          <div class="table-mobile-content gl-md-pr-2 gl-overflow-wrap-break">
            <gl-friendly-wrap :symbols="$options.wrapSymbols" :text="testCase.file" />
            <gl-button
              v-gl-tooltip
              size="small"
              category="tertiary"
              icon="copy-to-clipboard"
              :title="__('Copy to clipboard')"
              :data-clipboard-text="testCase.file"
              :aria-label="__('Copy to clipboard')"
            />
          </div>
        </div>

        <div class="table-section section-10 section-wrap">
          <div role="rowheader" class="table-mobile-header">{{ __('Status') }}</div>
          <div class="table-mobile-content text-center">
            <div
              class="add-border ci-status-icon d-flex align-items-center justify-content-end justify-content-md-center"
              :class="`ci-status-icon-${testCase.status}`"
            >
              <gl-icon :size="24" :name="testCase.icon" />
            </div>
          </div>
        </div>

        <div class="table-section section-10 section-wrap">
          <div role="rowheader" class="table-mobile-header">
            {{ __('Duration') }}
          </div>
          <div class="table-mobile-content pr-sm-1">
            {{ testCase.formattedTime }}
          </div>
        </div>

        <div class="table-section section-10 section-wrap">
          <div role="rowheader" class="table-mobile-header">{{ __('Details'), }}</div>
          <div class="table-mobile-content">
            <gl-button v-gl-modal-directive="`test-case-details-${index}`">{{
              __('View details')
            }}</gl-button>
            <test-case-details :modal-id="`test-case-details-${index}`" :test-case="testCase" />
          </div>
        </div>
      </div>
    </div>

    <div v-else>
      <p class="js-no-test-cases">{{ s__('TestReports|There are no test cases to display.') }}</p>
    </div>
  </div>
</template>
