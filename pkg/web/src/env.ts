import { defineEnvVars } from '@sveltejs/kit/env';

export const variables = defineEnvVars({
	PUBLIC_BACKEND_ENDPOINT: {
		public: true,
		static: true,
		schema: (value) => value ?? '',
	},
	PUBLIC_BACKEND_WS_ENDPOINT: {
		public: true,
		static: true,
		schema: (value) => value ?? '',
	},
});
