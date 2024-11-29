import { writable } from "svelte/store";

export const userIDStore = writable(0);
export const userTokenStore = writable('');
