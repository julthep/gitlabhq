<script>
import { GlButton } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { viewerTypes } from '../constants';

export default {
  components: {
    GlButton,
  },
  props: {
    viewer: {
      type: String,
      required: true,
    },
    mergeRequestId: {
      type: Number,
      required: true,
    },
  },
  computed: {
    mergeReviewLine() {
      return sprintf(__('Reviewing (merge request !%{mergeRequestId})'), {
        mergeRequestId: this.mergeRequestId,
      });
    },
  },
  methods: {
    changeMode(mode) {
      this.$emit('click', mode);
    },
  },
  viewerTypes,
};
</script>

<template>
  <div class="dropdown">
    <gl-button variant="link" data-toggle="dropdown">{{ __('Edit') }}</gl-button>
    <div class="dropdown-menu dropdown-menu-selectable dropdown-open-left">
      <ul>
        <li>
          <a
            :class="{
              'is-active': viewer === $options.viewerTypes.mr,
            }"
            href="#"
            @click.prevent="changeMode($options.viewerTypes.mr)"
          >
            <strong class="dropdown-menu-inner-title"> {{ mergeReviewLine }} </strong>
            <span class="dropdown-menu-inner-content">
              {{ __('Compare changes with the merge request target branch') }}
            </span>
          </a>
        </li>
        <li>
          <a
            :class="{
              'is-active': viewer === $options.viewerTypes.diff,
            }"
            href="#"
            @click.prevent="changeMode($options.viewerTypes.diff)"
          >
            <strong class="dropdown-menu-inner-title">{{ __('Reviewing') }}</strong>
            <span class="dropdown-menu-inner-content">
              {{ __('Compare changes with the last commit') }}
            </span>
          </a>
        </li>
      </ul>
    </div>
  </div>
</template>
