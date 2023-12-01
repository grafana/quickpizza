<script lang="ts">
import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';
import { onMount } from 'svelte';
import { userID } from '../../lib/stores';

var user = 0;
var loginError = '';
var password = 'admin';
var token = '';
var latestPizzaRecommendations: string[] = [];

onMount(async () => {
        userID.subscribe((value) => user = value);
        if (user === 0) {
            userID.set(Math.floor(100000 + Math.random() * 900000));
        }

        token = tokenFromCookie();
});

function tokenFromCookie() {
    const tokenCookie = document.cookie.split("; ").filter(c => c.startsWith("admin_token"));
    if (tokenCookie.length == 0) {
        return "";
    }

    return tokenCookie[0].split("=")[1];
}

async function handleSubmit() {
    const res = await fetch(`${PUBLIC_BACKEND_ENDPOINT}api/login?user=admin&password=${password}`, {
			method: 'GET',
            headers: {
					'X-User-ID': user.toString()
			},
      credentials: 'same-origin', // Honor Set-Cookie header returned by /api/login.
	},);
    if (!res.ok) {
        loginError = 'Login failed: ' + res.statusText;
        return;
    }

    token = tokenFromCookie();
}

async function handleLogout() {
    // Perhaps surprisingly, this only deletes (clears the value of) the admin_token cookie.
    document.cookie = "admin_token=; Expires=Thu, 01 Jan 1970 00:00:01 GMT";
    token = "";
}

$: if (token) {
    updateRecommendations();
}

function updateRecommendations() {
    fetch(`${PUBLIC_BACKEND_ENDPOINT}api/internal/recommendations`, {
            method: 'GET',
            headers: {
                    'Authorization': 'Bearer ' + token,
                    'X-User-ID': user.toString()
            }
    },).then(res => res.json()).then(json => {
        var newRec: string[] = [];
        json.pizzas = json.pizzas.reverse();
        json.pizzas.forEach((pizza: any) => {
            newRec.push(`
                ${pizza.name} (tool=${pizza.tool}, ingredients_number=${pizza.ingredients.length})`
            );
        });
        newRec = newRec.slice(0, 10);
        latestPizzaRecommendations = newRec;
    });
}
</script>

{#if token}

<section class="flex flex-column justify-center items-center mt-40">
	<div class="text-center">
        <button on:click={handleLogout} class="w-20 text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm  text-center">Logout</button>
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
            <button on:click={updateRecommendations} class="w-20 text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm  text-center">Refresh</button>
        </div>
</section>
{:else}
<section class="flex flex-column justify-center items-center mt-40">
	<div class="text-center">
        <div class="w-full bg-white rounded-lg shadow md:mt-0 sm:max-w-md xl:p-0">
            <div class="p-6 space-y-4 md:space-y-6 sm:p-8">
                <h1 class="text-xl font-bold leading-tight tracking-tight text-gray-900 md:text-2xl dark:text-white">
                    QuickPizza Administration
                </h1>
                <form class="space-y-4 md:space-y-6" on:submit|preventDefault={handleSubmit}>
                    <div>
                        <label for="text" class="block mb-2 text-sm font-medium text-gray-900 dark:text-white">Password</label>
                        <input type="text" name="password" id="password" placeholder="admin" class="bg-gray-50 border border-gray-300 text-gray-900 sm:text-sm rounded-lg focus:ring-primary-600 focus:border-primary-600 block w-full p-2.5" required bind:value={password}>
                    </div>
                    <button type="submit" class="w-full text-gray-900 bg-gray-50 hover:bg-gray-100 border border-gray-300 font-medium rounded-lg text-sm px-5 py-2.5 text-center">Sign in</button>
                </form>
                {#if loginError}
                    <div class="text-center text-red-500">{loginError}</div>
                {/if}
            </div>
	</div>
</section>
<footer>
    <div class="flex justify-center mt-4">
        <p class="text-xs">Your user ID is: {user}</p>
    </div>
    <div class="flex justify-center mt-2">
        <p class="text-xs"><a class="text-blue-500" href="/">Back to main page</a></p>
    </div>
</footer>
{/if}
