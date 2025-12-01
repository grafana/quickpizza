/**
 * Utility to send Sentry errors with source context.
 * 
 * Since browser-based Sentry SDKs don't have access to source files at runtime,
 * they cannot include preContext, contextLine, and postContext in error payloads.
 * 
 * This utility manually constructs error events with source context for testing
 * purposes when sending to a Sentry-compatible backend like Grafault.
 */

import * as Sentry from '@sentry/svelte';

interface FrameWithContext {
  filename: string;
  function: string;
  lineno: number;
  colno?: number;
  in_app: boolean;
  pre_context?: string[];
  context_line?: string;
  post_context?: string[];
}

interface ErrorTemplate {
  type: string;
  value: string;
  frames: FrameWithContext[];
}

/**
 * Pre-defined error templates with source context for testing
 */
const errorTemplates: Record<string, ErrorTemplate> = {
  TypeError: {
    type: 'TypeError',
    value: "Cannot read properties of undefined (reading 'map')",
    frames: [
      {
        filename: '/src/routes/+page.svelte',
        function: 'renderPizzaList',
        lineno: 142,
        colno: 28,
        in_app: true,
        pre_context: [
          '  // Render the list of pizzas',
          '  function renderPizzaList(pizzas) {',
          '    if (!pizzas) return [];',
        ],
        context_line: "    return pizzas.map(p => p.name);",
        post_context: [
          '  }',
          '',
          '  // Get pizza recommendations',
        ],
      },
      {
        filename: '/src/lib/api.ts',
        function: 'fetchPizzas',
        lineno: 45,
        colno: 12,
        in_app: true,
        pre_context: [
          '  const response = await fetch(endpoint);',
          '  const data = await response.json();',
        ],
        context_line: '  return renderPizzaList(data.pizzas);',
        post_context: [
          '}',
          '',
        ],
      },
      {
        filename: 'node_modules/svelte/internal/index.js',
        function: 'run',
        lineno: 18,
        in_app: false,
      },
    ],
  },
  NetworkError: {
    type: 'Error',
    value: 'Failed to fetch pizza recommendations: Network request failed',
    frames: [
      {
        filename: '/src/routes/+page.svelte',
        function: 'getPizza',
        lineno: 175,
        colno: 15,
        in_app: true,
        pre_context: [
          'async function getPizza() {',
          '  try {',
          '    const res = await fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/pizza`, {',
        ],
        context_line: "      method: 'POST',",
        post_context: [
          '      body: JSON.stringify(restrictions),',
          '      headers: {',
          "        'Content-Type': 'application/json',",
        ],
      },
      {
        filename: '/src/routes/+page.svelte',
        function: 'handleClick',
        lineno: 378,
        colno: 8,
        in_app: true,
        pre_context: [
          '  <button',
          '    slot="label"',
          '    type="button"',
        ],
        context_line: '    on:click={getPizza}',
        post_context: [
          '    class="mt-6 text-white bg-gradient-to-br..."',
          '  >',
          '    Pizza, Please!</button>',
        ],
      },
    ],
  },
  ValidationError: {
    type: 'ValidationError',
    value: 'Invalid pizza configuration: minimum toppings cannot exceed maximum',
    frames: [
      {
        filename: '/src/lib/validators.ts',
        function: 'validateRestrictions',
        lineno: 23,
        colno: 11,
        in_app: true,
        pre_context: [
          'export function validateRestrictions(restrictions: Restrictions): void {',
          '  if (restrictions.minNumberOfToppings > restrictions.maxNumberOfToppings) {',
        ],
        context_line: "    throw new ValidationError('Invalid pizza configuration: minimum toppings cannot exceed maximum');",
        post_context: [
          '  }',
          '  if (restrictions.maxCaloriesPerSlice < 100) {',
          "    throw new ValidationError('Maximum calories must be at least 100');",
        ],
      },
      {
        filename: '/src/routes/+page.svelte',
        function: 'getPizza',
        lineno: 163,
        colno: 5,
        in_app: true,
        pre_context: [
          'async function getPizza() {',
          '  faro.api.pushEvent("Get Pizza Recommendation", { restrictions });',
        ],
        context_line: '  validateRestrictions(restrictions);',
        post_context: [
          '  const res = await fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/pizza`, {',
          "    method: 'POST',",
        ],
      },
    ],
  },
  RenderError: {
    type: 'RenderError',
    value: 'Component failed to render: missing required prop "ingredients"',
    frames: [
      {
        filename: '/src/components/PizzaCard.svelte',
        function: 'create_fragment',
        lineno: 45,
        colno: 22,
        in_app: true,
        pre_context: [
          '<script lang="ts">',
          '  export let pizza: Pizza;',
          '  ',
          '  $: ingredientNames = pizza.ingredients',
        ],
        context_line: "    .map(i => i.name)",
        post_context: [
          "    .join(', ');",
          '</script>',
          '',
        ],
      },
      {
        filename: '/src/routes/+page.svelte',
        function: 'update',
        lineno: 412,
        colno: 10,
        in_app: true,
        pre_context: [
          '  {#if pizza}',
          '    <div class="pizza-container">',
        ],
        context_line: '      <PizzaCard {pizza} />',
        post_context: [
          '    </div>',
          '  {/if}',
        ],
      },
    ],
  },
};

/**
 * Send a test error to Sentry with source context included.
 * This bypasses the normal Sentry.captureException to manually construct
 * the event payload with preContext, contextLine, and postContext.
 */
export function sendErrorWithContext(
  errorType: keyof typeof errorTemplates = 'TypeError'
): void {
  const template = errorTemplates[errorType];
  if (!template) {
    console.error(`Unknown error type: ${errorType}`);
    return;
  }

  // Construct the event manually with source context
  const event: Sentry.Event = {
    event_id: crypto.randomUUID().replace(/-/g, ''),
    timestamp: Date.now() / 1000,
    platform: 'javascript',
    environment: 'development',
    exception: {
      values: [
        {
          type: template.type,
          value: template.value,
          stacktrace: {
            frames: template.frames.map((frame) => ({
              filename: frame.filename,
              function: frame.function,
              lineno: frame.lineno,
              colno: frame.colno,
              in_app: frame.in_app,
              pre_context: frame.pre_context,
              context_line: frame.context_line,
              post_context: frame.post_context,
            })),
          },
        },
      ],
    },
    contexts: {
      browser: {
        name: navigator.userAgent.includes('Chrome') ? 'Chrome' : 
              navigator.userAgent.includes('Firefox') ? 'Firefox' : 
              navigator.userAgent.includes('Safari') ? 'Safari' : 'Unknown',
      },
      os: {
        name: navigator.platform,
      },
      runtime: {
        name: 'browser',
        version: navigator.userAgent,
      },
    },
    tags: {
      source: 'test-button',
      has_context: 'true',
    },
  };

  // Send the event using captureEvent (exported from @sentry/core)
  Sentry.captureEvent(event);
  
  console.log(`Sent ${errorType} error with source context to Sentry`);
}

/**
 * Get available error types for the UI
 */
export function getAvailableErrorTypes(): string[] {
  return Object.keys(errorTemplates);
}

