<script context="module" lang="ts">
	export const prerender = true;
</script>

<script lang="ts">
	let math = "";
</script>

<svelte:head>
	<title>Home</title>
</svelte:head>

<section>
	<input type=text bind:value="{math}" />
</section>

<style></style>
