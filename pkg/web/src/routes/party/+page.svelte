<script lang="ts">
// biome-ignore assist/source/organizeImports: organized by hand
import { faro } from '@grafana/faro-web-sdk';
import {
	PUBLIC_BACKEND_ENDPOINT,
	PUBLIC_BACKEND_WS_ENDPOINT,
} from '$env/static/public';
import { onDestroy, onMount } from 'svelte';
import { verifyUserLoggedIn } from '../../lib/auth';
import { isLoggedInStore, wsVisitorIDStore } from '../../lib/stores';

type PizzaRecommendation = {
	pizza: {
		id: number;
		name: string;
		dough: { name: string };
		ingredients: Array<{ name: string }>;
		tool: string;
	};
	calories: number;
	vegetarian: boolean;
};

const restrictions = {
	maxCaloriesPerSlice: 1000,
	mustBeVegetarian: false,
	excludedIngredients: [],
	excludedTools: [],
	maxNumberOfToppings: 5,
	minNumberOfToppings: 2,
	customName: '',
};

let numberOfPizzas = 4;
let pizzas: PizzaRecommendation[] = [];
let failedCount = 0;
let errorResult = '';
let isGenerating = false;
let isLoggedIn = false;
let anonymousToken = '';
let wsVisitorID = 0;
let socket: WebSocket | undefined;
let unsubscribeVisitorID: (() => void) | undefined;

onMount(async () => {
	unsubscribeVisitorID = wsVisitorIDStore.subscribe(
		(value) => (wsVisitorID = value),
	);
	if (wsVisitorID === 0) {
		wsVisitorIDStore.set(Math.floor(100000 + Math.random() * 900000));
	}

	anonymousToken = randomToken(16);
	isLoggedIn = await verifyUserLoggedIn();
	isLoggedInStore.set(isLoggedIn);
	connectWebSocket();
	faro.api.pushEvent('Navigation', { url: window.location.href });
});

onDestroy(() => {
	unsubscribeVisitorID?.();
	socket?.close();
});

function randomToken(length: number): string {
	let result = '';
	const characters =
		'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
	for (let index = 0; index < length; index++) {
		result += characters.charAt(Math.floor(Math.random() * characters.length));
	}
	return result;
}

function connectWebSocket() {
	let wsUrl = PUBLIC_BACKEND_WS_ENDPOINT;
	if (wsUrl === '') {
		const location = window.location;
		wsUrl =
			(location.protocol === 'https:' ? 'wss://' : 'ws://') +
			location.hostname +
			(location.port !== '80' && location.port !== '443'
				? `:${location.port}`
				: '') +
			'/ws';
	}
	socket = new WebSocket(wsUrl);
}

function announcePizza() {
	const message = JSON.stringify({
		user: wsVisitorID,
		ws_visitor_id: wsVisitorID,
		msg: 'new_pizza',
	});

	if (socket?.readyState === WebSocket.OPEN) {
		socket.send(message);
	} else if (socket?.readyState === WebSocket.CONNECTING) {
		const sendWhenOpen = () => {
			socket?.send(message);
			socket?.removeEventListener('open', sendWhenOpen);
		};
		socket.addEventListener('open', sendWhenOpen);
	}
}

