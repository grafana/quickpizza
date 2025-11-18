<script lang="ts">
// biome-ignore assist/source/organizeImports: organized by hand
import { faro } from '@grafana/faro-web-sdk';
import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';
import { onMount } from 'svelte';

var loginError = '';
var username = 'admin';
var password = 'admin';
var adminLoggedIn = false;
var latestPizzaRecommendations: string[] = [];

onMount(async () => {
	adminLoggedIn = checkAdminLoggedIn();
});

function checkAdminLoggedIn() {
	const tokenCookie = document.cookie
		.split('; ')
		.filter((c) => c.startsWith('admin_token'));
	if (tokenCookie.length === 0) {
		return false;
	}

	return true;
}

async function handleSubmit() {
	faro.api.startUserAction(
		'adminLogin', // name of the user action
		{ username: username }, // custom attributes attached to the user action
		{ triggerName: 'adminLoginButtonClick', importance: 'critical' }, // custom config
	);
	const res = await fetch(
		`${PUBLIC_BACKEND_ENDPOINT}/api/admin/login?user=${username}&password=${password}`,
		{
			method: 'POST',
			credentials: 'same-origin', // Honor Set-Cookie header returned by /api/admin/login.
		},
	);
	if (!res.ok) {
		loginError = 'Login failed: ' + res.statusText;
		faro.api.pushEvent('Unsuccessful Admin Login', { username: username });
		faro.api.pushError(new Error('Admin Login Error: ' + res.statusText));
		return;
	}

	faro.api.pushEvent('Successful Admin Login', { username: username });
	adminLoggedIn = checkAdminLoggedIn();
}

async function handleLogout() {
	faro.api.startUserAction(
		'adminLogout', // name of the user action
		{ username: username }, // custom attributes attached to the user action
		{ triggerName: 'adminLogoutButtonClick', importance: 'critical' }, // custom config
	);
	faro.api.pushEvent('Admin Logout');
	// Perhaps surprisingly, this only deletes (clears the value of) the admin_token cookie.
	document.cookie = 'admin_token=; Expires=Thu, 01 Jan 1970 00:00:01 GMT';
	adminLoggedIn = false;
}

$: if (adminLoggedIn) {
	updateRecommendations();
}

function updateRecommendations() {
	// Admin token is sent via Cookies in headers
	fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/internal/recommendations`, {
		method: 'GET',
	})
		.then((res) => res.json())
		.then((json) => {
			faro.api.pushEvent('Update Recent Pizza Recommendations');
			var newRec: string[] = [];
			json.pizzas.forEach((pizza: string) => {
				newRec.push(`
                ${pizza.name} (tool=${pizza.tool}, ingredients_number=${pizza.ingredients.length})`);
			});
			if (newRec.length >= 15) {
				faro.api.pushError(new Error('Too Many Recommendations'));
			}
			newRec = newRec.slice(0, 15);
			if (newRec.length >= 0) {
				newRec[0] = newRec[0] + ' (newest)';
			}
			latestPizzaRecommendations = newRec;
		});
}
</script>

{#if adminLoggedIn}
	<section class="flex flex-column justify-center items-center mt-40">
		<div class="text-center">
			<button
				on:click={handleLogout}
				class="w-20 text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm text-center"
				>Logout</button
			>
			<div class="mt-4 mb-4">
				<h2 class="text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl mb-2">
					Latest pizza recommendations
				</h2>
				<ul>
					{#if latestPizzaRecommendations.length === 0}
						<li>No recommendations yet</li>
					{:else}
						{#each latestPizzaRecommendations as pizza}
							<li>{pizza}</li>
						{/each}
					{/if}
				</ul>
			</div>
			<button
				on:click={updateRecommendations}
				class="w-20 text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm text-center"
				>Refresh</button
			>
		</div>
	</section>
{:else}
	<section class="flex flex-column justify-center items-center mt-40">
		<div class="text-center">
			<div class="w-full bg-white rounded-lg shadow md:mt-0 sm:max-w-md xl:p-0">
				<div class="p-6 space-y-4 md:space-y-6 sm:p-8">
					<h1 class="text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl">
						QuickPizza Administration
					</h1>
					<form class="space-y-4 md:space-y-6" on:submit|preventDefault={handleSubmit}>
						<div>
							<label for="username" class="block mb-2 text-sm font-medium text-gray-900"
								>Username (hint: admin)</label
							>
							<input
								type="text"
								name="username"
								id="username"
								class="bg-gray-50 border border-gray-300 text-gray-900 sm:text-sm rounded-lg focus:ring-primary-600 focus:border-primary-600 block w-full p-2.5"
								required
								bind:value={username}
							/>
						</div>
						<div>
							<label for="password" class="block mb-2 text-sm font-medium text-gray-900"
								>Password (hint: admin)</label
							>
							<input
								type="password"
								name="password"
								id="password"
								class="bg-gray-50 border border-gray-300 text-gray-900 sm:text-sm rounded-lg focus:ring-primary-600 focus:border-primary-600 block w-full p-2.5"
								required
								bind:value={password}
							/>
						</div>
						<button
							type="submit"
							class="w-full text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center"
							>Sign in</button
						>
					</form>
					{#if loginError}
						<div class="text-center text-red-500">{loginError}</div>
					{/if}
				</div>
			</div>
		</div>
	</section>
{/if}
<footer>
	<div class="flex justify-center mt-2">
		<p class="text-xs">
			<a class="text-blue-500" data-sveltekit-reload href="/">Back to main page</a>
		</p>
	</div>
</footer>
