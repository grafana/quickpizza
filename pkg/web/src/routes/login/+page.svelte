<script lang="ts">
	import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';
	import { onMount } from 'svelte';

	var loginError = '';
	var username = '';
	var password = '';
	var qpUserLoggedIn = false;

	onMount(async () => {
		qpUserLoggedIn = checkQPUserLoggedIn();
	});

	function checkQPUserLoggedIn() {
		const tokenCookie = document.cookie.split('; ').filter((c) => c.startsWith('qp_user_token'));
		if (tokenCookie.length == 0) {
			return false;
		}

		return true;
	}

	async function handleSubmit() {
		const res = await fetch(`${PUBLIC_BACKEND_ENDPOINT}api/users/token/login?set_cookie=1`, {
			method: 'POST',
			body: JSON.stringify({ username: username, password: password }),
			credentials: 'same-origin'
		});
		if (!res.ok) {
			loginError = 'Login failed: ' + res.statusText;
			return;
		}

		qpUserLoggedIn = checkQPUserLoggedIn();
	}

	async function handleLogout() {
		document.cookie = 'qp_user_token=; Expires=Thu, 01 Jan 1970 00:00:01 GMT';
		qpUserLoggedIn = false;
	}
</script>

{#if qpUserLoggedIn}
	<section class="flex flex-column justify-center items-center mt-40">
		<div class="text-center text-xl">
			<span class="mt-5 font-bold">Hello there! You are currently logged in.</span>
		</div>
	</section>
	<section class="flex flex-column justify-center items-center mt-40">
		<div class="text-center">
			<button
				on:click={handleLogout}
				class="w-20 text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm  text-center"
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
						<div>
							<label for="text" class="block mb-2 text-sm font-medium text-gray-900"
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
							<label for="text" class="block mb-2 text-sm font-medium text-gray-900"
								>Password (hint: 12345678)</label
							>
							<input
								type="text"
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
		<p class="text-xs"><a class="text-blue-500" href="/">Back to main page</a></p>
	</div>
</footer>
