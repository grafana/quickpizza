<script lang="ts">
// biome-ignore assist/source/organizeImports: organized by hand
import { faro } from '@grafana/faro-web-sdk';
import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';
import { onMount } from 'svelte';

var loginError = '';
var username = '';
var password = '';
var qpUserLoggedIn = false;
var ratings = [];

onMount(async () => {
	qpUserLoggedIn = checkQPUserLoggedIn();

	if (!qpUserLoggedIn) {
		await fetchCSRFToken();
	}
});

function getCookie(name) {
	for (let cookie of document.cookie.split('; ')) {
		const [key, value] = cookie.split('=');
		if (key === name) {
			return decodeURIComponent(value);
		}
	}
	return null;
}

function checkQPUserLoggedIn() {
	let token = getCookie('qp_user_token');
	return token !== null && token.length > 0;
}

async function fetchCSRFToken() {
	await fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/csrf-token`, {
		method: 'POST',
		credentials: 'same-origin',
	});

	document.getElementById('csrf-token').value = getCookie('csrf_token') || '';
}

async function handleSubmit() {
	faro.api.startUserAction(
		'userLogin', // name of the user action
		{ username: username }, // custom attributes attached to the user action
		{ triggerName: 'userLoginButtonClick', importance: 'critical' }, // custom config
	);
	const res = await fetch(
		`${PUBLIC_BACKEND_ENDPOINT}/api/users/token/login?set_cookie=true`,
		{
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({
				username: username,
				password: password,
				csrf: document.getElementById('csrf-token').value,
			}),
			credentials: 'same-origin',
		},
	);
	if (!res.ok) {
		loginError = 'Login failed: ' + res.statusText;
		faro.api.pushEvent('Unsuccessful Login', { username: username });
		faro.api.pushError(new Error('Login Error: ' + res.statusText));
		return;
	}

	faro.api.pushEvent('Successful Login', { username: username });
	qpUserLoggedIn = checkQPUserLoggedIn();
}

$: if (qpUserLoggedIn) {
	updateRatings();
}

async function updateRatings() {
	ratings = [];
	const res = await fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/ratings`, {
		method: 'GET',
		credentials: 'same-origin',
	});
	if (!res.ok) {
		ratings = ['Something went wrong retrieving your ratings.'];
		return;
	}
	const json = await res.json();

	var newRatings = [];
	json.ratings.forEach((rating) => {
		newRatings.push(
			`Rating ID: ${rating.id} (stars=${rating.stars}, pizza_id=${rating.pizza_id})`,
		);
	});
	ratings = newRatings;
}

async function deleteRatings() {
	faro.api.startUserAction(
		'userDeleteRatings', // name of the user action
		{ username: username }, // custom attributes attached to the user action
		{ triggerName: 'userDeleteRatingsButtonClick', importance: 'critical' }, // custom config
	);
	const res = await fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/ratings`, {
		method: 'DELETE',
		credentials: 'same-origin',
	});

	if (!res.ok) {
		if (res.status === 403) {
			const json = await res.json();
			alert(
				'Cannot clear ratings: The default user is not allowed to delete ratings. Please create your own user account.',
			);
		} else if (res.status === 401) {
			alert('You need to be logged in to clear ratings.');
		} else {
			alert('Failed to clear ratings: ' + res.statusText);
		}
		return;
	}

	location.reload();
}

async function handleLogout() {
	faro.api.startUserAction(
		'userLogout', // name of the user action
		{ username: username }, // custom attributes attached to the user action
		{ triggerName: 'userLogoutButtonClick', importance: 'critical' }, // custom config
	);
	faro.api.pushEvent('User Logout');
	document.cookie = 'qp_user_token=; Expires=Thu, 01 Jan 1970 00:00:01 GMT';
	qpUserLoggedIn = false;
}
</script>

{#if qpUserLoggedIn}
	<section class="flex flex-column justify-center items-center mt-40">
		<div class="text-center">
			<div class="mt-4 mb-12">
				<h2 class="text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl mb-2">
					Your Pizza Ratings:
				</h2>
				<ul>
					{#if ratings.length === 0}
						<li>No ratings yet</li>
					{:else}
						{#each ratings as rating}
							<li>{rating}</li>
						{/each}
					{/if}
				</ul>
			</div>
			<button
				on:click={deleteRatings}
				class="w-32 mr-2 text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm text-center"
				>Clear Ratings</button
			>
			<button
				on:click={handleLogout}
				class="w-20 text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm text-center"
				>Logout</button
			>
		</div>
	</section>
{:else}
	<section class="flex flex-column justify-center items-center mt-40">
		<div class="text-center">
			<div class="w-full bg-white rounded-lg shadow md:mt-0 sm:max-w-md xl:p-0">
				<div class="p-6 space-y-4 md:space-y-6 sm:p-8">
					<h1 class="text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl">
						QuickPizza User Login
					</h1>
					<form class="space-y-4 md:space-y-6" on:submit|preventDefault={handleSubmit}>
						<input type="hidden" name="csrftoken" id="csrf-token" value="" />
						<div>
							<label for="username" class="block mb-2 text-sm font-medium text-gray-900"
								>Username (hint: default)</label
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
								>Password (hint: 12345678)</label
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
							class="w-full text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center mt-10"
							>Sign in</button
						>
					</form>
					<p class="text-sm">
						<b>Tip:</b> You can create a new user via the
						<code>POST http://quickpizza.grafana.com/api/users</code>
						endpoint. Attach a JSON payload with <code>username</code> and <code>password</code> keys.
					</p>
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
