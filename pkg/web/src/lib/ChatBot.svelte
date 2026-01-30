<script lang="ts">
	import { faro } from '@grafana/faro-web-sdk';
	import { PUBLIC_BACKEND_ENDPOINT } from '$env/static/public';

	let isOpen = false;
	let inputMessage = '';
	let isLoading = false;
	let messages: { role: 'user' | 'bot'; content: string }[] = [];

	function toggleChat() {
		isOpen = !isOpen;
		if (isOpen) {
			faro.api.pushEvent('ChatBot Opened', {});
		} else {
			faro.api.pushEvent('ChatBot Closed', {});
		}
	}

	function handleKeyDown(event: KeyboardEvent) {
		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			sendMessage();
		}
	}

	async function sendMessage() {
		if (!inputMessage.trim() || isLoading) return;

		const userMessage = inputMessage.trim();
		inputMessage = '';

		// Add user message
		messages = [...messages, { role: 'user', content: userMessage }];

		// Track the chat message event
		faro.api.startUserAction(
			'sendChatMessage',
			{ message: userMessage },
			{ triggerName: 'chatBotSendMessage' }
		);

		isLoading = true;

		try {
			const res = await fetch(`${PUBLIC_BACKEND_ENDPOINT}/api/chat`, {
				method: 'POST',
				body: JSON.stringify({ message: userMessage }),
				headers: {
					'Content-Type': 'application/json',
				},
			});

			if (!res.ok) {
				const errorData = await res.json().catch(() => ({}));
				const errorMessage = errorData.error || 'Failed to get response. Please try again.';
				faro.api.pushError(new Error(`ChatBot API Error: ${errorMessage}`));
				messages = [
					...messages,
					{ role: 'bot', content: errorMessage },
				];
				return;
			}

			const json = await res.json();
			messages = [
				...messages,
				{ role: 'bot', content: json.response || 'Sorry, I could not process your request.' },
			];
		} catch (error) {
			faro.api.pushError(new Error(`ChatBot Error: ${error}`));
			messages = [
				...messages,
				{ role: 'bot', content: 'Sorry, something went wrong. Please try again.' },
			];
		} finally {
			isLoading = false;
		}
	}
</script>

{#snippet RobotIcon(className: string)}
	<svg
		xmlns="http://www.w3.org/2000/svg"
		class={className}
		fill="none"
		viewBox="0 0 24 24"
		stroke="currentColor"
		stroke-width="1.5"
	>
		<rect x="4" y="8" width="16" height="12" rx="2" stroke="currentColor" fill="none" />
		<line x1="12" y1="8" x2="12" y2="4" stroke="currentColor" stroke-width="1.5" />
		<circle cx="12" cy="3" r="1.5" fill="currentColor" />
		<circle cx="9" cy="13" r="1.5" fill="currentColor" />
		<circle cx="15" cy="13" r="1.5" fill="currentColor" />
		<line x1="9" y1="17" x2="15" y2="17" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
	</svg>
{/snippet}

<!-- Chat Bot Button -->
<button
	on:click={toggleChat}
	class="fixed bottom-6 right-6 w-14 h-14 bg-gradient-to-br from-red-500 to-orange-400 hover:bg-gradient-to-bl text-white rounded-full shadow-lg flex items-center justify-center transition-all duration-300 hover:scale-110 z-50"
	aria-label="Open chat"
>
	{#if isOpen}
		<!-- Close icon -->
		<svg
			xmlns="http://www.w3.org/2000/svg"
			class="h-6 w-6"
			fill="none"
			viewBox="0 0 24 24"
			stroke="currentColor"
			stroke-width="2"
		>
			<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
		</svg>
	{:else}
		<!-- Robot icon -->
		{@render RobotIcon("h-7 w-7")}
	{/if}
</button>

<!-- Chat Widget -->
{#if isOpen}
	<div
		class="fixed bottom-24 right-6 w-80 sm:w-96 h-[28rem] bg-white border border-gray-200 rounded-lg shadow-xl flex flex-col z-50"
	>
		<!-- Header -->
		<div
			class="bg-gradient-to-br from-red-500 to-orange-400 text-white px-4 py-3 rounded-t-lg flex items-center"
		>
			{@render RobotIcon("h-6 w-6 mr-2")}
			<span class="font-medium">QuickPizza Assistant</span>
		</div>

		<!-- Messages area -->
		<div class="flex-1 overflow-y-auto p-4 space-y-3">
			{#if messages.length === 0}
				<div class="text-center text-gray-500 mt-8">
					<p class="text-sm">👋 Hi there!</p>
					<p class="text-sm mt-1">How can I help you with your pizza today?</p>
				</div>
			{:else}
				{#each messages as message}
					<div class="flex {message.role === 'user' ? 'justify-end' : 'justify-start'}">
						<div
							class="max-w-[80%] px-3 py-2 rounded-lg text-sm {message.role === 'user'
								? 'bg-gradient-to-br from-red-500 to-orange-400 text-white'
								: 'bg-gray-100 text-gray-800'}"
						>
							{message.content}
						</div>
					</div>
				{/each}
				{#if isLoading}
					<div class="flex justify-start">
						<div class="bg-gray-100 text-gray-800 px-3 py-2 rounded-lg text-sm">
							<span class="inline-flex items-center">
								<span class="animate-pulse">Thinking...</span>
							</span>
						</div>
					</div>
				{/if}
			{/if}
		</div>

		<!-- Input area -->
		<div class="border-t border-gray-200 p-3">
			<div class="flex items-center space-x-2">
				<input
					type="text"
					bind:value={inputMessage}
					on:keydown={handleKeyDown}
					placeholder="Type a message..."
					disabled={isLoading}
					class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:border-red-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
				/>
				<button
					on:click={sendMessage}
					disabled={isLoading}
					class="px-3 py-2 bg-gradient-to-br from-red-500 to-orange-400 hover:bg-gradient-to-bl text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed"
					aria-label="Send message"
				>
					<svg
						xmlns="http://www.w3.org/2000/svg"
						class="h-5 w-5"
						fill="none"
						viewBox="0 0 24 24"
						stroke="currentColor"
						stroke-width="2"
					>
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
						/>
					</svg>
				</button>
			</div>
		</div>
	</div>
{/if}
