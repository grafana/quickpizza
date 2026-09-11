import { expect, test } from '@playwright/test';

test('shows a pizza recommendation', async ({ page }) => {
	await page.goto('/');

	await expect(
		page.getByRole('heading', {
			name: 'Looking to break out of your pizza routine?',
		}),
	).toBeVisible();
	const pizzaResponse = page.waitForResponse(
		(response) =>
			response.url().endsWith('/api/pizza') &&
			response.request().method() === 'POST',
	);
	await page.getByRole('button', { name: 'Pizza, Please!' }).click();
	expect((await pizzaResponse).status()).toBe(200);

	const recommendation = page.locator('#recommendations');
	await expect(recommendation).toBeVisible();
	await expect(recommendation).toContainText('Our recommendation:');
	await expect(recommendation).toContainText('Name:');
	await expect(recommendation).toContainText('Ingredients:');
	await expect(recommendation).toContainText('Calories per slice:');
});
