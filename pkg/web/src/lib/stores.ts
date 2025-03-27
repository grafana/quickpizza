import { writable } from 'svelte/store';

export const wsVisitorIDStore = writable(0);
export const userTokenStore = writable('');