async function requestPizza(): Promise<PizzaRecommendation> {
	const headers: Record<string, string> = {
		'Content-Type': 'application/json',
	};
	if (!isLoggedIn) {
		headers.Authorization = `Token ${anonymousToken}`;
	}

	const response = await fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/pizza`, {
		method: 'POST',
		body: JSON.stringify(restrictions),
		headers,
		credentials: 'same-origin',
	});

	if (!response.ok) {
		const contentType = response.headers.get('content-type') || '';
		if (contentType.includes('application/json')) {
			const body = await response.json();
			throw new Error(body.error || 'Failed to get a pizza recommendation.');
		}
		throw new Error(
			`${response.status}: Failed to get a pizza recommendation.`,
		);
	}

	const recommendation = (await response.json()) as PizzaRecommendation;
	announcePizza();
	return recommendation;
}

async function generatePizzas() {
	const count = Math.min(
		12,
		Math.max(2, Math.trunc(Number(numberOfPizzas)) || 2),
	);
	numberOfPizzas = count;
	pizzas = [];
	failedCount = 0;
	errorResult = '';
	isGenerating = true;

	faro.api.pushEvent('Get Batch Pizza Recommendations', {
		count: String(count),
		vegetarian: String(restrictions.mustBeVegetarian),
	});
	faro.api.startUserAction(
		'getBatchPizzas',
		{
			count: String(count),
			vegetarian: String(restrictions.mustBeVegetarian),
		},
		{ triggerName: 'getBatchPizzasButtonClick' },
	);

	try {
		const results = await Promise.allSettled(
			Array.from({ length: count }, () => requestPizza()),
		);
		pizzas = results
			.filter(
				(result): result is PromiseFulfilledResult<PizzaRecommendation> =>
					result.status === 'fulfilled',
			)
			.map((result) => result.value);
		failedCount = results.length - pizzas.length;

		if (failedCount === results.length) {
			errorResult = 'None of the pizzas could be generated. Please try again.';
		} else if (failedCount > 0) {
			errorResult = `${failedCount} of ${results.length} pizzas could not be generated.`;
		}
	} catch (error) {
		errorResult =
			error instanceof Error
				? error.message
				: 'Something went wrong. Please try again.';
		faro.api.pushError(error instanceof Error ? error : new Error(errorResult));
	} finally {
		isGenerating = false;
	}
}
</script>

<svelte:head>
	<title>Pizza Party | QuickPizza</title>
	<meta
		name="description"
		content="Generate several QuickPizza recommendations at the same time."
	/>
</svelte:head>

<header class="mt-4 flow-root">
	<a class="flex float-left items-center" href="/">
		<img class="w-7 h-7 mr-2" src="/images/pizza.png" alt="" />
		<span class="text-xl font-bold text-red-600">QuickPizza</span>
	</a>
	<nav aria-label="Main navigation" class="flex float-right items-center mt-1 gap-4 text-xs font-bold">
		<a class="text-red-600 hover:text-red-800" href="/">Single Pizza</a>
		<a class="text-red-600 hover:text-red-800" data-sveltekit-reload href="/login">
			{isLoggedIn ? 'Profile' : 'Login'}
		</a>
	</nav>
</header>

<main class="mt-20 mb-10">
	<section class="text-center max-w-2xl mx-auto">
		<p class="text-sm font-bold uppercase tracking-widest text-red-600">Pizza Party</p>
		<h1 class="text-3xl md:text-5xl mt-3 font-semibold">One click. A whole table of pizzas.</h1>
		<p class="mt-4 text-gray-700">
			Choose how many recommendations you need and QuickPizza will make them all at once.
		</p>

		<form
			class="mt-8 mx-auto max-w-lg bg-gray-50 border border-gray-200 rounded-lg p-5 text-left"
			on:submit|preventDefault={generatePizzas}
		>
			<div class="sm:flex sm:items-end sm:gap-6">
				<label class="block flex-1 text-sm font-medium text-gray-900" for="pizza-count">
					Number of pizzas
					<input
						id="pizza-count"
						name="pizza-count"
						type="number"
						min="2"
						max="12"
						step="1"
						bind:value={numberOfPizzas}
						class="mt-2 block w-full rounded-lg border border-gray-300 bg-white p-2.5 text-gray-900 focus:border-red-600 focus:ring-red-600"
					/>
				</label>
				<label class="flex items-center mt-4 sm:mt-0 sm:mb-3 text-sm text-gray-900">
					<input
						bind:checked={restrictions.mustBeVegetarian}
						type="checkbox"
						class="w-4 h-4 mr-2 accent-red-600"
					/>
					Vegetarian only
				</label>
			</div>
			<p class="mt-2 text-xs text-gray-500">Choose between 2 and 12 pizzas.</p>
			<button
				type="submit"
				disabled={isGenerating}
				class="mt-5 w-full text-white bg-gradient-to-br from-red-500 to-orange-400 hover:bg-gradient-to-bl disabled:opacity-60 disabled:cursor-wait font-medium rounded-lg text-sm px-5 py-2.5 text-center"
			>
				{isGenerating ? `Making ${numberOfPizzas} pizzas…` : 'Start the Pizza Party'}
			</button>
		</form>
	</section>

	{#if errorResult}
		<div
			class="mt-6 mx-auto max-w-lg bg-red-100 text-red-800 text-sm font-medium px-4 py-2 rounded-lg text-center"
			role="alert"
		>
			{errorResult}
		</div>
	{/if}

	{#if pizzas.length > 0}
		<section class="mt-10" aria-live="polite">
			<div class="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-2 mb-4">
				<div>
					<h2 class="text-2xl font-semibold">Your pizza lineup</h2>
					<p class="text-sm text-gray-600">{pizzas.length} fresh recommendations, ready to share.</p>
				</div>
				<button
					type="button"
					on:click={generatePizzas}
					disabled={isGenerating}
					class="self-start text-red-700 bg-red-50 hover:bg-red-100 border border-red-200 font-medium rounded-lg text-sm px-4 py-2 disabled:opacity-60"
				>
					Make another batch
				</button>
			</div>

			<div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
				{#each pizzas as recommendation, index}
					<article class="bg-gray-50 border border-gray-200 rounded-lg p-5 text-left">
						<p class="text-xs font-bold uppercase tracking-wider text-red-600">Pizza {index + 1}</p>
						<h3 class="mt-1 text-lg font-semibold">{recommendation.pizza.name}</h3>
						<dl class="mt-4 text-sm">
							<div class="flex justify-between gap-4 border-b border-gray-200 py-2">
								<dt class="text-gray-500">Dough</dt>
								<dd class="font-medium text-right">{recommendation.pizza.dough.name}</dd>
							</div>
							<div class="flex justify-between gap-4 border-b border-gray-200 py-2">
								<dt class="text-gray-500">Tool</dt>
								<dd class="font-medium text-right">{recommendation.pizza.tool}</dd>
							</div>
							<div class="flex justify-between gap-4 py-2">
								<dt class="text-gray-500">Calories / slice</dt>
								<dd class="font-medium">{recommendation.calories}</dd>
							</div>
						</dl>
						<h4 class="mt-3 text-sm font-medium">Toppings</h4>
						<ul class="mt-1 list-disc list-inside text-sm text-gray-700">
							{#each recommendation.pizza.ingredients as ingredient}
								<li>{ingredient.name}</li>
							{/each}
						</ul>
					</article>
				{/each}
			</div>
		</section>
	{/if}
</main>

<footer class="flex justify-center mt-8 mb-4">
	<p class="text-sm">Made with ❤️ by QuickPizza Labs.</p>
</footer>
