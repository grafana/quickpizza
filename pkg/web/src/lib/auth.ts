import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';

/**
 * Get a cookie value by name
 */
export function getCookie(name: string): string | null {
	for (const cookie of document.cookie.split('; ')) {
		const [key, value] = cookie.split('=');
		if (key === name) {
			return decodeURIComponent(value);
		}
	}
	return null;
}

/**
 * Clear a cookie by name (expires it in the past).
 * Uses document.cookie because Cookie Store API is not universally available.
 */
export function clearCookie(name: string): void {
	// biome-ignore lint/suspicious/noDocumentCookie: Cookie Store API lacks broad browser support
	document.cookie = `${name}=; Expires=Thu, 01 Jan 1970 00:00:01 GMT`;
}

/**
 * Check if the qp_user_token cookie is present.
 * Note: This only checks for cookie presence, not validity.
 * Use verifyUserLoggedIn() for server-side validation.
 */
export function hasUserTokenCookie(): boolean {
	const token = getCookie('qp_user_token');
	return token !== null && token.length > 0;
}

/**
 * Verify if the user is logged in by making a request to the backend.
 * Returns true if the user's session is valid, false otherwise.
 */
export async function verifyUserLoggedIn(): Promise<boolean> {
	// First check if the cookie exists at all
	if (!hasUserTokenCookie()) {
		return false;
	}

	// Verify the token is valid by calling the authenticate endpoint
	try {
		const res = await fetch(
			`${PUBLIC_BACKEND_ENDPOINT}/api/users/token/authenticate`,
			{
				method: 'POST',
				credentials: 'same-origin',
			},
		);
		return res.ok;
	} catch {
		return false;
	}
}
